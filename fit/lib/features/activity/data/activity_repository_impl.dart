import '../../../core/domain/data_source.dart';
import '../../../core/storage/hive_store.dart';
import '../domain/entities/daily_activity.dart';
import '../domain/repositories/activity_repository.dart';

/// [DailyActivity] ↔ map.
class DailyActivityMapper {
  DailyActivityMapper._();

  static Map<String, dynamic> toMap(DailyActivity a) => {
    'dayKey': a.dayKey,
    'steps': a.steps,
    'distanceKm': a.distanceKm,
    'activeKcal': a.activeKcal,
    'restingHr': a.restingHr,
    'source': a.source.name,
    'syncedAt': a.syncedAt?.millisecondsSinceEpoch,
  };

  static DailyActivity fromMap(Map<String, dynamic> m) => DailyActivity(
    dayKey: m['dayKey'] as String,
    steps: (m['steps'] as num?)?.toInt() ?? 0,
    distanceKm: (m['distanceKm'] as num?)?.toDouble(),
    activeKcal: (m['activeKcal'] as num?)?.toDouble(),
    restingHr: (m['restingHr'] as num?)?.toDouble(),
    source: DataSource.values.firstWhere((s) => s.name == m['source'], orElse: () => DataSource.manual),
    syncedAt: m['syncedAt'] == null ? null : DateTime.fromMillisecondsSinceEpoch(m['syncedAt'] as int),
  );
}

/// Hive-backed [ActivityRepository]; one record per day keyed by `yyyy-MM-dd`.
class ActivityRepositoryImpl implements ActivityRepository {
  ActivityRepositoryImpl(this._store);
  final HiveStore<DailyActivity> _store;

  @override
  DailyActivity? forDay(String dayKey) => _store.get(dayKey);

  @override
  Map<String, DailyActivity> forDays(Iterable<String> dayKeys) {
    final out = <String, DailyActivity>{};
    for (final k in dayKeys) {
      final a = _store.get(k);
      if (a != null) out[k] = a;
    }
    return out;
  }

  @override
  Future<void> save(DailyActivity activity) => _store.put(activity.dayKey, activity);

  @override
  Future<void> delete(String dayKey) => _store.delete(dayKey);

  @override
  Stream<void> watch() => _store.watch();
}
