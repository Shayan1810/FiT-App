import 'package:hive/hive.dart';

part 'recipe.g.dart';

@HiveType(typeId: 1)
class RecipeIngredient extends HiveObject {
  @HiveField(0)
  late String foodItemName; // Store food item name for reference
  
  @HiveField(1)
  late double quantity; // Quantity of this ingredient
  
  @HiveField(2)
  late String unit; // Unit from the food item
  
  @HiveField(3)
  late double calories; // Calculated calories
  
  @HiveField(4)
  late double protein; // Calculated protein
  
  @HiveField(5)
  late double carbohydrate; // Calculated carbohydrate
  
  @HiveField(6)
  late double fat; // Calculated fat

  RecipeIngredient({
    required this.foodItemName,
    required this.quantity,
    required this.unit,
    required this.calories,
    required this.protein,
    required this.carbohydrate,
    required this.fat,
  });
}

@HiveType(typeId: 2)
class Recipe extends HiveObject {
  @HiveField(0)
  late String name;

  @HiveField(1)
  late String tag;

  @HiveField(2)
  late String unit; // Unit for the whole recipe (e.g., "1 serving", "2 portions")

  @HiveField(3)
  late List<RecipeIngredient> ingredients;

  @HiveField(4)
  late double totalCalories;

  @HiveField(5)
  late double totalProtein;

  @HiveField(6)
  late double totalCarbohydrate;

  @HiveField(7)
  late double totalFat;

  Recipe({
    required this.name,
    required this.tag,
    required this.unit,
    required this.ingredients,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbohydrate,
    required this.totalFat,
  });

  // Calculate totals from ingredients
  void calculateTotals() {
    totalCalories = ingredients.fold(0.0, (sum, ingredient) => sum + ingredient.calories);
    totalProtein = ingredients.fold(0.0, (sum, ingredient) => sum + ingredient.protein);
    totalCarbohydrate = ingredients.fold(0.0, (sum, ingredient) => sum + ingredient.carbohydrate);
    totalFat = ingredients.fold(0.0, (sum, ingredient) => sum + ingredient.fat);
  }
}
