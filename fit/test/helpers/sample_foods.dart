import 'package:fit/features/nutrition/domain/entities/food_item.dart';
import 'package:fit/features/nutrition/domain/entities/nutrition_facts.dart';

/// A handful of user-style foods (per 100 g, USDA / IFCT values) for tests.
class SampleFoods {
  SampleFoods._();

  static FoodItem _f(
    String id,
    String name,
    String category,
    double kcal,
    double protein,
    double carbs,
    double fat,
    double fiber,
    double servingGrams,
    String servingLabel, [
    List<String> aliases = const [],
  ]) => FoodItem(
    id: 'food_$id',
    name: name,
    category: category,
    per100g: NutritionFacts(kcal: kcal, protein: protein, carbs: carbs, fat: fat, fiber: fiber),
    servingGrams: servingGrams,
    servingLabel: servingLabel,
    aliases: aliases,
  );

  static final List<FoodItem> all = [
    _f('roti', 'Roti (whole wheat)', 'Grains', 280, 9.5, 50, 5, 7, 40, '1 roti', [
      'chapati',
      'chapatti',
      'phulka',
      'rotis',
      'chapatis',
    ]),
    _f('dal', 'Dal (cooked)', 'Legumes', 120, 6, 15, 4, 3, 150, '1 katori', [
      'daal',
      'dal tadka',
      'toor dal',
      'moong dal',
      'masoor dal',
      'lentil curry',
      'dal fry',
    ]),
    _f('banana', 'Banana', 'Fruit', 89, 1.1, 22.8, 0.3, 2.6, 118, '1 medium', ['bananas', 'kela']),
    _f('chicken_breast', 'Chicken breast (cooked)', 'Meat & fish', 165, 31, 0, 3.6, 0, 120, '1 breast', [
      'chicken',
      'grilled chicken',
      'boiled chicken',
    ]),
    _f('rice_white', 'White rice (cooked)', 'Grains', 130, 2.7, 28.2, 0.3, 0.4, 150, '1 cup', [
      'rice',
      'chawal',
      'steamed rice',
      'basmati rice',
      'plain rice',
    ]),
    _f('curd', 'Curd / yogurt (plain)', 'Dairy & eggs', 61, 3.5, 4.7, 3.3, 0, 150, '1 katori', [
      'dahi',
      'yogurt',
      'yoghurt',
    ]),
    _f('egg', 'Egg (whole)', 'Dairy & eggs', 143, 12.6, 0.7, 9.5, 0, 50, '1 egg', [
      'eggs',
      'boiled egg',
      'anda',
      'poached egg',
    ]),
    _f('chicken_biryani', 'Chicken biryani', 'Grains', 174, 8, 22, 6, 1, 300, '1 plate', [
      'biryani',
      'biriyani',
    ]),
    _f('oats', 'Oats (dry)', 'Grains', 389, 16.9, 66.3, 6.9, 10.6, 40, '½ cup', [
      'oatmeal',
      'rolled oats',
      'porridge oats',
    ]),
    _f('milk', 'Milk (whole)', 'Dairy & eggs', 61, 3.2, 4.8, 3.3, 0, 250, '1 glass', [
      'doodh',
      'full cream milk',
      'toned milk',
    ]),
    _f('chai', 'Tea with milk & sugar', 'Drinks', 40, 1.2, 6, 1.2, 0, 150, '1 cup', [
      'tea',
      'chai',
      'masala chai',
    ]),
    _f('almonds', 'Almonds', 'Nuts', 579, 21.2, 21.6, 49.9, 12.5, 28, '1 handful', ['badam', 'almond']),
    _f('whey', 'Whey protein', 'Supplements', 400, 78, 8, 6, 0, 30, '1 scoop', [
      'protein powder',
      'protein shake',
      'whey protein',
    ]),
    _f('chicken_curry', 'Chicken curry', 'Meat & fish', 149, 13, 4, 9, 1, 200, '1 bowl'),
    _f('salad', 'Green salad (no dressing)', 'Vegetables', 20, 1.3, 3.5, 0.2, 1.8, 100, '1 bowl', ['salad']),
  ];

  /// Looks up a sample food by its short id (e.g. `roti`).
  static FoodItem byId(String id) => all.firstWhere((f) => f.id == 'food_$id');
}
