import 'package:health/health.dart';

import '../../../core/platform/health_brand.dart';
import '../../../core/storage/settings_store.dart';
import '../../../core/utils/date_utils.dart';
import '../../activity/domain/entities/daily_activity.dart';
import '../../activity/domain/repositories/activity_repository.dart';
import '../../profile/domain/entities/weight_entry.dart';
import '../../profile/domain/repositories/profile_repository.dart';
import '../../sleep/domain/entities/sleep_session.dart';
import '../../sleep/domain/repositories/sleep_repository.dart';
import '../../workout/domain/entities/workout_session.dart';
import '../../workout/domain/repositories/workout_repository.dart';
import '../domain/health_sync_repository.dart';
import 'health_connect_source.dart';

/// Pulls Health Connect data into FiT's offline stores.
///
/// Records imported from Health Connect get deterministic ids
/// (`hc_<uuid>`), so re-syncing the same period updates instead of
/// duplicating. Manual entries are never overwritten except a day's
/// activity, where device data replaces a manual step count.
class HealthSyncRepositoryImpl implements HealthSyncRepository {
  HealthSyncRepositoryImpl({
    required HealthConnectSource source,
    required ActivityRepository activity,
    required SleepRepository sleep,
    required WorkoutRepository workouts,
    required ProfileRepository profile,
    required SettingsStore settings,
  }) : _src = source,
       _activity = activity,
       _sleep = sleep,
       _workouts = workouts,
       _profile = profile,
       _settings = settings;

  final HealthConnectSource _src;
  final ActivityRepository _activity;
  final SleepRepository _sleep;
  final WorkoutRepository _workouts;
  final ProfileRepository _profile;
  final SettingsStore _settings;

  @override
  Future<HealthLinkStatus> status() => _src.status();

  @override
  Future<void> install() => _src.install();

