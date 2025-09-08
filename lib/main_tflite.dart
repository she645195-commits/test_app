import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:csv/csv.dart'; // CSVラベル対応
import 'package:flutter/services.dart' show rootBundle;



class FoodRecognitionScreen extends StatefulWidget {
  // このクラスがMaterialAppのhomeプロパティで呼ばれ
  // アプリ起動時に最初に見る画面を提供する
  @override
  // createState()はStatefulWidgetでは必須のもの
  // 矢印（=>）はDartのショートハンド構文（アロー関数）を表す

  // ここのcreateState()は
  // 戻り値は_FoodRecognitionScreenState型であり、
  // _FoodRecognitionScreenState()のインスタンスを生成して返すもの
  // となる。
  _FoodRecognitionScreenState createState() => _FoodRecognitionScreenState();
}

class _FoodRecognitionScreenState extends State<FoodRecognitionScreen> {
  Interpreter? _interpreter;
  List<dynamic>? _recognitions;
  String? _imagePath;
  List<String>? _labels;
  List<List<dynamic>>? _csvTable;

  @override
  void initState() {
    super.initState();
    loadModel();
    loadLabels();
  }

  // TensorFlow Liteモデルのロード
  Future<void> loadModel() async {
    print('_FoodRecognitionScreenState loadModel()');
    try {
      // モデルをassetsからファイルにコピー（tflite_flutterはファイルパスを要求）
      _interpreter = await Interpreter.fromAsset(
        'assets/model.tflite',
        options: InterpreterOptions()..threads = 4,
      );
      print('Model loaded successfully');
    } catch (e) {
      print('Error loading model: $e');
    }
  }

  // modelに対応するCSVラベル読み込み
  Future<void> loadLabels() async {
    try {
      // assetsからラベルファイルを読み込む
      final csvString = await rootBundle.loadString('assets/aiy_food_V1_labelmap.csv');
      _csvTable = const CsvToListConverter().convert(csvString);
      // 1列目がラベル名なら以下で取得
      _labels = _csvTable!.map((row) => row[0].toString()).toList();
      print('Labels loaded successfully');
      print('csvTable $_csvTable');
      print('_labels $_labels');
    } catch (e) {
      print('Error loading labels: $e');
    }
  }

  // IDから名前を取得する関数
  String getLabelName(String id) {
    if (_csvTable == null) return 'no_table';
    for (int i = 1; i < _csvTable!.length; i++) { // ヘッダーをスキップ
      if (_csvTable![i][0] == int.parse(id)+1) {
        return _csvTable![i][1].toString();
      }
    }
    return 'no_id'; // IDが見つからない場合
  }

  // ギャラリーから画像を選択
  Future<void> pickImage() async {
    print('_FoodRecognitionScreenState pickImage()');
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _imagePath = pickedFile.path);
      classifyImage(pickedFile.path);
    }
  }

  /// 画像分類（入力サイズ自動・正規化・上位5件）
  // 画像を前処理してモデルで推論
  // Future<void>: 将来何かを処理するが値は返さない型
  // async: 内部で待機が必要な処理がある時につける
  // 引数は画像のファイルパス
  Future<void> classifyImage(String imagePath) async {
    if (_interpreter == null) {
      print('Interpreter not initialized');
      return;
    }

    try {
      print('img.Image? image');
      img.Image? image = img.decodeImage(File(imagePath).readAsBytesSync());
      if (image == null) {
        print('Failed to decode image');
        return;
      }

      print('var inputShape');
      // var inputShape = _interpreter!.getInputTensor(0).shape; // -> [1, 192, 192, 3]
      //int height = inputShape[1];
      //int width = inputShape[2];
      int height = 224;
      int width = 224;

      print('img.Image resizedImage');
      img.Image resizedImage = img.copyResize(image, width: width, height: height);

      print('Float32List input');
      // Uint8List を作成し、0-255 の値を直接格納
      Uint8List input = Uint8List(height * width * 3);
      int index = 0;
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          var pixel = resizedImage.getPixel(x, y);
          input[index++] = pixel.r.toInt();
          input[index++] = pixel.g.toInt();
          input[index++] = pixel.b.toInt();
        }
      }


      // 4次元リストに変換
      List<List<List<List<int>>>> input4d = [
        List.generate(height, (y) =>
            List.generate(width, (x) =>
                List.generate(3, (c) => input[(y*width + x)*3 + c])
            )
        )
      ];

      // 入力形状を [1, height, width, 3] にリシェイプ
      var reshapedInput = input.reshape([1, height, width, 3]);
      print('reshapedInput $reshapedInput');

      print('var outputShape');
      var outputShape = _interpreter!.getOutputTensor(0).shape;
      print('var output');
      Uint8List output = Uint8List(outputShape.reduce((a, b) => a * b));
      // 2次元配列として初期化
      // var reshapedoutput = List<List<int>>.generate(
      //   outputShape[0], // バッチサイズ (1)
      //       (i) => List<int>.filled(outputShape[1], 0), // 2024要素
      // );

      print('_interpreter!.run');
      //print('input4d $input4d');
      //print('output $output');
      _interpreter!.run(input4d, output);

      print('List<Map<String, dynamic>> recognitions');
      // 上位5件を取得
      List<Map<String, dynamic>> recognitions = [];
      for (int i = 0; i < output.length; i++) {
        recognitions.add({
          'label': _labels != null && i < _labels!.length ? _labels![i] : 'Class $i',
          'confidence': output[i],
        });
      }
      recognitions.sort((a, b) => b['confidence'].compareTo(a['confidence']));
      _recognitions = recognitions.take(5).toList();

      setState(() {});
      print('Classification completed');
    } catch (e) {
      print('Error classifying image: $e');
    }
  }

  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }

  // UIの構築
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Food Recognition')),
      body: Column(
        children: [
          _imagePath == null
              ? Text('No image selected')
              : Image.file(File(_imagePath!), height: 300),
          ElevatedButton(
            onPressed: pickImage,
            child: Text('Pick Image from Gallery'),
          ),
          _recognitions != null
              ? Expanded(
            child: ListView.builder(
              itemCount: _recognitions!.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(getLabelName(_recognitions![index]['label'])),
                  subtitle: Text(
                    'Confidence: ${(100 * _recognitions![index]['confidence']).toStringAsFixed(2)}%',
                  ),
                );
              },
            ),
          )
              : Container(),
        ],
      ),
    );
  }
}