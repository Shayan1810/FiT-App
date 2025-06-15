import 'package:hive/hive.dart';

part 'food_item.g.dart';

@HiveType(typeId: 5)
class FoodItem extends HiveObject {
  @HiveField(0)
  late String name;

  @HiveField(1)
  late String tag;

  @HiveField(2)
  late String unit;

  @HiveField(3)
  late double calories;

  @HiveField(4)
  late double protein;

  @HiveField(5)
  late double carbohydrate;

  @HiveField(6)
  late double fat;

  FoodItem({
    required this.name,
    required this.tag,
    required this.unit,
    required this.calories,
    required this.protein,
    required this.carbohydrate,
    required this.fat,
  });

  // Calculate total macronutrients
  double get totalMacros => protein + carbohydrate + fat;
  
  // Calculate calories per gram for scaling
  double get caloriesPerGram => calories / _parseUnitAmount();
  
  double _parseUnitAmount() {
    // Extract numeric value from unit (e.g., "100g" -> 100)
    RegExp regex = RegExp(r'(\d+(?:\.\d+)?)');
    Match? match = regex.firstMatch(unit);
    return match != null ? double.parse(match.group(1)!) : 1.0;
  }
}
