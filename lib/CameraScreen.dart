import 'package:flutter/material.dart';
import 'dart:io';
import 'FoodRecognitionScreen.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class CameraScreen extends StatefulWidget {
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  bool _isCameraInitialized = false;
  String? _errorState = null;

  @override
  void initState() {
    super.initState();
    // カメラコントローラを初期化
    _initializeControllerFuture = _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      // テスト用に意図的な例外をスロー（本番では削除）
      //throw Exception('テスト用の意図的なエラー');

      // // 無効なカメラを強制的に指定
      // final firstCamera = CameraDescription(
      //   name: "invalid_camera", // 存在しないカメラ名
      //   lensDirection: CameraLensDirection.back,
      //   sensorOrientation: 90,
      // );

      // 利用可能なカメラを取得
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        print('カメラが利用できません');
        return;
      }
      final firstCamera = cameras.first;

      // カメラコントローラを初期化
      _controller = CameraController(firstCamera, ResolutionPreset.medium);
      _initializeControllerFuture = _controller.initialize();
      await _initializeControllerFuture;
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      setState(() {
        // カメラの初期化エラーかを判定する変数
        // この中身を見て表示する画面を切り替える（未実装）
        _errorState = 'カメラ起動失敗';
      });
      print('カメラ初期化エラー: $e');
    }
  }

  @override
  void dispose() {
    if (_controller.value.isInitialized) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('カメラ'),
        backgroundColor: Colors.blue[300],
        // flutterの仕様でNavigator.push または
        // Navigator.pushReplacementで画面遷移してきたとき
        // 自動で戻るボタンがつけられる
      ),

      //if(_errorState == null){
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return CameraPreview(_controller);
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),

      floatingActionButton: FloatingActionButton(
        shape: const CircleBorder(),
        backgroundColor: Colors.blue[200],
        onPressed: () async {
          try {
            await _initializeControllerFuture;

            // 写真を撮影
            final XFile image = await _controller.takePicture();
            // // 撮影した画像のパスを表示
            // ScaffoldMessenger.of(context).showSnackBar(
            //   SnackBar(content: Text('写真が保存されました: ${image.path}')),
            // );
            print("image.path ${image.path}");

            // 写真を保存
            //await saveImage(image);

            // 撮った写真を渡して画面を切り替える
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    FoodRecognitionScreen(image: image),
              ),
            );
          } catch (e) {
            print(e);
          }
        },
        child: const Icon(Icons.camera_alt, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Future<void> saveImage(XFile image) async {
    try {
      // アプリのドキュメントディレクトリを取得
      final directory = await getApplicationDocumentsDirectory();

      // 一時ディレクトリ
      //final directory = await getTemporaryDirectory();

      // ファイル名を生成（例: timestamp.jpg）
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = path.join(directory.path, fileName);

      // XFileからファイルを読み込み、指定したパスに保存
      final File newImage = await File(image.path).copy(filePath);

      print('写真が保存されました: $filePath');

    } catch (e) {
      print('保存に失敗しました: $e');

    }
  }
}
