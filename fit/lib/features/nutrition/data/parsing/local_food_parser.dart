import '../../domain/entities/food_item.dart';
import '../../domain/entities/nutrition_analysis.dart';
import 'food_matcher.dart';
import 'quantity_parser.dart';

/// Stage 2 of the nutrition pipeline: understands meal text **offline**
/// using the built-in + custom food databases.
///
/// "2 roti, 1 katori dal and a banana" →
///   roti × 2 servings (80 g) + dal 150 g + banana 118 g.
class LocalFoodParser {
  LocalFoodParser._();

  /// Minimum match score for a fragment to count as recognised.
  static const double acceptScore = 0.72;

  /// Analyses [text] against [foods]. Unrecognised fragments are listed in
  /// `unmatched`; the caller decides whether to escalate to Gemini.
  static NutritionAnalysis analyze(String text, List<FoodItem> foods) {
    final items = <AnalyzedItem>[];
    final unmatched = <String>[];
    for (final fragment in QuantityParser.split(text)) {
      final q = QuantityParser.parse(fragment);
      if (q.foodText.isEmpty) continue;
      final hits = FoodMatcher.rank(q.foodText, foods, minScore: acceptScore, limit: 1);
      if (hits.isEmpty) {
        unmatched.add(fragment);
        continue;
      }
      final food = hits.first.food;
      final grams = gramsFor(q, food);
      items.add(
        AnalyzedItem(
          name: food.name,
          grams: grams,
          facts: food.factsFor(grams),
          confidence: hits.first.score,
          foodId: food.id,
        ),
      );
    }
    return NutritionAnalysis(
      query: text,
      items: items,
      source: AnalysisSource.localDatabase,
      unmatched: unmatched,
    );
  }

  /// Converts a parsed quantity into grams for [food].
  ///
  /// * g / kg / ml / l → direct conversion (1 mL ≈ 1 g);
  /// * a household unit that appears in the food's serving label (e.g.
  ///   "1 slice", "1 cup") → that many servings;
  /// * other household units → standard household grams;
  /// * no unit / "piece" / "serving" → amount × serving grams.
  static double gramsFor(ParsedQuantity q, FoodItem food) {
    switch (q.unit) {
      case 'g':
      case 'ml':
        return q.amount;
      case 'kg':
      case 'l':
        return q.amount * 1000;
      case null:
      case 'piece':
      case 'serving':
        return q.amount * food.servingGrams;
      default:
        final label = food.servingLabel.toLowerCase();
        final unitWords =
            {
              'bowl': ['bowl', 'katori'],
              'cup': ['cup', 'mug'],
              'glass': ['glass'],
              'plate': ['plate'],
              'slice': ['slice'],
              'scoop': ['scoop'],
              'tbsp': ['tbsp'],
              'tsp': ['tsp'],
            }[q.unit] ??
            [q.unit!];
        if (unitWords.any(label.contains)) return q.amount * food.servingGrams;
        return q.amount * (QuantityParser.householdGrams[q.unit] ?? food.servingGrams);
    }
  }
}
