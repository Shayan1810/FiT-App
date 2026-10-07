import 'package:fit/core/di/injector.dart';
import 'package:fit/core/storage/hive_boxes.dart';
import 'package:fit/features/insights/domain/usecases/build_health_snapshot.dart';
import 'package:fit/features/insights/domain/usecases/generate_briefing.dart';
import 'package:fit/features/profile/domain/repositories/profile_repository.dart';
import 'package:fit/features/transformation/domain/repositories/transformation_repository.dart';
import 'package:fit/features/workout/domain/repositories/workout_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_env.dart';

/// Records exactly as v2.0.0 wrote them must keep working after updating.
void main() {
  setUp(() => setUpTestEnv());
  tearDown(tearDownTestEnv);

  test('v2.0.0 data is read unchanged by this version', () async {
    final now = DateTime.now();
    await HiveBoxes.box(HiveBoxes.profile).put('me', {
      'name': 'Sam',
      'sex': 'male',
      'dob': DateTime(1995, 1, 1).millisecondsSinceEpoch,
      'heightCm': 178.0,
      'weightKg': 90.0,
      'bodyFatPct': 30.0,
      'goal': 'lose',
      'weeklyRateKg': 0.7,
      'photoPath': null,
      // v2.0.0 had no newer fields
    });
    await HiveBoxes.box(HiveBoxes.workouts).put('wo_1', {
      'id': 'wo_1',
      'start': now.subtract(const Duration(days: 1)).millisecondsSinceEpoch,
      'title': 'Push',
      'type': 'strength',
      'durationMin': 60,
      'rpe': 8,
      'sets': [
        {
          'exerciseId': 'ex_bench',
          'exerciseName': 'Bench press',
          'muscle': 'chest',
          'reps': 8,
          'weightKg': 60.0,
        },
      ],
      'source': 'manual',
    });
    final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
    String d(DateTime x) =>
        '${x.year}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
    await HiveBoxes.box(HiveBoxes.transformation).put('plan_x', {
      'format': 'fit-plan',
      'version': 1,
      'id': 'plan_x',
      'name': 'Phase 1',
      'start': d(start),
      'end': d(start.add(const Duration(days: 69))),
      'areas': ['body', 'skin'],
      'bodyGoal': 'recomposition',
      'startWeightKg': 90.0,
      'startBodyFatPct': 30.0,
      'goalWeightKg': 82.0,
      'macros': {'kcal': 1900.0, 'protein': 140.0, 'carbs': 180.0, 'fat': 60.0},
      'sleep': {'hours': 9.0, 'bedtime': '22:00', 'wake': '07:00'},
      'items': [
        {
          'id': 'm1',
          'kind': 'meal',
          'title': 'Breakfast',
          'slot': 'breakfast',
          'time': '08:00',
          'facts': {'kcal': 600.0, 'protein': 40.0, 'carbs': 70.0, 'fat': 15.0},
        },
      ],
    });
    await HiveBoxes.box(HiveBoxes.settings).put('active_plan', 'plan_x');
    await HiveBoxes.box(HiveBoxes.settings).put('app_mode', 'transformation');
    await HiveBoxes.box(HiveBoxes.settings).put('onboarded', true);
    await HiveBoxes.box(HiveBoxes.planChecks).put('${d(start)}#m1@plan_x', now.millisecondsSinceEpoch);

    final p = sl<ProfileRepository>().getProfile()!;
    expect((p.name, p.weightKg, p.bmrAdjustPct), ('Sam', 90.0, 0.0));
    expect(sl<WorkoutRepository>().sessions().single.sets.single.weightKg, 60);
    final repo = sl<TransformationRepository>();
    expect(repo.mode, AppMode.transformation);
    expect(repo.activePlan()!.name, 'Phase 1');
    expect(repo.checksFor(d(start)), {'m1'});

    final b = (await GenerateBriefing(sl<BuildHealthSnapshot>(), useIsolate: false)())!;
    expect(b.transformation, isNotNull);
    expect(b.transformation!.strength.single.name, 'Bench press');
  });
}
