import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'CameraScreen.dart';
import 'FoodRecognitionScreen.dart';
import 'DatabaseHelper.dart';
import 'dart:collection';
import 'dart:io';

class MealListScreen extends StatefulWidget {
  @override
  _MealListScreenState createState() => _MealListScreenState();
}

class _MealListScreenState extends State<MealListScreen> {
  // List<Map<String, dynamic>> mealRecord = [
  //   // 画面確認用ダミーデータ
  //   {
  //     'date': '2025/08/15',
  //     'records': [
  //       {'dbId': 4, 'time': '19:40', 'mealName': 'Japanese curry', 'calories': '500', 'imagePath': 'assets/meal_image.jpg',},
  //       {'dbId': 3,'time': '5:00', 'mealName': 'Japanese curry', 'calories': '1200', 'imagePath': 'assets/meal_image.jpg',}
  //     ],
  //   },
  //   {
  //     'date': '2025/08/14',
  //     'records': [
  //       {'dbId': 2, 'time': '19:30', 'mealName': 'Japanese curry', 'calories': '500', 'imagePath': 'assets/meal_image.jpg',},
  //       {'dbId': 1, 'time': '9:30', 'mealName': 'Japanese curry', 'calories': '900', 'imagePath': 'assets/meal_image.jpg',},
  //     ],
  //   },
  // ];

  // 画面の作成はのデータベースから取得したデータから上のようなリストにする
  // mealRecord の要素数（日付の数）でforループ
  // さらにそのループの中でmealRecord[0]['records']の要素数（写真の数）でforループ

  XFile? _galleryImageImage = null; //　端末のファイルを取得する際に使用する
  List<Map<String, dynamic>>? _showList;

  // スライド状態を管理するためのマップ
  Map<String, double> _slideOffsets = {};

  // 表示するボタンの幅を定義
  final double _deleteButtonWidth = 80.0;

  // スワイプ完了と判断するしきい値
  final double _slideThreshold = 0.4;

  //データベースの確認
  final DatabaseHelper dbHelper = DatabaseHelper.instance;

