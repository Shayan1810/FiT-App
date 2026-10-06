import 'dart:math';

import '../../features/nutrition/domain/entities/food_log_entry.dart';
import '../../features/nutrition/domain/entities/nutrition_facts.dart';
import '../../features/transformation/domain/entities/transformation_plan.dart';
import '../../features/transformation/domain/repositories/transformation_repository.dart';
import '../../features/workout/domain/entities/exercise.dart';
import '../../features/workout/domain/entities/workout_session.dart';
import '../utils/date_utils.dart';

/// A generic, realistic transformation used by "Load demo data", tests and
/// the screenshot generator. Contains no real person's data.
class DemoTransformation {
  DemoTransformation._();

  static PlannedExercise _x(String id, String name, MuscleGroup m, int sets, int reps, double kg) =>
      PlannedExercise(exerciseId: id, name: name, muscle: m, sets: sets, reps: reps, weightKg: kg);

  static PlanItem _meal(
    String id,
    String title,
    MealSlot slot,
    int time,
    String foods,
    double kcal,
    double p,
    double c,
    double f,
  ) => PlanItem(
    id: id,
    kind: PlanItemKind.meal,
    title: title,
    slot: slot,
    time: time,
    detail: foods,
    facts: NutritionFacts(kcal: kcal, protein: p, carbs: c, fat: f),
  );

