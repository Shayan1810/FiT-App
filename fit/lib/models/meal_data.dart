import 'package:hive/hive.dart';
import 'food_item.dart';
import 'recipe.dart';

part 'meal_data.g.dart';

@HiveType(typeId: 3)
class MealData extends HiveObject {
  @HiveField(0)
  String mealName;

  @HiveField(1)
  String? note;

  // Your existing items list
  @HiveField(2)
  List<dynamic> items;

  // Add defaultValue here so old objects get an empty list
  @HiveField(3, defaultValue: <int>[])
  List<int> quantities;

  MealData({
    required this.mealName,
    this.note,
    List<dynamic>? items,
    List<int>? quantities,
  })  : this.items = items ?? [],
        this.quantities = quantities ?? [];

  double get totalProtein => _sum((i) =>
      i is FoodItem ? i.protein : i is Recipe ? i.totalProtein : 0);

  double get totalCarb => _sum((i) =>
      i is FoodItem ? i.carbohydrate : i is Recipe ? i.totalCarbohydrate : 0);

  double get totalFat => _sum((i) =>
      i is FoodItem ? i.fat : i is Recipe ? i.totalFat : 0);

  double get totalCalories => _sum((i) =>
      i is FoodItem ? i.calories : i is Recipe ? i.totalCalories : 0);

  double _sum(double Function(dynamic) metric) {
    double total = 0;
    for (var j = 0; j < items.length; j++) {
      final qty = (j < quantities.length) ? quantities[j] : 1;
      total += metric(items[j]) * qty;
    }
    return total;
  }
}