  // 端末に保存されている写真を取得する関数
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _galleryImageImage = XFile(pickedFile.path);
      });
    }
  }

  @override
  void initState() {
    super.initState();

    _homeinit();
  }

  Future<void> _homeinit() async {
    var allList = await dbHelper.getAllCaloriesSortedByDateTime();
    print('_MealTrackerScreenState データベース上の全リスト $allList');

    // 取得したデータを表示用に変換（非同期処理）
    final transformedData = await transformData(allList);

    setState(() {
      _showList = transformedData;
      print('_MealTrackerScreenState 表示するためのリスト $_showList');
    });
  }

  //　データベースから受け取ったリストを表示用に成形する
  // LinkedHashMap を使用して、日付をキーとしてデータをグループ化
  Future<List<Map<String, dynamic>>> transformData(
    List<Map<String, dynamic>> data,
  ) async {
    // 日付をキー、その日の食事記録のリストを値とするLinkedHashMap
    final groupedByDate = LinkedHashMap<String, List<Map<String, dynamic>>>();

    for (var record in data) {
      // データの取得と形式変換
      final date = record['date'] as String;
      final recordData = {
        'dbId': record['id'] as int,
        'time': record['time'] as String,
        'mealName': record['name'] as String,
        'calories': record['calorie'].toString(), // カロリーをStringに変換
        'imagePath': record['image_path'] as String,
      };

      // LinkedHashMapにデータを追加
      if (groupedByDate.containsKey(date)) {
        groupedByDate[date]!.add(recordData);
      } else {
        groupedByDate[date] = [recordData];
      }
    }

    // 最終的なリスト形式に変換
    final result = groupedByDate.entries.map((entry) {
      return {'date': entry.key, 'records': entry.value};
    }).toList();

    return result;
  }

  @override
  Widget build(BuildContext context) {
    print("_MealTrackerScreenState build()");
    // 枠のサイズを取得する
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(title: Text('食事の記録'), backgroundColor: Colors.blue[300]),

      body: GestureDetector(
        onTap: _closeAllSlides,
        child: Stack(
          // Stackを親ウィジェット（Scaffoldのbody）のサイズに合わせる
          fit: StackFit.expand,
          children: <Widget>[
            SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  // 修正点：nullとemptyの両方をチェックする三項演算子を使用
                  (_showList == null || _showList!.isEmpty)
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 50.0),
                            child: Text(
                              'まだ食事記録がありません。',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          child: Column(
                            children: <Widget>[
                              for (var meal in _showList!) ...[
                                SizedBox(height: 2),
                                buildDateContainer(meal['date'], size.width),
                                SizedBox(height: 1),
                                for (var record in meal['records']) ...[
                                  buildRecordContainer(record, size.width),
                                ],
                              ],
                            ],
                          ),
                        ),
                ],
              ),
            ),

            // 右下に固定のボタン
            Positioned(
              bottom: 30,
              right: 20,
              child: SizedBox(
                width: 80, // カスタム幅
                height: 80, // カスタム高さ
                child: FloatingActionButton(
                  onPressed: () {
                    print('右下のボタンが押されました');
                    showModalBottomSheet(
                      context: context,
                      builder: (context) {
                        return ModalContainer(size.width);
                      },
                    );
                  },
                  backgroundColor: Colors.blue[500],
                  elevation: 8,
                  shape: const CircleBorder(),
                  child: const Icon(Icons.add, color: Colors.white, size: 40),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 日付を表示するウィジェット
  Widget buildDateContainer(String date, double screenWidth) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue[100],
        border: Border.all(color: Colors.white),
        borderRadius: BorderRadius.circular(6),
      ),
      width: screenWidth,
      child: Text('  $date', style: const TextStyle(fontSize: 20)),
    );
  }

  // 食品のデータを表示するウィジェット (スワイプでボタンを出すように変更)
  Widget buildRecordContainer(Map<String, dynamic> record, double screenWidth) {
    final slideKey = record['dbId']!.toString();
    // スライドのオフセットを取得
    final slideOffset = _slideOffsets[slideKey] ?? 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: GestureDetector(
        onHorizontalDragUpdate: (details) {
          _slideOffsets.forEach((key, value) {
            if (key != slideKey) {
              _slideOffsets[key] = 0.0;
            }
          });

          setState(() {
            final newOffset = (slideOffset + details.primaryDelta!).clamp(
              -_deleteButtonWidth,
              0.0,
            );
            _slideOffsets[slideKey] = newOffset;
          });
        },
        onHorizontalDragEnd: (details) {
          setState(() {
            if (slideOffset.abs() > _deleteButtonWidth * _slideThreshold) {
              _slideOffsets[slideKey] = -_deleteButtonWidth;
            } else {
              _slideOffsets[slideKey] = 0.0;
            }
          });
        },
        child: Stack(
          children: [
            // 削除ボタン (背景)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.red,
                  //border: Border.all(color: Colors.blue),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 15),
                child: IconButton(
                  icon: Icon(Icons.delete, color: Colors.white),
                  onPressed: () {
                    // データベースとローカルリストからアイテムを削除するロジック
                    _deleteRecord(record);
                  },
                ),
              ),
            ),

            // 記録コンテナ (手前)
            AnimatedContainer(
              duration: Duration(milliseconds: 300),
              curve: Curves.easeOut,
              transform: Transform.translate(
                offset: Offset(slideOffset, 0),
              ).transform,
              // 時間、カロリー、写真を表示するコンテナ
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border.all(color: Colors.blue),
                borderRadius: BorderRadius.circular(6),
              ),
              height: 80,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SizedBox(width: screenWidth * 0.03),
                      Container(
                        width: screenWidth * 0.6,
                        height: 70,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Container(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: <Widget>[
                                  Container(
                                    height: 34,
                                    child: Text(
                                      record['time']!,
                                      style: TextStyle(fontSize: 23),
                                    ),
                                  ),
                                  SizedBox(width: 30),
                                ],
                              ),
                            ),
                            Container(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: <Widget>[
                                  Container(
                                    width: screenWidth * 0.6 * 0.65,
                                    height: 34,
                                    child: Text(
                                      record['mealName']!,
                                      style: TextStyle(fontSize: 20),
                                    ),
                                  ),
                                  Container(
                                    width: screenWidth * 0.6 * 0.35,
                                    child: Text(
                                      record['calories']! + 'kcal',
                                      style: TextStyle(fontSize: 20),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: screenWidth * 0.05),
                      Container(
                        width: 80,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(4),
                          image: DecorationImage(
                            image: FileImage(File(record['imagePath']!)),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: Center(),
                      ),
                      SizedBox(width: screenWidth * 0.05),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // レコードを削除するヘルパー関数
  void _deleteRecord(Map<String, dynamic> record) async {
    // ローカルリストからアイテムを削除
    setState(() {
      _showList!.forEach((meal) {
        meal['records'].removeWhere((rec) => rec['dbId'] == record['dbId']);
      });
      // 空になった日付のグループを削除
      _showList!.removeWhere((meal) => meal['records'].isEmpty);
    });
    // データベースからも削除
    await dbHelper.deleteCalories(record['dbId']);
    // スライド状態をリセット
    _slideOffsets.remove(record['dbId'].toString());
  }

  // スライドしたアイテムをすべて元に戻すメソッド
  void _closeAllSlides() {
    setState(() {
      _slideOffsets.forEach((key, value) {
        _slideOffsets[key] = 0.0;
      });
    });
  }

  // 右下に固定されているボタンを押下したときに
  // 表示されるコンテナ
  Widget ModalContainer(double screenWidth) {
    return Container(
      height: 300,
      color: Colors.grey[300],
      //child: Center(child: Text("下から")),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          //SizedBox(width: size.width*0.4*0.1),
          Container(
            width: screenWidth * 0.4,
            height: screenWidth * 0.35,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              //border: Border.all(color: Colors.black45),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Material(
              color: Colors.transparent, // Containerの背景を利用
              child: InkWell(
                borderRadius: BorderRadius.circular(10), // タップエフェクトの形状
                onTap: () {
                  print('カメラボタンが押されました');

                  /// カメラボタンが押された時の処理
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => CameraScreen()),
                  );
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(
                      Icons.camera_alt, // カメラアイコン
                      color: Colors.white,
                      size: 40,
                    ),
                    SizedBox(height: 8), // アイコンとテキストの間隔
                    Text(
                      'カメラ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SizedBox(width: screenWidth * 0.03),
          Container(
            width: screenWidth * 0.4,
            height: screenWidth * 0.35,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Material(
              color: Colors.transparent, // Containerの背景を利用
              child: InkWell(
                borderRadius: BorderRadius.circular(10), // タップエフェクトの形状
                onTap: () async {
                  print('フォルダボタンが押されました');

                  /// フォルダボタンが押された時の処理

                  // 写真を選択
                  await _pickImage();

                  if (_galleryImageImage != null) {
                    // 選択した写真を渡して画面を切り替える
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            FoodRecognitionScreen(image: _galleryImageImage!),
                      ),
                    );
                  }
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.folder_open, color: Colors.white, size: 40),
                    SizedBox(height: 8), // アイコンとテキストの間隔
                    Text(
                      'フォルダ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          //SizedBox(width: screenWidth * 0.4 * 0.9),
        ],
      ),
    );
  }
}
