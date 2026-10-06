import 'dart:math';

import '../../features/activity/domain/entities/daily_activity.dart';
import '../../features/activity/domain/repositories/activity_repository.dart';
import '../../features/nutrition/domain/entities/food_item.dart';
import '../../features/nutrition/domain/entities/nutrition_facts.dart';
import '../../features/nutrition/domain/entities/food_log_entry.dart';
import '../../features/nutrition/domain/repositories/nutrition_repository.dart';
import '../../features/profile/domain/entities/user_profile.dart';
import '../../features/profile/domain/entities/weight_entry.dart';
import '../../features/profile/domain/repositories/profile_repository.dart';
import '../../features/sleep/domain/entities/sleep_session.dart';
import '../../features/sleep/domain/repositories/sleep_repository.dart';
import '../../features/workout/data/exercise_library.dart';
import '../../features/workout/domain/entities/workout_session.dart';
import '../../features/workout/domain/repositories/workout_repository.dart';
import '../storage/settings_store.dart';
import '../utils/date_utils.dart';

/// Fills the app with 3 weeks of realistic, deterministic data.
///
/// Used by Settings → "Load demo data", by widget tests, and by
/// `tool/generate_screenshots_test.dart` (handbook screenshots).
class DemoData {
  DemoData._();

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

  /// Foods used by the demo diary (saved to "My foods").
  static final List<FoodItem> _foods = [
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

  /// Writes [days] days of demo profile, food, steps, sleep, workouts and weights.
  static Future<void> seed({
    required ProfileRepository profile,
    required NutritionRepository nutrition,
    required ActivityRepository activity,
    required WorkoutRepository workouts,
    required SleepRepository sleep,
    required SettingsStore settings,
    DateTime? now,
    int days = 21,
  }) async {
    final rng = Random(42);
    final today = DateKeys.startOfDay(now ?? DateTime.now());
    await profile.saveProfile(
      UserProfile(
        name: 'Alex Morgan',
        sex: Sex.male,
        dateOfBirth: DateTime(1996, 4, 12),
        heightCm: 178,
        weightKg: 72,
        goal: GoalType.lose,
        weeklyRateKg: 0.4,
      ),
    );
    await settings.write(SettingsStore.kOnboarded, true);
    for (final f in _foods) {
      await nutrition.saveCustomFood(f);
    }

    final menu = <MealSlot, List<(String, double)>>{
      MealSlot.breakfast: [('oats', 60), ('milk', 250), ('banana', 118)],
      MealSlot.lunch: [('roti', 120), ('dal', 150), ('rice_white', 150), ('curd', 150)],
      MealSlot.snacks: [('chai', 150), ('almonds', 28), ('whey', 30)],
      MealSlot.dinner: [('chicken_curry', 200), ('roti', 80), ('salad', 100)],
    };

    for (var i = days - 1; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      final key = DateKeys.of(d);
      final isToday = i == 0;

      // Weight: gentle downward trend + daily water noise.
      if (i % 2 == 0 || i < 4) {
        final kg = 73.6 - (days - i) * 0.055 + (rng.nextDouble() - 0.5) * 0.9;
        await profile.logWeight(
          WeightEntry(
            dayKey: key,
            date: d.add(const Duration(hours: 7)),
            kg: double.parse(kg.toStringAsFixed(1)),
          ),
        );
      }

      // Food (today: only breakfast + lunch so far).
      for (final slot in MealSlot.values) {
        if (isToday && (slot == MealSlot.dinner || slot == MealSlot.snacks)) continue;
        for (final (id, grams) in menu[slot]!) {
          final food = _foods.firstWhere((f) => f.id == 'food_$id');
          final g = grams * (0.85 + rng.nextDouble() * 0.3);
          await nutrition.saveEntry(
            FoodLogEntry(
              id: FoodLogEntry.newId(key),
              dayKey: key,
              slot: slot,
              name: food.name,
              grams: g,
              facts: food.factsFor(g),
              source: EntrySource.custom,
              createdAt: d.add(Duration(hours: 8 + slot.index * 4)),
              foodId: food.id,
            ),
          );
        }
      }
      await nutrition.setWater(key, isToday ? 1250 : 2000 + rng.nextInt(6) * 250);

      // Steps from "Samsung Health".
      final steps = isToday ? 6420 : 5200 + rng.nextInt(6500);
      await activity.save(
        DailyActivity(
          dayKey: key,
          steps: steps,
          distanceKm: steps * 0.00073,
          restingHr: 58 + rng.nextInt(5).toDouble(),
          source: DataSource.healthConnect,
          syncedAt: d,
        ),
      );

      // Sleep ending this morning.
      final bedMin = 23 * 60 + rng.nextInt(80) - 30;
      final dur = isToday ? 400 : 390 + rng.nextInt(110);
      final start = d.subtract(const Duration(days: 1)).add(Duration(minutes: bedMin));
      await sleep.save(
        SleepSession(
          id: 'demo_sleep_$key',
          start: start,
          end: start.add(Duration(minutes: dur)),
          quality: 3 + rng.nextInt(3),
          source: DataSource.healthConnect,
        ),
      );

      // Training: push / pull / legs rotation 4×/week + a weekend run.
      final wd = d.weekday;
      if (wd == DateTime.monday ||
          wd == DateTime.wednesday ||
          wd == DateTime.friday ||
          wd == DateTime.tuesday) {
        final plan = switch (wd) {
          DateTime.monday => ['ex_bench', 'ex_ohp', 'ex_tricep_pushdown'],
          DateTime.tuesday => ['ex_pullup', 'ex_bb_row', 'ex_db_curl'],
          DateTime.wednesday => ['ex_squat', 'ex_rdl', 'ex_leg_curl'],
          _ => ['ex_incline_db', 'ex_lat_pulldown', 'ex_lateral_raise'],
        };
        final progress = (days - i) * 0.25;
        await workouts.save(
          WorkoutSession(
            id: 'demo_wo_$key',
            start: d.add(const Duration(hours: 18)),
            title: switch (wd) {
              DateTime.monday => 'Push',
              DateTime.tuesday => 'Pull',
              DateTime.wednesday => 'Legs',
              _ => 'Upper',
            },
            type: WorkoutType.strength,
            durationMin: 55 + rng.nextInt(20),
            rpe: 7 + rng.nextInt(2),
            sets: [
              for (final id in plan)
                for (var s = 0; s < 3; s++)
                  WorkoutSet(
                    exerciseId: id,
                    exerciseName: ExerciseLibrary.byId(id)!.name,
                    muscle: ExerciseLibrary.byId(id)!.muscle,
                    reps: 8 + rng.nextInt(3),
                    weightKg:
                        (id == 'ex_squat'
                            ? 80
                            : id == 'ex_bench'
                            ? 60
                            : 30) +
                        progress,
                  ),
            ],
          ),
        );
      } else if (wd == DateTime.sunday) {
        await workouts.save(
          WorkoutSession(
            id: 'demo_run_$key',
            start: d.add(const Duration(hours: 7)),
            title: 'Running',
            type: WorkoutType.run,
            durationMin: 32,
            rpe: 6,
            distanceKm: 5.2,
            deviceKcal: 340,
            source: DataSource.healthConnect,
          ),
        );
      }
    }
  }
}
