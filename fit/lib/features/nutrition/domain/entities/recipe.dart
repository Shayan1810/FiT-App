import 'package:equatable/equatable.dart';

import 'food_item.dart';
import 'nutrition_facts.dart';

/// One ingredient line of a recipe.
class RecipeIngredient extends Equatable {
  const RecipeIngredient({required this.name, required this.grams, required this.facts, this.foodId});

  final String name;
  final double grams;

  /// Nutrition for [grams] of this ingredient (already scaled).
  final NutritionFacts facts;
  final String? foodId;

  @override
  List<Object?> get props => [name, grams, facts, foodId];
}

/// A user recipe ("Your Recipes" from the original app). Appears in food search as one
/// serving = total / [servings].
class Recipe extends Equatable {
  const Recipe({required this.id, required this.name, required this.servings, required this.ingredients});

  final String id;
  final String name;
  final int servings;
  final List<RecipeIngredient> ingredients;

  /// Nutrition of the whole pot.
  NutritionFacts get total => ingredients.fold(NutritionFacts.zero, (a, i) => a + i.facts);

  /// Total cooked weight (sum of ingredient grams).
  double get totalGrams => ingredients.fold(0.0, (a, i) => a + i.grams);

  /// Nutrition of one serving.
  NutritionFacts get perServing => total.scale(1 / (servings <= 0 ? 1 : servings));

  /// This recipe as a searchable [FoodItem] (per-100 g normalised).
  FoodItem toFoodItem() {
    final grams = totalGrams <= 0 ? 100.0 : totalGrams;
    final serving = grams / (servings <= 0 ? 1 : servings);
    return FoodItem(
      id: id,
      name: name,
      per100g: total.scale(100 / grams),
      servingGrams: serving,
      servingLabel: '1 serving',
      category: 'My recipes',
      origin: FoodOrigin.recipe,
    );
  }

  @override
  List<Object?> get props => [id, name, servings, ingredients];
}
