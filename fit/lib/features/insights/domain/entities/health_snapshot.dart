import '../../../activity/domain/entities/daily_activity.dart';
import '../../../nutrition/domain/entities/nutrition_facts.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../../profile/domain/entities/weight_entry.dart';
import '../../../sleep/domain/entities/sleep_session.dart';
import '../../../workout/domain/entities/workout_session.dart';

/// Everything known about one calendar day.
class DaySnapshot {
  const DaySnapshot({
    required this.dayKey,
    required this.date,
    required this.intake,
    required this.foodEntries,
    required this.waterMl,
    required this.workouts,
    this.activity,
  });

  final String dayKey;
  final DateTime date;

  /// Sum of all food logged that day.
  final NutritionFacts intake;

  /// Number of food entries (0 → day not logged).
  final int foodEntries;
  final int waterMl;
  final DailyActivity? activity;
  final List<WorkoutSession> workouts;
}

/// Immutable bundle of all data the insight engine needs.
///
/// Built on the UI isolate from repositories (cheap, in-memory reads), then
/// handed to a background isolate where `InsightEngine.generate` runs — so
/// heavy maths never blocks a frame.
class HealthSnapshot {
  const HealthSnapshot({
    required this.now,
    required this.profile,
    required this.days,
    required this.workouts,
    required this.sleep,
    required this.weights,
  });

  final DateTime now;
  final UserProfile profile;

  /// The last 28 days, oldest first; `days.last` is today.
  final List<DaySnapshot> days;

  /// Workouts in the last 28 days (plus older ones for PR detection).
  final List<WorkoutSession> workouts;

  /// Sleep sessions ending in the last 28 days.
  final List<SleepSession> sleep;

  /// Weigh-ins from the last 120 days.
  final List<WeightEntry> weights;

  /// The snapshot of the current (incomplete) day.
  DaySnapshot get today => days.last;
}
