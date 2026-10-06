import 'package:fit/core/di/injector.dart';
import 'package:fit/core/dev/demo_transformation.dart';
import 'package:fit/core/utils/date_utils.dart';
import 'package:fit/features/insights/domain/usecases/build_health_snapshot.dart';
import 'package:fit/features/insights/domain/usecases/generate_briefing.dart';
import 'package:fit/features/nutrition/domain/entities/food_log_entry.dart';
import 'package:fit/features/nutrition/domain/entities/nutrition_facts.dart';
import 'package:fit/features/nutrition/domain/repositories/nutrition_repository.dart';
import 'package:fit/features/profile/domain/entities/user_profile.dart';
import 'package:fit/features/profile/domain/repositories/profile_repository.dart';
import 'package:fit/features/sleep/domain/repositories/sleep_repository.dart';
import 'package:fit/features/transformation/domain/calculators/transformation_calculator.dart';
import 'package:fit/features/transformation/domain/repositories/transformation_repository.dart';
import 'package:fit/features/transformation/domain/usecases/toggle_plan_item.dart';
import 'package:fit/features/transformation/presentation/transformation_cubit.dart';
import 'package:fit/features/workout/domain/repositories/workout_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_env.dart';

UserProfile _profile() => UserProfile(
  name: 'Sam Test',
  sex: Sex.male,
  dateOfBirth: DateTime(1995, 1, 1),
  heightCm: 178,
  weightKg: 74,
  bodyFatPct: 21,
);

