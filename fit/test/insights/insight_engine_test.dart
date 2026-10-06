import 'package:bloc_test/bloc_test.dart';
import 'package:fit/core/dev/demo_data.dart';
import 'package:fit/core/di/injector.dart';
import 'package:fit/core/storage/settings_store.dart';
import 'package:fit/features/activity/domain/repositories/activity_repository.dart';
import 'package:fit/features/insights/domain/calculators/recovery_calculator.dart';
import 'package:fit/features/insights/domain/usecases/build_health_snapshot.dart';
import 'package:fit/features/insights/domain/usecases/generate_briefing.dart';
import 'package:fit/features/insights/presentation/bloc/insights_bloc.dart';
import 'package:fit/features/nutrition/domain/repositories/nutrition_repository.dart';
import 'package:fit/features/profile/domain/repositories/profile_repository.dart';
import 'package:fit/features/sleep/domain/repositories/sleep_repository.dart';
import 'package:fit/features/workout/domain/repositories/workout_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_env.dart';

Future<void> seed() => DemoData.seed(
  profile: sl<ProfileRepository>(),
  nutrition: sl<NutritionRepository>(),
  activity: sl<ActivityRepository>(),
  workouts: sl<WorkoutRepository>(),
  sleep: sl<SleepRepository>(),
  settings: sl<SettingsStore>(),
);

void main() {
  setUp(() => setUpTestEnv());
  tearDown(tearDownTestEnv);

  test('no profile → no briefing (onboarding needed)', () async {
    expect(await GenerateBriefing(sl<BuildHealthSnapshot>(), useIsolate: false)(), isNull);
  });

  test('3 weeks of data → full, consistent briefing', () async {
    await seed();
    final b = (await GenerateBriefing(sl<BuildHealthSnapshot>(), useIsolate: false)())!;

    expect(b.greeting, contains('Alex'));
    expect(b.narrative.length, greaterThanOrEqualTo(3));
    expect(b.recovery.score, inInclusiveRange(0, 100));
    expect(b.week, hasLength(7));
    expect(b.weightTrend, isNotEmpty);
    expect(b.today.tdeeMethod, startsWith('Adaptive'));

    // Goal is fat loss → tomorrow's target sits below expected expenditure.
    expect(b.plan.targets.goalDeltaKcal, lessThan(0));
    expect(b.plan.targets.protein, closeTo(sl<ProfileRepository>().getProfile()!.weightKg * 2.0, 0.01));
    expect(b.plan.steps, inInclusiveRange(5000, 10000));
    expect(b.plan.bedtime.isBefore(b.plan.wake), isTrue);
    // Every insight is justified.
    for (final i in b.insights) {
      expect(i.why, isNotEmpty);
      expect(i.reference, isNotEmpty);
    }
  });

  test('runs in a background isolate', () async {
    await seed();
    final b = await GenerateBriefing(sl<BuildHealthSnapshot>())();
    expect(b, isNotNull);
    expect(Readiness.values, contains(b!.recovery.readiness));
  });

  blocTest<InsightsBloc, InsightsState>(
    'InsightsBloc emits loading → ready',
    setUp: seed,
    build: () => InsightsBloc(
      generate: GenerateBriefing(sl<BuildHealthSnapshot>(), useIsolate: false),
      changes: const Stream.empty(),
    ),
    act: (b) => b.add(const InsightsStarted()),
    expect: () => [
      isA<InsightsState>().having((s) => s.status, 'status', InsightsStatus.loading),
      isA<InsightsState>().having((s) => s.status, 'status', InsightsStatus.ready),
    ],
  );
}
