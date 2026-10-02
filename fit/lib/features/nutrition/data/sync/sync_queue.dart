import '../../../../core/storage/hive_store.dart';

/// A meal description waiting to be analysed online.
class PendingJob {
  const PendingJob({
    required this.id,
    required this.text,
    required this.entryId,
    required this.createdAt,
    this.attempts = 0,
    this.lastError,
  });

  final String id;
  final String text;

  /// The placeholder FoodLogEntry to fill in once analysed.
  final String entryId;
  final DateTime createdAt;
  final int attempts;
  final String? lastError;

  /// Copy of this job with one more failed attempt recorded.
  PendingJob failed(String error) => PendingJob(
    id: id,
    text: text,
    entryId: entryId,
    createdAt: createdAt,
    attempts: attempts + 1,
    lastError: error,
  );

  static Map<String, dynamic> toMap(PendingJob j) => {
    'id': j.id,
    'text': j.text,
    'entryId': j.entryId,
    'createdAt': j.createdAt.millisecondsSinceEpoch,
    'attempts': j.attempts,
    'lastError': j.lastError,
  };

  static PendingJob fromMap(Map<String, dynamic> m) => PendingJob(
    id: m['id'] as String,
    text: m['text'] as String,
    entryId: m['entryId'] as String,
    createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int),
    attempts: (m['attempts'] as int?) ?? 0,
    lastError: m['lastError'] as String?,
  );
}

/// Durable FIFO of [PendingJob]s (Hive) — survives app restarts.
class SyncQueue {
  SyncQueue(this._store);
  final HiveStore<PendingJob> _store;

  /// Jobs oldest first.
  List<PendingJob> all() => _store.getAll()..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  /// Adds a job.
  Future<void> enqueue(PendingJob job) => _store.put(job.id, job);

  /// Replaces a job (e.g. after a failed attempt).
  Future<void> update(PendingJob job) => _store.put(job.id, job);

  /// Removes a job.
  Future<void> remove(String id) => _store.delete(id);

  /// Number of waiting jobs.
  int get length => _store.length;

  /// Emits when jobs change.
  Stream<void> watch() => _store.watch();
}
