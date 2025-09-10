import 'dart:io';
import 'dart:typed_data';
import 'DatabaseHelper.dart';
import 'MealListScreen.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:csv/csv.dart'; // CSVラベル対応
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import 'package:camera/camera.dart';

class FoodRecognitionScreen extends StatefulWidget {
  final XFile image;

  const FoodRecognitionScreen({required this.image});

  @override
  _FoodRecognitionScreenState createState() => _FoodRecognitionScreenState();
}

class _FoodRecognitionScreenState extends State<FoodRecognitionScreen> {
  Interpreter? _interpreter;
  List<dynamic>? _recognitions;
  String? _imagePath;
  List<String>? _labels;
  List<List<dynamic>>? _csvTable;

  List<String>? _errorState;

  // データベースに登録するために必要な情報
  // dbHelper.insertCalories({
  //   'date': date,　←登録するタイミングの日付
  //   'time': time,　←登録するタイミングの時間
  //   'name': 'Sample Record',　←画像を解析して取得
  //   'calorie': 500     ←nameから検索する
  //   'image_path': 'sample/pass/$time',　←保存ボタンを押したときファイルを保存するその場所
  // });

  Map<String, dynamic>? mealRecord;
  final DatabaseHelper dbHelper = DatabaseHelper.instance;

  // 画面確認用ダミーデータ
  // {
  // 'date': '2025/08/15',
  // 'time': '19:40',
  // 'Name': 'Japanese curry',
  // 'calories': '500',
  // 'imagePath': 'assets/meal_image.jpg',
  // };

  @override
  void initState() {
    super.initState();

    _errorState = [];
    setState(() {
      _errorState?.add('initState Start');
    });

    //_imagePath = widget.image.path; // コンストラクタで受け取ったimageのパスにアクセス
    //_loadModelAndProcess(); // モデルロードや処理を開始
    print("_FoodRecognitionScreenState　initState() Start");

    // コンストラクタで受け取ったimageのパス
    _imagePath = widget.image.path;
    // モデルとラベルをロードする
    _loadModelAndProcess();

    print("_FoodRecognitionScreenState　initState() End");
  }

