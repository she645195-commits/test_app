import 'package:flutter/material.dart';
import 'MealListScreen.dart';

Future<void> main() async {
  // データベースを使うための初期化
  WidgetsFlutterBinding.ensureInitialized();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meal Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: MealListScreen(),
    );
  }
}
