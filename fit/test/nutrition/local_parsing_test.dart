import 'package:fit/features/nutrition/data/parsing/food_matcher.dart';
import 'package:fit/features/nutrition/data/parsing/local_food_parser.dart';
import 'package:fit/features/nutrition/data/parsing/quantity_parser.dart';
import 'package:fit/features/nutrition/domain/entities/nutrition_analysis.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sample_foods.dart';

void main() {
  group('QuantityParser', () {
    test('digits, glued units, fractions, words', () {
      var q = QuantityParser.parse('200g paneer');
      expect((q.amount, q.unit, q.foodText), (200, 'g', 'paneer'));
      q = QuantityParser.parse('2 cups of rice');
      expect((q.amount, q.unit, q.foodText), (2, 'cup', 'rice'));
      q = QuantityParser.parse('1/2 cup oats');
      expect((q.amount, q.unit), (0.5, 'cup'));
      q = QuantityParser.parse('half a banana');
      expect((q.amount, q.unit, q.foodText), (0.5, null, 'banana'));
      q = QuantityParser.parse('a glass of milk');
      expect((q.amount, q.unit, q.foodText), (1, 'glass', 'milk'));
      q = QuantityParser.parse('3 large eggs');
      expect((q.amount, q.foodText), (3, 'eggs'));
      q = QuantityParser.parse('1 katori dal');
      expect((q.unit, q.foodText), ('bowl', 'dal'));
    });

    test('splits meal text into fragments', () {
      expect(QuantityParser.split('2 roti, dal and curd + salad'), ['2 roti', 'dal', 'curd', 'salad']);
    });
  });

  group('FoodMatcher', () {
    test('exact, alias, plural and typo matches', () {
      String best(String q) => FoodMatcher.rank(q, SampleFoods.all, limit: 1).first.food.id;
      expect(best('roti'), 'food_roti');
      expect(best('chapati'), 'food_roti');
      expect(best('chapatis'), 'food_roti');
      expect(best('chapti'), 'food_roti'); // typo
      expect(best('dahi'), 'food_curd');
      expect(best('eggs'), 'food_egg');
      expect(best('chicken biryani'), 'food_chicken_biryani');
    });

    test('normalize singularises plurals', () {
      expect(FoodMatcher.normalize('Tomatoes!'), 'tomato');
      expect(FoodMatcher.normalize('Strawberries'), 'strawberry');
    });
  });

  group('LocalFoodParser', () {
    test('analyses a typical Indian meal fully offline', () {
      final a = LocalFoodParser.analyze('2 roti, 1 katori dal and a banana', SampleFoods.all);
      expect(a.isComplete, isTrue);
      expect(a.source, AnalysisSource.localDatabase);
      expect(a.items.map((i) => i.foodId), ['food_roti', 'food_dal', 'food_banana']);
      // 2 × 40 g roti = 80 g → 224 kcal; dal 150 g → 180 kcal; banana 118 g → 105 kcal
      expect(a.items[0].grams, 80);
      expect(a.total.kcal, closeTo(224 + 180 + 105, 2));
    });

    test('grams and household units', () {
      final a = LocalFoodParser.analyze('150g chicken breast, 1 cup rice', SampleFoods.all);
      expect(a.items[0].grams, 150);
      expect(a.items[0].facts.protein, closeTo(46.5, 0.1));
      expect(a.items[1].grams, 150); // rice serving label is "1 cup" → 1 serving
    });

    test('reports unknown fragments instead of guessing', () {
      final a = LocalFoodParser.analyze('2 roti and a quokka steak', SampleFoods.all);
      expect(a.items, hasLength(1));
      expect(a.unmatched, ['a quokka steak']);
      expect(a.isComplete, isFalse);
    });
  });

  group('SampleFoods', () {
    test('ids are unique', () {
      final ids = SampleFoods.all.map((f) => f.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    // USDA "carbohydrate" is by difference and includes fibre, which yields
    // ~2 kcal/g rather than 4, so the check uses fibre-adjusted Atwater.
    test('energy agrees with fibre-adjusted Atwater within 15 % (alcohol excepted)', () {
      for (final f in SampleFoods.all) {
        final p = f.per100g;
        if (p.kcal < 20) continue;
        final atwater = p.protein * 4 + (p.carbs - p.fiber) * 4 + p.fiber * 2 + p.fat * 9;
        expect((atwater - p.kcal).abs() / p.kcal, lessThan(0.15), reason: f.name);
      }
    });
  });
}
