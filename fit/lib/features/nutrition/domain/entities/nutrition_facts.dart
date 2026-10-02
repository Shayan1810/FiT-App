import 'package:equatable/equatable.dart';

/// Energy and macronutrients for some amount of food.
///
/// Immutable value object; supports `+` and [scale] so totals are computed
/// by folding (e.g. `entries.fold(NutritionFacts.zero, (a, e) => a + e.facts)`).
class NutritionFacts extends Equatable {
  const NutritionFacts({
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.fiber = 0,
  });

  /// Kilocalories.
  final double kcal;

  /// Grams of protein / carbohydrate / fat / fibre.
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;

  static const NutritionFacts zero = NutritionFacts(kcal: 0, protein: 0, carbs: 0, fat: 0, fiber: 0);

  /// Sum of two fact sets.
  NutritionFacts operator +(NutritionFacts o) => NutritionFacts(
    kcal: kcal + o.kcal,
    protein: protein + o.protein,
    carbs: carbs + o.carbs,
    fat: fat + o.fat,
    fiber: fiber + o.fiber,
  );

  /// Multiplies every value by [factor] (e.g. grams / 100).
  NutritionFacts scale(double factor) => NutritionFacts(
    kcal: kcal * factor,
    protein: protein * factor,
    carbs: carbs * factor,
    fat: fat * factor,
    fiber: fiber * factor,
  );

  /// Energy implied by macros using Atwater factors (4/4/9 kcal per g).
  double get atwaterKcal => protein * 4 + carbs * 4 + fat * 9;

  /// Share of energy from each macro (0–1), based on Atwater energy.
  double get proteinShare => atwaterKcal == 0 ? 0 : protein * 4 / atwaterKcal;

  /// Share of energy from carbohydrate (0–1).
  double get carbShare => atwaterKcal == 0 ? 0 : carbs * 4 / atwaterKcal;

  /// Share of energy from fat (0–1).
  double get fatShare => atwaterKcal == 0 ? 0 : fat * 9 / atwaterKcal;

  Map<String, dynamic> toMap() => {
    'kcal': kcal,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'fiber': fiber,
  };

  factory NutritionFacts.fromMap(Map<String, dynamic> m) => NutritionFacts(
    kcal: (m['kcal'] as num?)?.toDouble() ?? 0,
    protein: (m['protein'] as num?)?.toDouble() ?? 0,
    carbs: (m['carbs'] as num?)?.toDouble() ?? 0,
    fat: (m['fat'] as num?)?.toDouble() ?? 0,
    fiber: (m['fiber'] as num?)?.toDouble() ?? 0,
  );

  @override
  List<Object?> get props => [kcal, protein, carbs, fat, fiber];
}
