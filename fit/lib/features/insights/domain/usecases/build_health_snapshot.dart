import '../../../../core/utils/date_utils.dart';
import '../../../activity/domain/repositories/activity_repository.dart';
import '../../../nutrition/domain/entities/nutrition_facts.dart';
import '../../../nutrition/domain/repositories/nutrition_repository.dart';
import '../../../profile/domain/repositories/profile_repository.dart';
import '../../../sleep/domain/repositories/sleep_repository.dart';
import '../../../workout/domain/entities/workout_session.dart';
import '../../../workout/domain/repositories/workout_repository.dart';
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
  }) : _profile = profile,
       _nutrition = nutrition,
       _activity = activity,
       _workouts = workouts,
       _sleep = sleep;

  final ProfileRepository _profile;
  final NutritionRepository _nutrition;
  final ActivityRepository _activity;
  final WorkoutRepository _workouts;
  final SleepRepository _sleep;

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
    final keys = dates.map(DateKeys.of).toList();
    final from = dates.first;
    final to = DateKeys.startOfDay(now).add(const Duration(days: 1));

    final food = _nutrition.entriesForDays(keys);
    final activity = _activity.forDays(keys);
    // 90 days of workouts so personal records can be compared.
    final workouts = _workouts.sessionsBetween(now.subtract(Duration(days: days > 90 ? days + 56 : 90)), to);

    final byDay = <String, List<WorkoutSession>>{};
    for (final w in workouts) {
      (byDay[DateKeys.of(w.start)] ??= []).add(w);
    }
    final snapshots = [
      for (var i = 0; i < dates.length; i++)
        DaySnapshot(
          dayKey: keys[i],
          date: dates[i],
          intake: (food[keys[i]] ?? const []).fold(NutritionFacts.zero, (a, e) => a + e.facts),
          foodEntries: (food[keys[i]] ?? const []).where((e) => !e.isPending).length,
          waterMl: _nutrition.waterFor(keys[i]),
          activity: activity[keys[i]],
          workouts: byDay[keys[i]] ?? const [],
        ),
    ];

    return HealthSnapshot(
      now: now,
      profile: profile,
      days: snapshots,
      workouts: workouts,
      sleep: _sleep.sessionsEndingBetween(from.subtract(const Duration(days: 7)), to),
      weights: _profile
          .getWeights()
          .where((w) => now.difference(w.date).inDays <= (days > 120 ? days : 120))
          .toList(),
    );
  }
}
