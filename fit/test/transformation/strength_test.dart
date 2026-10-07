import 'package:fit/core/di/injector.dart';
import 'package:fit/core/dev/demo_transformation.dart';
import 'package:fit/core/utils/date_utils.dart';
import 'package:fit/features/transformation/domain/calculators/strength_calculator.dart';
import 'package:fit/features/transformation/domain/entities/transformation_plan.dart';
import 'package:fit/features/transformation/domain/repositories/transformation_repository.dart';
import 'package:fit/features/transformation/domain/usecases/toggle_plan_item.dart';
import 'package:fit/features/workout/domain/entities/exercise.dart';
import 'package:fit/features/workout/domain/entities/workout_session.dart';
import 'package:fit/features/workout/domain/repositories/workout_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_env.dart';

WorkoutSession _s(DateTime d, String id, List<(int, double)> sets) => WorkoutSession(
  id: id,
  start: d,
  title: 'Push',
  type: WorkoutType.strength,
  durationMin: 60,
  rpe: 8,
  sets: [
    for (final (r, kg) in sets)
      WorkoutSet(
        exerciseId: 'ex_bench',
        exerciseName: 'Bench press',
        muscle: MuscleGroup.chest,
        reps: r,
        weightKg: kg,
      ),
  ],
);

void main() {
  const bench = PlannedExercise(
    exerciseId: 'ex_bench',
    name: 'Bench press',
    muscle: MuscleGroup.chest,
    sets: 3,
    reps: 8,
    weightKg: 60,
  );
  final d0 = DateTime(2026, 10, 1, 7);

  group('progressive overload (double progression)', () {
    test('first session uses the planned load', () {
      final s = StrengthCalculator.suggest(bench, const []);
      expect((s.kg, s.reps, s.sets, s.isIncrease), (60.0, 8, 3, false));
    });

    test('all target reps done → +2.5 kg', () {
      final h = StrengthCalculator.history([
        _s(d0, 'a', [(8, 60), (8, 60), (9, 60)]),
      ], 'ex_bench');
      final s = StrengthCalculator.suggest(bench, h);
      expect(s.kg, 62.5);
      expect(s.isIncrease, isTrue);
    });

    test('missed reps → repeat the load', () {
      final h = StrengthCalculator.history([
        _s(d0, 'a', [(8, 60), (7, 60), (6, 60)]),
      ], 'ex_bench');
      final s = StrengthCalculator.suggest(bench, h);
      expect(s.kg, 60);
      expect(s.isIncrease, isFalse);
      expect(s.reason, contains('best last time: 8'));
    });

    test('light loads go up by 1 kg; bodyweight adds reps', () {
      const curl = PlannedExercise(
        exerciseId: 'c',
        name: 'Curl',
        muscle: MuscleGroup.arms,
        sets: 2,
        reps: 10,
      );
      expect(
        StrengthCalculator.suggest(curl, [
          ExercisePerformance(date: d0, sets: const [(10, 12), (10, 12)]),
        ]).kg,
        13,
      );
      final bw = StrengthCalculator.suggest(curl, [
        ExercisePerformance(date: d0, sets: const [(10, 0), (12, 0)]),
      ]);
      expect((bw.kg, bw.reps), (0.0, 13));
    });
  });

  test('strength change: first vs latest e1RM', () {
    final changes = StrengthCalculator.changes([
      _s(d0, 'a', [(8, 60), (8, 60)]),
      _s(d0.add(const Duration(days: 7)), 'b', [(8, 65), (8, 65)]),
    ]);
    final c = changes.single;
    expect(c.sessions, 2);
    expect(c.first.e1rm, closeTo(60 * (1 + 8 / 30), 1e-9));
    expect(c.e1rmChangePct, closeTo(65 / 60 * 100 - 100, 1e-9));
    expect(c.topKgChange, 5);
  });

  group('plan workouts', () {
    setUp(() => setUpTestEnv());
    tearDown(tearDownTestEnv);

    test('Log sets saves what was lifted; a later tick repeats it', () async {
      final repo = sl<TransformationRepository>();
      final toggle = sl<TogglePlanItem>();
      final today = DateKeys.startOfDay(DateTime.now());
      final plan = await DemoTransformation.seed(repo, daysAgo: 20);
      final push = plan.items.firstWhere((i) => i.id == 'w_push');
      final d1 = [for (var k = 14; k > 0; k--) today.subtract(Duration(days: k))].firstWhere(push.occursOn);
      final d2 = d1.add(const Duration(days: 7));

      final lifted = [
        for (final e in push.exercises)
          for (var k = 0; k < e.sets; k++)
            WorkoutSet(
              exerciseId: e.exerciseId,
              exerciseName: e.name,
              muscle: e.muscle,
              reps: e.reps,
              weightKg: e.weightKg + 5,
            ),
      ];
      await toggle.logWorkout(push, d1, sets: lifted, durationMin: 55, rpe: 8);
      final s1 = sl<WorkoutRepository>().sessions().firstWhere(
        (s) => s.id == TogglePlanItem.sessionId(DateKeys.of(d1), push),
      );
      expect(s1.sets.first.weightKg, push.exercises.first.weightKg + 5);
      expect(s1.durationMin, 55);
      expect(repo.checksFor(DateKeys.of(d1)), contains('w_push'));

      // Quick tick a week later repeats last time's weights, not the plan's.
      await toggle(plan, push, d2, true);
      final s2 = sl<WorkoutRepository>().sessions().firstWhere(
        (s) => s.id == TogglePlanItem.sessionId(DateKeys.of(d2), push),
      );
      expect(s2.sets.first.weightKg, push.exercises.first.weightKg + 5);

      // Overload advice builds on the logged sets.
      final hist = toggle.historyOf(push.exercises.first.exerciseId, before: d2);
      final sug = StrengthCalculator.suggest(push.exercises.first, hist);
      expect(sug.kg, push.exercises.first.weightKg + 5 + 2.5);
    });
  });
}