  // initState()でawait loadModel()のように呼び出すと
  // Futureを返すように解釈され、エラーが発生する
  // この対策のためロード処理と解析処理をひとまとめのメソッドとする
  Future<void> _loadModelAndProcess() async {
    try {
      await loadModel();
      await loadLabels();
      if (_imagePath != null) {
        await classifyImage(_imagePath!);
        print(
          "_FoodRecognitionScreenState　initState()　_recognitions= $_recognitions",
        );
        if (_recognitions != null && _recognitions!.isNotEmpty) {
          await _makeMealRecord();
        } else {
          // 認識結果がなかった場合のエラー処理
          setState(() {
            _errorState?.add("No recognition results found.");
          });
          print("No recognition results found.");
        }
        //String logName = getLabelName(_recognitions![0]['label']);
      } else {
        print("Error: _imagePath is null");
        setState(() {
          _errorState?.add("Error: _imagePath is null");
        });
      }
    } catch (e) {
      print("Error in _loadModelAndProcess: $e");
      setState(() {
        _errorState?.add("_loadModelAndProcess catch");
      });
    }
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
      setState(() {
        _errorState?.add('loadModel catch');
      });
    }
  }

  // modelに対応するCSVラベル読み込み
  Future<void> loadLabels() async {
    try {
      // assetsからラベルファイルを読み込む
      final csvString = await rootBundle.loadString(
        'assets/aiy_food_V1_labelmap_updated.csv',
      );
      _csvTable = const CsvToListConverter().convert(csvString);
      if (_csvTable==null){
        setState(() {
          _errorState?.add('loadLabels() _csvTable==null');
        });
      }else{
        setState(() {
          _errorState?.add('loadLabels() _csvTable!=null');
        });
      }
      // 1列目がラベル名なら以下で取得
      _labels = _csvTable!.map((row) => row[0].toString()).toList();
      if (_labels==null){
        setState(() {
          _errorState?.add('loadLabels() _labels==null');
        });
      }else{
        setState(() {
          _errorState?.add('loadLabels() _labels!=null');
        });
      }
      // _csvTableの内容メモ
      // _csvTable[index][0] :食品のID、画像解析と紐づけるためのもの
      // _csvTable[index][1] :食品名（英語）APIにアクセスする際に使用
      // _csvTable[index][2] :食品名（日本語）画面表示用
      // _csvTable[index][3] :一食あたりの一般的な量（グラム）
      //                      APIから得られる情報が100グラム当たりのカロリーであるため
      print('Labels loaded successfully');
      // print('csvTable $_csvTable');
      // print('_labels $_labels');
    } catch (e) {
      print('Error loading labels: $e');
      setState(() {
        _errorState?.add('loadLabels catch');
      });
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
      setState(() {
        _errorState?.add('Interpreter not initialized');
      });
      return;
    }

    try {
      print('img.Image? image');
      img.Image? image = img.decodeImage(File(imagePath).readAsBytesSync());
      if (image == null) {
        print('Failed to decode image');
        setState(() {
          _errorState?.add('Failed to decode image');
        });
        return;
      }

      print('var inputShape');
      // var inputShape = _interpreter!.getInputTensor(0).shape; // -> [1, 192, 192, 3]
      //int height = inputShape[1];
      //int width = inputShape[2];
      int height = 224;
      int width = 224;

      print('img.Image resizedImage');
      img.Image resizedImage = img.copyResize(
        image,
        width: width,
        height: height,
      );

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
        List.generate(
          height,
          (y) => List.generate(
            width,
            (x) => List.generate(3, (c) => input[(y * width + x) * 3 + c]),
          ),
        ),
      ];

      // 入力形状を [1, height, width, 3] にリシェイプ
      var reshapedInput = input.reshape([1, height, width, 3]);
      //print('reshapedInput $reshapedInput');

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
          'label': _labels != null && i < _labels!.length
              ? _labels![i]
              : 'Class $i',
          'confidence': output[i],
        });
      }
      recognitions.sort((a, b) => b['confidence'].compareTo(a['confidence']));
      _recognitions = recognitions.take(5).toList();

      setState(() {});
      print('Classification completed');
    } catch (e) {
      print('Error classifying image: $e');
      setState(() {
        _errorState?.add('classifyImage catch');
      });
    }
  }

  // 'date': '2025/08/15',
  // 'time': '19:40',
  // 'Name': 'Japanese curry',
  // 'calories': '500',
  // 'imagePath': 'assets/meal_image.jpg',
  Future<void> _makeMealRecord() async {
    print("_makeMealRecord() Start");
    String? recordDate;
    String? recordTime;
    String? searchName; // APIリクエストに使用
    String? recordName;
    String? recordCalorie;

    // 現在の日付と時間を取得（例）
    final now = DateTime.now();
    recordDate =
        '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';
    recordTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    print("_makeMealRecord() recordDate=$recordDate");
    print("_makeMealRecord() recordTime=$recordTime");

    var _dbg = _recognitions![0]['label'];
    setState(() {
      _errorState?.add(
        '_recognitions![0]['
        'label'
        '] = $_dbg',
      );
    });
    // 食品名を取得
    final labelData = await getlabelData((_recognitions![0]['label']));
    print("_makeMealRecord() labelData=$labelData");
    if (labelData.length == 3) {
      searchName = labelData[0];
      recordName = labelData[1];
      recordCalorie = labelData[2];
    } else {
      // ラベルから食品名を取得できなかった場合、お茶をにごす
      recordName = '---';
    }
    print("_makeMealRecord() recordName=$recordName");

    print("_makeMealRecord() recordCalorie=$recordCalorie");

    setState(() {
      mealRecord = {};
      // mealRecordにまとめる

      mealRecord?.putIfAbsent('date', () => recordDate);
      mealRecord?.putIfAbsent('time', () => recordTime);
      mealRecord?.putIfAbsent('name', () => recordName);
      mealRecord?.putIfAbsent('calorie', () => recordCalorie);
    });
    print("_makeMealRecord() mealRecord=");
    print(mealRecord);
    setState(() {
      _errorState?.add('_makeMealRecord() end');
    });
  }

  // IDから名前を取得する関数
  Future<List<dynamic>> getlabelData(String id) async {
    setState(() {
      _errorState?.add("getlabelData start");
    });
    if (_csvTable == null) {
      setState(() {
        _errorState?.add("getlabelData _csvTable == null)");
      });
      return ['no_table'];
    }

    if(_labels!=null){
      setState(() {
        _errorState?.add("_labels.length= ${_labels!.length}");
        _errorState?.add("_labels[0]= ${_labels![0]}");
      });
    }
    setState(() {
      _errorState?.add("getlabelData 1");
      _errorState?.add("id.runtimeType = ${id.runtimeType}");
      _errorState?.add("id = |${id}|");
      _errorState?.add(
        "int.parse(id).runtimeType = |${int.parse(id).runtimeType}|",
      );
      _errorState?.add("id = |${(int.parse(id) + 1).toString()}|");
    });
    // デバッグ用ログを追加して、型を確認
    //print("ID from recognition: $id, type: ${id.runtimeType}");

    // 認識結果のIDとCSVのIDを両方とも文字列として比較する
    final String recognitionIdString = (int.parse(id) + 1).toString();
    print("Parsed recognition ID string: $recognitionIdString");

    setState(() {
      _errorState?.add("getlabelData 2 _csvTable!.length=${_csvTable!.length}");
    });
    for (int i = 1; i < _csvTable!.length; i++) {
      // CSVから読み込んだIDを文字列に変換し、前後の空白を削除
      final String csvIdString = _csvTable![i][0].toString().trim();
      print("CSV ID string: $csvIdString");

      // setState(() {
      //   _errorState?.add("getlabelData 3 csvIdString=$csvIdString");
      // });
      // 文字列として比較
      if (csvIdString == recognitionIdString) {
        setState(() {
          _errorState?.add("if (csvIdString == recognitionIdString) {");
        });
        final name = _csvTable![i][1].toString();
        final JapaneseName = _csvTable![i][2].toString();
        final calories = _csvTable![i][3].toString();
        return [name, JapaneseName, calories];
      }
    }
    setState(() {
      _errorState?.add(
        "getlabelData no_id ,_csvTable!.length= ${_csvTable!.length}' )",
      );
    });
    return ['no_id']; // IDが見つからない場合
  }

  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }

  // 結果を画面に表示
  @override
  Widget build(BuildContext context) {
    print('Widget build(');
    return Scaffold(
      appBar: AppBar(
        title: Text('Food Recognition'),
        backgroundColor: Colors.blue[300],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // 写真を入れる
            Container(
              // ここに写真を表示する
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                image: DecorationImage(
                  image: FileImage(File(_imagePath!)),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Container(
              height: 34,
              child: mealRecord != null && mealRecord!['name'] != null
                  ? Text(
                      // 食品名を入れる
                      mealRecord!['name'],
                      //'Name',
                      style: TextStyle(fontSize: 23),
                    )
                  : const SizedBox.shrink(),
            ),
            Container(
              height: 34,
              child: mealRecord != null && mealRecord!['calorie'] != null
                  ? Text(
                      // このテキストに記録（撮影）した時間を入れる
                      '${mealRecord!['calorie']} kcal',
                      //'000kcal',
                      style: TextStyle(fontSize: 23),
                    )
                  : const SizedBox.shrink(),
            ),
            SizedBox(height: 10),
            Container(
              child: ElevatedButton(
                onPressed: () {
                  print('ボタンが押されました');
                  // ボタンが押されたらデータベースに登録しホーム画面に戻る
                  saveAndReturnToHome();
                },
                style: ElevatedButton.styleFrom(
                  // 背景色
                  backgroundColor: Colors.blue[400],
                  // テキスト色（フォアグラウンドカラー）
                  foregroundColor: Colors.white,
                ),
                child: Text("保存", style: TextStyle(fontSize: 18)),
              ),
            ),

            //　デバッグ用
            SizedBox(
              height: 200,
              child: SingleChildScrollView(
                child: Column(
                  children: <Widget>[
                    for (var meal in _errorState!) ...[
                      Text(
                        meal,
                        style: TextStyle(color: Colors.red, fontSize: 18),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> saveAndReturnToHome() async {
    if (_imagePath != null) {
      final savedPath = await saveImage(_imagePath!);
      mealRecord?.putIfAbsent('image_path', () => savedPath.toString());
      print(mealRecord);
      await dbHelper.insertCalories(mealRecord!);
    } else {
      dbHelper.insertCalories(mealRecord!);
    }

    // ホーム画面に戻る
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => MealListScreen()),
      (Route<dynamic> route) => false, // falseを返すことで、前の画面をすべて削除
    );
  }

  Future<String> saveImage(String imagePath) async {
    try {
      // アプリのドキュメントディレクトリを取得
      final directory = await getApplicationDocumentsDirectory();

      // 一時ディレクトリ
      //final directory = await getTemporaryDirectory();

      // ファイル名を生成（例: timestamp.jpg）
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = path.join(directory.path, fileName);

      // XFileからファイルを読み込み、指定したパスに保存
      final File newImage = await File(imagePath).copy(filePath);

      print('写真が保存されました: $filePath');
      return filePath;
    } catch (e) {
      print('保存に失敗しました: $e');
      return '';
    }
  }
}
