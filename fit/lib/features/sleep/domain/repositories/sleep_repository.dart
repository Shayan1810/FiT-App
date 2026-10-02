import '../entities/sleep_session.dart';

/// Sleep session storage.
abstract class SleepRepository {
  /// All sessions, newest first.
  List<SleepSession> sessions();

  /// Sessions that ended within [from, to).
  List<SleepSession> sessionsEndingBetween(DateTime from, DateTime to);

  /// Adds or replaces a session.
  Future<void> save(SleepSession session);

  /// Deletes a session.
  Future<void> delete(String id);

  /// Emits when sessions change.
  Stream<void> watch();
}