  /// The demo plan, starting on [start].
  static TransformationPlan plan(DateTime start) => TransformationPlan(
    id: 'plan_demo',
    name: 'Summer Cut',
    start: DateKeys.startOfDay(start),
    end: DateKeys.startOfDay(start).add(const Duration(days: 83)),
    areas: const {GoalArea.body, GoalArea.skin},
    bodyGoal: BodyGoal.recomposition,
    startWeightKg: 74,
    startBodyFatPct: 21,
    goalWeightKg: 69,
    goalBodyFatPct: 15,
    macros: const MacroGoals(kcal: 2050, protein: 165, carbs: 205, fat: 62, fiber: 30, waterMl: 3000),
    stepsGoal: 9000,
    cardioMinutesGoal: 40,
    sleepHours: 8,
    bedtimeMin: 23 * 60,
    wakeMin: 7 * 60,
    items: [
      _meal(
        'm_breakfast',
        'Breakfast',
        MealSlot.breakfast,
        8 * 60,
        '80 g oats, 300 ml milk, 1 banana, 30 g whey',
        620,
        45,
        88,
        11,
      ),
      _meal(
        'm_lunch',
        'Lunch',
        MealSlot.lunch,
        13 * 60,
        '150 g chicken breast, 200 g rice, salad',
        640,
        52,
        70,
        14,
      ),
      _meal(
        'm_snack',
        'Snack',
        MealSlot.snacks,
        17 * 60,
        '200 g Greek yoghurt, 20 g almonds',
        300,
        22,
        14,
        17,
      ),
      _meal(
        'm_dinner',
        'Dinner',
        MealSlot.dinner,
        20 * 60,
        '3 eggs, 2 rotis, dal, vegetables',
        490,
        30,
        38,
        20,
      ),
      PlanItem(
        id: 'w_push',
        kind: PlanItemKind.workout,
        title: 'Push day',
        weekdays: const {1, 4},
        time: 7 * 60,
        durationMin: 60,
        rpe: 8,
        exercises: [
          _x('ex_bench', 'Bench press', MuscleGroup.chest, 4, 8, 60),
          _x('ex_ohp', 'Overhead press', MuscleGroup.shoulders, 3, 8, 35),
          _x('ex_incline_db', 'Incline dumbbell press', MuscleGroup.chest, 3, 10, 22),
          _x('ex_tricep_pushdown', 'Triceps pushdown', MuscleGroup.arms, 3, 12, 25),
        ],
      ),
      PlanItem(
        id: 'w_pull',
        kind: PlanItemKind.workout,
        title: 'Pull day',
        weekdays: const {2, 5},
        time: 7 * 60,
        durationMin: 60,
        rpe: 8,
        exercises: [
          _x('ex_deadlift', 'Deadlift', MuscleGroup.back, 3, 5, 100),
          _x('ex_pullup', 'Pull-up', MuscleGroup.back, 4, 8, 0),
          _x('ex_bb_row', 'Barbell row', MuscleGroup.back, 3, 10, 50),
          _x('ex_db_curl', 'Dumbbell curl', MuscleGroup.arms, 3, 12, 12),
        ],
      ),
      PlanItem(
        id: 'w_legs',
        kind: PlanItemKind.workout,
        title: 'Leg day',
        weekdays: const {3, 6},
        time: 7 * 60,
        durationMin: 65,
        rpe: 8,
        exercises: [
          _x('ex_squat', 'Back squat', MuscleGroup.legs, 4, 6, 80),
          _x('ex_rdl', 'Romanian deadlift', MuscleGroup.glutes, 3, 10, 60),
          _x('ex_leg_press', 'Leg press', MuscleGroup.legs, 3, 12, 140),
          _x('ex_calf_raise', 'Calf raise', MuscleGroup.legs, 4, 15, 60),
        ],
      ),
      const PlanItem(
        id: 'c_walk',
        kind: PlanItemKind.cardio,
        title: 'Evening walk',
        workoutType: WorkoutType.walk,
        time: 18 * 60 + 30,
        durationMin: 40,
        distanceKm: 3.5,
        rpe: 3,
      ),
      const PlanItem(
        id: 's_creatine',
        kind: PlanItemKind.supplement,
        title: 'Creatine',
        detail: '5 g with breakfast',
        time: 8 * 60 + 15,
      ),
      const PlanItem(
        id: 's_vitd',
        kind: PlanItemKind.supplement,
        title: 'Vitamin D3',
        detail: '1 capsule',
        time: 13 * 60 + 15,
      ),
      const PlanItem(
        id: 'skin_morning',
        kind: PlanItemKind.skincare,
        title: 'Morning skincare',
        routineSlot: RoutineSlot.morning,
        detail: 'Cleanser, vitamin C serum, moisturiser, sunscreen',
        time: 7 * 60 + 45,
      ),
      const PlanItem(
        id: 'skin_afternoon',
        kind: PlanItemKind.skincare,
        title: 'Afternoon skincare',
        routineSlot: RoutineSlot.afternoon,
        detail: 'Reapply sunscreen',
        time: 13 * 60 + 30,
      ),
      const PlanItem(
        id: 'skin_evening',
        kind: PlanItemKind.skincare,
        title: 'Evening skincare',
        routineSlot: RoutineSlot.evening,
        detail: 'Cleanser, retinol (3×/week), moisturiser',
        time: 22 * 60,
      ),
      const PlanItem(
        id: 'h_hair',
        kind: PlanItemKind.habit,
        title: 'Shampoo & conditioner',
        weekdays: {1, 3, 5},
        time: 7 * 60 + 40,
      ),
    ],
  );

  /// Saves the demo plan starting [daysAgo] days before [now], turns
  /// Transformation mode on and ticks ~85 % of each past day's checklist
  /// (marks only; the general demo data supplies the food and workouts).
  static Future<TransformationPlan> seed(
    TransformationRepository repo, {
    DateTime? now,
    int daysAgo = 17,
  }) async {
    final today = DateKeys.startOfDay(now ?? DateTime.now());
    final p = plan(today.subtract(Duration(days: daysAgo)));
    await repo.savePlan(p);
    await repo.setMode(AppMode.transformation);
    final rng = Random(7);
    for (var d = p.start; d.isBefore(today); d = d.add(const Duration(days: 1))) {
      for (final i in p.itemsFor(d)) {
        if (rng.nextDouble() < 0.88) await repo.setCheck(DateKeys.of(d), i.id, true);
      }
    }
    // Today: the morning is done.
    for (final i in p.itemsFor(today)) {
      if (i.sortTime < 9 * 60) await repo.setCheck(DateKeys.of(today), i.id, true);
    }
    return p;
  }
}