void main() {
  setUp(() => setUpTestEnv());
  tearDown(tearDownTestEnv);

  test('ticking logs the real record; unticking removes it', () async {
    final repo = sl<TransformationRepository>();
    final toggle = sl<TogglePlanItem>();
    final today = DateKeys.startOfDay(DateTime.now());
    final plan = await DemoTransformation.seed(repo, daysAgo: 3);
    final day = today;
    final key = DateKeys.of(day);
    final meal = plan.items.firstWhere((i) => i.id == 'm_lunch');

    await toggle(plan, meal, day, true);
    final entry = sl<NutritionRepository>()
        .entriesForDay(key)
        .where((e) => e.source == EntrySource.plan)
        .single;
    expect(entry.facts.kcal, 640);
    expect(entry.slot, MealSlot.lunch);
    expect(repo.checksFor(key), contains('m_lunch'));
    await toggle(plan, meal, day, true); // idempotent
    expect(
      sl<NutritionRepository>().entriesForDay(key).where((e) => e.source == EntrySource.plan),
      hasLength(1),
    );
    await toggle(plan, meal, day, false);
    expect(sl<NutritionRepository>().entriesForDay(key).where((e) => e.source == EntrySource.plan), isEmpty);
    expect(repo.checksFor(key), isNot(contains('m_lunch')));

    // Workout → session with sets × reps × kg.
    final wday = [
      for (var k = 0; k < 7; k++) today.subtract(Duration(days: k)),
    ].firstWhere((d) => plan.workoutsOn(d).isNotEmpty && plan.contains(d), orElse: () => today);
    if (plan.workoutsOn(wday).isNotEmpty) {
      final w = plan.workoutsOn(wday).first;
      await toggle(plan, w, wday, true);
      final s = sl<WorkoutRepository>().sessions().firstWhere(
        (x) => x.id == TogglePlanItem.sessionId(DateKeys.of(wday), w),
      );
      expect(s.sets.length, w.exercises.fold<int>(0, (a, e) => a + e.sets));
      expect(s.durationMin, w.durationMin);
    }

    // Sleep → last night at the planned times.
    await toggle(plan, plan.sleepItem, day, true);
    final night = sl<SleepRepository>().sessions().firstWhere((s) => s.id == TogglePlanItem.sleepId(key));
    expect(night.minutes, 8 * 60);
    await toggle(plan, plan.sleepItem, day, false);
    expect(sl<SleepRepository>().sessions().where((s) => s.id == TogglePlanItem.sleepId(key)), isEmpty);
  });

  test('fat lost comes from the energy deficit, not the scale', () async {
    await sl<ProfileRepository>().saveProfile(_profile());
    final repo = sl<TransformationRepository>();
    final today = DateKeys.startOfDay(DateTime.now());
    await DemoTransformation.seed(repo, daysAgo: 10);
    // Eat 1 200 kcal on the 10 completed days.
    for (var k = 1; k <= 10; k++) {
      final d = today.subtract(Duration(days: k));
      await sl<NutritionRepository>().saveEntry(
        FoodLogEntry(
          id: FoodLogEntry.newId(DateKeys.of(d)),
          dayKey: DateKeys.of(d),
          slot: MealSlot.lunch,
          name: 'Food',
          grams: 500,
          facts: const NutritionFacts(kcal: 1200, protein: 150, carbs: 80, fat: 30),
          source: EntrySource.manual,
          createdAt: d.add(const Duration(hours: 12)),
        ),
      );
    }
    final snap = sl<BuildHealthSnapshot>()()!;
    expect(snap.transformation, isNotNull);
    final st = TransformationCalculator.compute(
      input: snap.transformation!,
      profile: snap.profile,
      weights: snap.weights,
      now: snap.now,
    );
    expect(st.dayNumber, 11);
    expect(st.countedDays, 10);
    expect(st.netKcal, lessThan(0));
    expect(st.fatLostKg, closeTo(-st.netKcal / 7700, 1e-9));
    expect(st.estimatedWeightKg, closeTo(74 - st.fatLostKg, 1e-9));
    expect(st.estimatedBodyFatPct, lessThan(21));
    expect(st.adherenceAll, inInclusiveRange(0.6, 1.0));
    expect(st.today, isNotNull);
    expect(st.yesterday!.dayNumber, 10);
  });

  test('briefing follows the plan in Transformation mode only', () async {
    await sl<ProfileRepository>().saveProfile(_profile());
    final repo = sl<TransformationRepository>();
    final plan = await DemoTransformation.seed(repo, daysAgo: 5);
    final gen = GenerateBriefing(sl<BuildHealthSnapshot>(), useIsolate: false);

    var b = (await gen())!;
    expect(b.transformation, isNotNull);
    expect(b.today.targets.kcal, plan.macros.kcal);
    expect(b.today.targets.protein, plan.macros.protein);
    expect(b.today.stepTarget, 9000);
    expect(b.narrative.first, contains('Day 6 of 84'));
    expect(b.insights.any((i) => i.id.startsWith('plan_')), isTrue);
    expect(DateKeys.clock(b.plan.bedtime), '23:00');
    expect(DateKeys.clock(b.plan.wake), '07:00');
    final tomorrow = DateKeys.startOfDay(DateTime.now()).add(const Duration(days: 1));
    expect(b.plan.training.isRest, plan.isRestDay(tomorrow));

    await repo.setMode(AppMode.general);
    b = (await gen())!;
    expect(b.transformation, isNull);
    expect(b.narrative.first, isNot(contains('Day 6')));
  });

  test('a finished transformation switches back to General mode', () async {
    await sl<ProfileRepository>().saveProfile(_profile());
    final repo = sl<TransformationRepository>();
    await DemoTransformation.seed(repo, daysAgo: 90); // 84-day plan → ended
    expect(repo.mode, AppMode.transformation);
    final cubit = TransformationCubit(
      repo: repo,
      toggle: sl<TogglePlanItem>(),
      profile: sl<ProfileRepository>(),
    );
    await cubit.start();
    expect(repo.mode, AppMode.general);
    expect(cubit.state.isActive(DateTime.now()), isFalse);
    expect(await cubit.setMode(AppMode.transformation), isFalse);
    await cubit.close();
  });

  test('saving a plan seeds the profile and imports/exports', () async {
    await sl<ProfileRepository>().saveProfile(_profile());
    final repo = sl<TransformationRepository>();
    final cubit = TransformationCubit(
      repo: repo,
      toggle: sl<TogglePlanItem>(),
      profile: sl<ProfileRepository>(),
    );
    await cubit.start();
    final plan = DemoTransformation.plan(
      DateKeys.startOfDay(DateTime.now()).subtract(const Duration(days: 2)),
    );
    expect(await cubit.import(repo.exportPlan(plan)), isNull);
    expect(repo.mode, AppMode.transformation);
    expect(repo.activePlan(), plan);
    final weights = sl<ProfileRepository>().getWeights();
    expect(weights.any((w) => w.dayKey == DateKeys.of(plan.start) && w.kg == 74), isTrue);
    expect(await cubit.import('{"format":"fit-plan"}'), isNotNull);
    await cubit.deletePlan();
    expect(repo.activePlan(), isNull);
    expect(repo.mode, AppMode.general);
    await cubit.close();
  });
}
