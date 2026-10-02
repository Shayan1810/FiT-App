import 'package:equatable/equatable.dart';

import 'nutrition_facts.dart';

/// Where a food definition comes from.
enum FoodOrigin {
  /// Created by the user ("My foods").
  custom,

  /// A user recipe exposed as a food (per serving).
  recipe,
}

/// A searchable food definition. Nutrition is stored **per 100 g**.
class FoodItem extends Equatable {
  const FoodItem({
    required this.id,
    required this.name,
    required this.per100g,
    required this.servingGrams,
    required this.servingLabel,
    this.aliases = const [],
    this.category = 'Other',
    this.origin = FoodOrigin.custom,
  });

  final String id;
  final String name;

  /// Alternative names used by search & the text parser (e.g. "chapati").
  final List<String> aliases;
  final String category;
  final NutritionFacts per100g;

  /// Weight of one typical serving, e.g. 40 g for "1 roti".
  final double servingGrams;

  /// Human label of one serving, e.g. "1 roti".
  final String servingLabel;
  final FoodOrigin origin;

  /// Nutrition for [grams] grams of this food.
  NutritionFacts factsFor(double grams) => per100g.scale(grams / 100);

  /// Nutrition for one serving.
  NutritionFacts get perServing => factsFor(servingGrams);

  @override
  List<Object?> get props => [id, name, per100g, servingGrams, servingLabel, origin];
}
