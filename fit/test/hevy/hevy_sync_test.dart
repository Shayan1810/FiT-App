import 'dart:convert';

import 'package:fit/core/di/injector.dart';
import 'package:fit/core/dev/demo_transformation.dart';
import 'package:fit/core/domain/data_source.dart';
import 'package:fit/core/network/retry_policy.dart';
import 'package:fit/core/storage/settings_store.dart';
import 'package:fit/core/utils/date_utils.dart';
import 'package:fit/features/hevy/data/hevy_client.dart';
import 'package:fit/features/hevy/data/hevy_sync.dart';
import 'package:fit/features/transformation/domain/repositories/transformation_repository.dart';
import 'package:fit/features/workout/domain/entities/exercise.dart';
import 'package:fit/features/workout/domain/repositories/workout_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../helpers/test_env.dart';

Map<String, dynamic> _workout(String id, DateTime start) => {
  'id': id,
  'title': 'Push (Hevy)',
  'start_time': start.toUtc().toIso8601String(),
  'end_time': start.add(const Duration(minutes: 62)).toUtc().toIso8601String(),
  'exercises': [
    {
      'title': 'Bench Press (Barbell)',
      'exercise_template_id': 'T1',
      'sets': [
        {'type': 'warmup', 'weight_kg': 40, 'reps': 10},
        {'type': 'normal', 'weight_kg': 70, 'reps': 8, 'rpe': 8},
        {'type': 'normal', 'weight_kg': 70, 'reps': 7, 'rpe': 9},
      ],
    },
    {
      'title': 'Cable Lateral Raise',
      'exercise_template_id': 'T2',
      'sets': [
        {'type': 'normal', 'weight_kg': 7.5, 'reps': 15},
      ],
    },
  ],
};

void main() {
  setUp(() => setUpTestEnv());
  tearDown(tearDownTestEnv);

  test('exercise names map to the FiT library or a stable custom id', () {
    final lib = sl<WorkoutRepository>().exercises();
    expect(HevySync.matchExercise('Bench Press (Barbell)', 'T1', lib).id, 'ex_bench');
    expect(HevySync.matchExercise('Deadlift (Barbell)', 'T', lib).id, 'ex_deadlift');
    expect(HevySync.matchExercise('Romanian Deadlift (Barbell)', 'T', lib).id, 'ex_rdl');
    final unknown = HevySync.matchExercise('Cable Lateral Raise', 'T2', lib);
    expect(unknown.muscle, MuscleGroup.shoulders);
    expect(HevySync.guessMuscle('hanging leg raise'), MuscleGroup.core);
    expect(HevySync.guessMuscle('incline treadmill walk'), MuscleGroup.cardio);
  });

  test('first sync imports workouts, skips warm-ups and ticks the planned workout', () async {
    final today = DateKeys.startOfDay(DateTime.now());
    final repo = sl<TransformationRepository>();
    final plan = await DemoTransformation.seed(repo, daysAgo: 6);
    final trainingDay = [
      for (var k = 1; k <= 6; k++) today.subtract(Duration(days: k)),
    ].firstWhere((d) => plan.workoutsOn(d).isNotEmpty);
    final key = DateKeys.of(trainingDay);
    for (final w in plan.workoutsOn(trainingDay)) {
      await repo.setCheck(key, w.id, false);
    }
    final calls = <String>[];
    final client = MockClient((req) async {
      calls.add(req.url.path);
      expect(req.headers['api-key'], 'secret');
      if (req.url.path == '/v1/workouts/count') return http.Response('{"workout_count": 1}', 200);
      if (req.url.path == '/v1/workouts') {
        return http.Response(
          jsonEncode({
            'page': 1,
            'page_count': 1,
            'workouts': [_workout('w1', trainingDay.add(const Duration(hours: 18)))],
          }),
          200,
        );
      }
      return http.Response('{}', 404);
    });
    final hevy = HevySync(
      client: HevyClient(client, retry: RetryPolicy(maxAttempts: 1, sleep: (_) async {})),
      settings: sl<SettingsStore>(),
      workouts: sl<WorkoutRepository>(),
      plans: repo,
    );
    expect(await hevy.connect('secret'), isNull);
    final r = await hevy.sync();
    expect(r.ok, isTrue, reason: r.error);
    expect(r.imported, 1);
    expect(r.planTicks, 1);
    final s = sl<WorkoutRepository>().sessions().firstWhere((x) => x.id == 'hevy_w1');
    expect(s.source, DataSource.hevy);
    expect(s.durationMin, 62);
    expect(s.sets.where((x) => x.exerciseId == 'ex_bench').map((x) => x.weightKg), [70, 70]);
    expect(s.rpe, 9);
    expect(
      repo.checksFor(key).intersection(plan.workoutsOn(trainingDay).map((w) => w.id).toSet()),
      hasLength(1),
    );
    expect(hevy.lastSync, isNotNull);
  });

  test('later syncs apply updates and deletions; bad keys are reported', () async {
    final now = DateTime.now();
    final client = MockClient((req) async {
      if (req.url.path == '/v1/workouts/count') return http.Response('{"workout_count": 2}', 200);
      if (req.url.path == '/v1/workouts') {
        return http.Response(
          jsonEncode({
            'page': 1,
            'page_count': 1,
            'workouts': [_workout('w1', now), _workout('w2', now)],
          }),
          200,
        );
      }
      if (req.url.path == '/v1/workouts/events') {
        return http.Response(
          jsonEncode({
            'page': 1,
            'page_count': 1,
            'events': [
              {'type': 'deleted', 'id': 'w1'},
              {'type': 'updated', 'workout': _workout('w3', now)},
            ],
          }),
          200,
        );
      }
      return http.Response('{}', 404);
    });
    final hevy = HevySync(
      client: HevyClient(client, retry: RetryPolicy(maxAttempts: 1, sleep: (_) async {})),
      settings: sl<SettingsStore>(),
      workouts: sl<WorkoutRepository>(),
    );
    await hevy.connect('k');
    await hevy.sync();
    final r2 = await hevy.sync();
    expect((r2.imported, r2.deleted), (1, 1));
    final ids = sl<WorkoutRepository>().sessions().map((s) => s.id).toSet();
    expect(ids.containsAll({'hevy_w2', 'hevy_w3'}), isTrue);
    expect(ids.contains('hevy_w1'), isFalse);

    final bad = HevySync(
      client: HevyClient(
        MockClient((_) async => http.Response('nope', 401)),
        retry: RetryPolicy(maxAttempts: 1, sleep: (_) async {}),
      ),
      settings: sl<SettingsStore>(),
      workouts: sl<WorkoutRepository>(),
    );
    expect(await bad.connect('wrong'), contains('rejected'));
  });
}
