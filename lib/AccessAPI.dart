import 'dart:convert';
import 'package:http/http.dart' as http;

/// 使用しない

// USDA FoodData Central API へのアクセスを行うクラス
// このAPIは食品名からカロリーや栄養素などの情報を取得できる

// APIからのレスポンスの形
// {
//    "foods": [
//      {
//        "fdcId": 1102647,
//        "description": "Apple, raw",
//        "foodNutrients": [
//          {"nutrientName": "Energy", "unitName": "KCAL", "value": 52.0},
//          {"nutrientName": "Protein", "unitName": "G", "value": 0.26},
//        ],
//      },
//    ],
//  };
class FoodDataService {
  final String apiKey = "wedln4UfPtK8kllersGFcZLqobpu8z83OeneVsrl"; // 取得したAPIキー

  // 引数で食品名を受け取り、その100グラムあたりのカロリーを返す
  Future<double?> searchFoodCalorie(String query) async {
    print("searchFoodCalorie() 1");
    final food = await _fetchFoodData(query);
    if (food != null) {
      String desc = food["description"];
      double? calories;

      for (var nutrient in food["foodNutrients"]) {
        if (nutrient["nutrientName"] == "Energy") {
          print("searchFoodCalorie() 2");
          print(nutrient["value"].runtimeType);
          calories = double.parse(nutrient["value"].toString());
          print("searchFoodCalorie() 3");
          return calories;
        }
      }
    } else {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchFoodData(String query) async {
    final url = Uri.parse(
      "https://api.nal.usda.gov/fdc/v1/foods/search?query=$query&api_key=$apiKey",
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data["foods"] != null && data["foods"].isNotEmpty) {
        return data["foods"][0]; // 先頭の食品を返す
      }
    }
    return null;
  }
}

// import 'package:flutter/material.dart';
// import 'food_data_service.dart';
//
// class FoodSearchScreen extends StatefulWidget {
//   @override
//   _FoodSearchScreenState createState() => _FoodSearchScreenState();
// }
//
// class _FoodSearchScreenState extends State<FoodSearchScreen> {
//   final FoodDataService _foodService = FoodDataService();
//   final TextEditingController _controller = TextEditingController();
//   String _result = "";
//
//   void _searchFood() async {
//     final food = await _foodService.fetchFoodData(_controller.text);
//     if (food != null) {
//       String desc = food["description"];
//       double? calories;
//
//       for (var nutrient in food["foodNutrients"]) {
//         if (nutrient["nutrientName"] == "Energy") {
//           calories = nutrient["value"];
//         }
//       }
//
//       setState(() {
//         _result = "$desc のカロリーは ${calories ?? "不明"} kcal";
//       });
//     } else {
//       setState(() {
//         _result = "食品が見つかりませんでした";
//       });
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text("食品検索")),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           children: [
//             TextField(
//               controller: _controller,
//               decoration: InputDecoration(labelText: "食品名を入力（例: apple）"),
//             ),
//             SizedBox(height: 10),
//             ElevatedButton(
//               onPressed: _searchFood,
//               child: Text("検索"),
//             ),
//             SizedBox(height: 20),
//             Text(_result),
//           ],
//         ),
//       ),
//     );
//   }
// }
