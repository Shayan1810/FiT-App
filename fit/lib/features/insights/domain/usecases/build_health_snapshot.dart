import 'dart:math';

import '../../../../core/utils/date_utils.dart';
import '../../../activity/domain/repositories/activity_repository.dart';
import '../../../nutrition/domain/entities/nutrition_facts.dart';
import '../../../nutrition/domain/repositories/nutrition_repository.dart';
import '../../../profile/domain/repositories/profile_repository.dart';
import '../../../sleep/domain/repositories/sleep_repository.dart';
import '../../../workout/domain/entities/workout_session.dart';
import '../../../workout/domain/repositories/workout_repository.dart';
import '../../../transformation/domain/calculators/transformation_calculator.dart';
import '../../../transformation/domain/repositories/transformation_repository.dart';
import '../entities/health_snapshot.dart';

/// Use case: gathers 28 days of data from every repository into an
/// immutable [HealthSnapshot]. Only fast, in-memory Hive reads happen here.
class BuildHealthSnapshot {
  BuildHealthSnapshot({
    required ProfileRepository profile,
    required NutritionRepository nutrition,
    required ActivityRepository activity,
    required WorkoutRepository workouts,
    required SleepRepository sleep,
    TransformationRepository? transformation,
  }) : _transformation = transformation,
       _profile = profile,
       _nutrition = nutrition,
       _activity = activity,
       _workouts = workouts,
       _sleep = sleep;

  final ProfileRepository _profile;
  final NutritionRepository _nutrition;
  final ActivityRepository _activity;
  final WorkoutRepository _workouts;
  final SleepRepository _sleep;
  final TransformationRepository? _transformation;

  /// Days of history in a snapshot.
  static const int windowDays = 28;

  /// Returns null if the user hasn't completed onboarding.
  ///
  /// [days] widens the window (Progress screen uses up to a year).
  HealthSnapshot? call([DateTime? at, int days = windowDays]) {
    final profile = _profile.getProfile();
    if (profile == null) return null;
    final now = at ?? DateTime.now();
    final dates = DateKeys.lastNDays(now, days);
    final from = dates.first;
    final to = DateKeys.startOfDay(now).add(const Duration(days: 1));

    // Active transformation (Transformation mode only).
    final repo = _transformation;
    final plan = repo != null && repo.mode == AppMode.transformation ? repo.activePlan() : null;
    final planActive = plan != null && !plan.isFinished(now);
    final planDates = planActive && plan.dayNumber(now) >= 1
        ? [
            for (
              var d = DateKeys.startOfDay(plan.start);
              !d.isAfter(DateKeys.startOfDay(now));
              d = DateTime(d.year, d.month, d.day + 1)
            )
              d,
          ]
        : const <DateTime>[];

    // 90 days of workouts so personal records can be compared.
    var workoutsFrom = now.subtract(Duration(days: days > 90 ? days + 56 : 90));
    if (planDates.isNotEmpty && planDates.first.isBefore(workoutsFrom)) workoutsFrom = planDates.first;
    final workouts = _workouts.sessionsBetween(workoutsFrom, to);
    final byDay = <String, List<WorkoutSession>>{};
    for (final w in workouts) {
      (byDay[DateKeys.of(w.start)] ??= []).add(w);
    }

    List<DaySnapshot> build(List<DateTime> ds) {
      final ks = ds.map(DateKeys.of).toList();
      final food = _nutrition.entriesForDays(ks);
      final activity = _activity.forDays(ks);
      return [
        for (var i = 0; i < ds.length; i++)
          DaySnapshot(
            dayKey: ks[i],
            date: ds[i],
            intake: (food[ks[i]] ?? const []).fold(NutritionFacts.zero, (a, e) => a + e.facts),
            foodEntries: (food[ks[i]] ?? const []).where((e) => !e.isPending).length,
            waterMl: _nutrition.waterFor(ks[i]),
            activity: activity[ks[i]],
            workouts: byDay[ks[i]] ?? const [],
          ),
      ];
    }

    final snapshots = build(dates);
    final transformation = planActive
        ? TransformationInput(
            plan: plan,
            days: planDates.isEmpty ? const [] : build(planDates),
            checks: repo!.checksForDays(planDates.map(DateKeys.of)),
          )
        : null;
    final weightDays = max(days > 120 ? days : 120, planDates.length + 1);

    return HealthSnapshot(
      now: now,
      profile: profile,
      days: snapshots,
      workouts: workouts,
      sleep: _sleep.sessionsEndingBetween(from.subtract(const Duration(days: 7)), to),
      weights: _profile.getWeights().where((w) => now.difference(w.date).inDays <= weightDays).toList(),
      transformation: transformation,
    );
  }
}
