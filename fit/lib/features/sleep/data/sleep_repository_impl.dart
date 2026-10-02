import '../../../core/domain/data_source.dart';
import '../../../core/storage/hive_store.dart';
import '../domain/entities/sleep_session.dart';
import '../domain/repositories/sleep_repository.dart';

/// [SleepSession] ↔ map.
class SleepSessionMapper {
  SleepSessionMapper._();

  static Map<String, dynamic> toMap(SleepSession s) => {
    'id': s.id,
    'start': s.start.millisecondsSinceEpoch,
    'end': s.end.millisecondsSinceEpoch,
    'quality': s.quality,
    'source': s.source.name,
  };

  static SleepSession fromMap(Map<String, dynamic> m) => SleepSession(
    id: m['id'] as String,
    start: DateTime.fromMillisecondsSinceEpoch(m['start'] as int),
    end: DateTime.fromMillisecondsSinceEpoch(m['end'] as int),
    quality: m['quality'] as int?,
    source: DataSource.values.firstWhere((s) => s.name == m['source'], orElse: () => DataSource.manual),
  );
}

/// Hive-backed [SleepRepository].
class SleepRepositoryImpl implements SleepRepository {
  SleepRepositoryImpl(this._store);
  final HiveStore<SleepSession> _store;

  @override
  List<SleepSession> sessions() => _store.getAll()..sort((a, b) => b.end.compareTo(a.end));

  @override
  List<SleepSession> sessionsEndingBetween(DateTime from, DateTime to) =>
      _store.where((s) => !s.end.isBefore(from) && s.end.isBefore(to))
        ..sort((a, b) => b.end.compareTo(a.end));

  @override
  Future<void> save(SleepSession session) => _store.put(session.id, session);

  @override
  Future<void> delete(String id) => _store.delete(id);

  @override
  Stream<void> watch() => _store.watch();
}
