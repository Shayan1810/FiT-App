import '../entities/daily_activity.dart';

/// Daily steps/distance/active-energy storage.
abstract class ActivityRepository {
  /// Activity for [dayKey], or null if nothing recorded.
  DailyActivity? forDay(String dayKey);

  /// Activity for several days (missing days are omitted).
  Map<String, DailyActivity> forDays(Iterable<String> dayKeys);

  /// Saves (replaces) a day.
  Future<void> save(DailyActivity activity);

  /// Removes a day's record (e.g. to fall back to Samsung Health data).
  Future<void> delete(String dayKey);

  /// Emits whenever activity data changes.
  Stream<void> watch();
}