  @override
  Future<bool> connect() async {
    try {
      final ok = await _src.requestPermissions();
      await _settings.write(SettingsStore.kHealthConnected, ok);
      return ok;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<SyncReport> sync({int days = 7}) async {
    try {
      if (await _src.status() != HealthLinkStatus.connected) {
        return SyncReport(error: '${HealthBrand.hub} not connected');
      }
      final now = DateTime.now();
      final from = DateKeys.startOfDay(now).subtract(Duration(days: days - 1));

      final dayCount = await _syncDays(from, now);
      // Sleep that ended in the window may have started the evening before.
      final sleeps = await _syncSleep(from.subtract(const Duration(hours: 18)), now);
      final workouts = await _syncWorkouts(from, now);
      final weights = await _syncWeights(from, now);

      await _settings.write(SettingsStore.kLastHealthSync, now.millisecondsSinceEpoch);
      return SyncReport(days: dayCount, sleepSessions: sleeps, workouts: workouts, weights: weights);
    } catch (e) {
      return SyncReport(error: e.toString());
    }
  }

  /// Steps, distance, active energy and resting HR per day.
  Future<int> _syncDays(DateTime from, DateTime now) async {
    final pts = await _src.points(
      [_src.distanceType, HealthDataType.ACTIVE_ENERGY_BURNED, HealthDataType.RESTING_HEART_RATE],
      from,
      now,
    );
    var count = 0;
    for (var d = from; !d.isAfter(now); d = d.add(const Duration(days: 1))) {
      final key = DateKeys.of(d);
      final end = DateKeys.endOfDay(d).isAfter(now) ? now : DateKeys.endOfDay(d);
      final steps = await _src.steps(d, end);
      final dayPts = pts.where((p) => DateKeys.of(p.dateFrom) == key);
      double sum(HealthDataType t) => dayPts.where((p) => p.type == t).fold(0.0, (a, p) => a + _num(p));
      final meters = sum(_src.distanceType);
      final active = sum(HealthDataType.ACTIVE_ENERGY_BURNED);
      final rhr = dayPts.where((p) => p.type == HealthDataType.RESTING_HEART_RATE).map(_num).toList();
      if (steps == 0 && meters == 0 && active == 0 && rhr.isEmpty) continue;
      // A day the user edited by hand is never overwritten by a sync.
      if (_activity.forDay(key)?.source == DataSource.manual) continue;

      await _activity.save(
        DailyActivity(
          dayKey: key,
          steps: steps,
          distanceKm: meters > 0 ? meters / 1000 : null,
          activeKcal: active > 0 ? active : null,
          restingHr: rhr.isEmpty ? null : rhr.reduce((a, b) => a + b) / rhr.length,
          source: DataSource.healthConnect,
          syncedAt: DateTime.now(),
        ),
      );
      count++;
    }
    return count;
  }

  Future<int> _syncSleep(DateTime from, DateTime now) async {
    final nights = await _src.sleep(from, now);
    final edited = {
      for (final s in _sleep.sessions())
        if (s.source == DataSource.manual) s.id,
    };
    for (final n in nights) {
      if (n.end.difference(n.start).inMinutes < 20) continue;
      if (edited.contains(n.id)) continue; // user corrected this night
      await _sleep.save(SleepSession(id: n.id, start: n.start, end: n.end, source: DataSource.healthConnect));
    }
    return nights.length;
  }

  Future<int> _syncWorkouts(DateTime from, DateTime now) async {
    final pts = await _src.points(const [HealthDataType.WORKOUT], from, now);
    for (final p in pts) {
      final v = p.value;
      if (v is! WorkoutHealthValue) continue;
      final type = mapWorkoutType(v.workoutActivityType.name);
      final minutes = p.dateTo.difference(p.dateFrom).inMinutes;
      if (minutes < 5) continue;
      await _workouts.save(
        WorkoutSession(
          id: 'hc_${p.uuid}',
          start: p.dateFrom,
          title: _titleCase(v.workoutActivityType.name),
          type: type,
          durationMin: minutes,
          rpe: defaultRpe(type),
          deviceKcal: v.totalEnergyBurned?.toDouble(),
          distanceKm: v.totalDistance == null ? null : v.totalDistance! / 1000,
          source: DataSource.healthConnect,
        ),
      );
    }
    return pts.length;
  }

  Future<int> _syncWeights(DateTime from, DateTime now) async {
    final pts = await _src.points(const [HealthDataType.WEIGHT], from, now);
    final manual = {
      for (final w in _profile.getWeights())
        if (w.source == DataSource.manual) w.dayKey,
    };
    for (final p in pts) {
      final key = DateKeys.of(p.dateFrom);
      if (manual.contains(key)) continue; // never overwrite a manual weigh-in
      await _profile.logWeight(
        WeightEntry(dayKey: key, date: p.dateFrom, kg: _num(p), source: DataSource.healthConnect),
      );
    }
    return pts.length;
  }

  static double _num(HealthDataPoint p) {
    final v = p.value;
    return v is NumericHealthValue ? v.numericValue.toDouble() : 0;
  }

  /// Maps a Health Connect exercise type name to a FiT [WorkoutType].
  static WorkoutType mapWorkoutType(String name) {
    final n = name.toUpperCase();
    if (n.contains('WALK') || n.contains('HIKING')) return WorkoutType.walk;
    if (n.contains('RUN')) return WorkoutType.run;
    if (n.contains('STRENGTH') || n.contains('WEIGHT') || n.contains('CALISTHENICS') || n.contains('CORE')) {
      return WorkoutType.strength;
    }
    if (n.contains('HIGH_INTENSITY') || n.contains('CROSS_TRAINING') || n.contains('JUMP_ROPE')) {
      return WorkoutType.hiit;
    }
    if (n.contains('YOGA') ||
        n.contains('PILATES') ||
        n.contains('FLEXIBILITY') ||
        n.contains('STRETCH') ||
        n.contains('TAI_CHI') ||
        n.contains('BREATH') ||
        n.contains('COOLDOWN')) {
      return WorkoutType.mobility;
    }
    if (n.contains('BIK') ||
        n.contains('ELLIPTICAL') ||
        n.contains('ROWING') ||
        n.contains('SWIM') ||
        n.contains('STAIR') ||
        n.contains('CARDIO') ||
        n.contains('DANC')) {
      return WorkoutType.cardio;
    }
    return WorkoutType.sport;
  }

  /// Typical session RPE assumed for imported workouts (no rating given).
  static int defaultRpe(WorkoutType t) => switch (t) {
    WorkoutType.walk => 3,
    WorkoutType.mobility => 3,
    WorkoutType.run => 6,
    WorkoutType.cardio => 6,
    WorkoutType.strength => 7,
    WorkoutType.hiit => 8,
    WorkoutType.sport => 6,
  };

  static String _titleCase(String s) => s
      .toLowerCase()
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}
