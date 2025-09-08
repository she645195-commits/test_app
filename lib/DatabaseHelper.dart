import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

// 必要な機能
// 初回データベースのテーブル作成
// 起動時　データベースの全情報を取得（リスト化するのは呼び出し元か？）
// 画像保存時情報の登録

class DatabaseHelper {
  // DatabaseHelperのシングルトンインスタンスを初期化
  static final DatabaseHelper instance = DatabaseHelper._init();

  // データベース接続を保持する変数
  static Database? _database;

  // コンストラクタの定義
  DatabaseHelper._init();

  // _databaseがnullでない場合は既存の接続を返し、
  // nullの場合は_initDBを呼び出して初期化
  Future<Database> get database async {
    if (_database != null) {
      print('_database != null');
      return _database!;
    } else {
      print('_database == null');
      _database = await _initDB('calories.db');
      return _database!;
    }
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  // テーブルの作成
  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE calories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        time TEXT NOT NULL,
        name TEXT NOT NULL,
        calorie INTEGER,
        image_path TEXT
      )
    ''');
  }

  // Insert操作
  Future<int> insertCalories(Map<String, dynamic> calorieRecord) async {
    final db = await database;
    print("insertCalories CALL");
    return await db.insert('calories', calorieRecord);
  }

  // Query操作（全件取得）
  Future<List<Map<String, dynamic>>> getAllCalories() async {
    final db = await database;
    return await db.query('calories');
  }

  // Query操作（日付と時間で昇順に並べ替え）
  Future<List<Map<String, dynamic>>> getAllCaloriesSortedByDateTime() async {
    final db = await database;
    print("getAllCaloriesSortedByDateTime CALL");
    return await db.query('calories', orderBy: 'date DESC, time DESC');
  }

  // Query操作（ID指定）
  Future<Map<String, dynamic>?> getCaloriesById(int id) async {
    final db = await database;
    final result = await db.query(
      'calories',
      where: 'id = ?',
      whereArgs: [id],
    );
    return result.isNotEmpty ? result.first : null;
  }

  // Update操作
  Future<int> updateCalories(int id, Map<String, dynamic> todo) async {
    final db = await database;
    return await db.update(
      'calories',
      todo,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Delete操作
  Future<int> deleteCalories(int id) async {
    final db = await database;
    print("deleteCalories CALL");
    return await db.delete('calories', where: 'id = ?', whereArgs: [id]);
  }

  Future close() async {
    final db = await database;
    db.close();
  }
}
