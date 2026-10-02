/// State of the Health Connect link.
enum HealthLinkStatus {
  /// Not Android / Health Connect not supported on this device.
  unavailable,

  /// Health Connect must be installed or updated from the Play Store.
  needsInstall,

  /// Installed but FiT has not been granted permissions yet.
  notAuthorized,

  /// Permissions granted; sync works.
  connected,
}

/// What a sync run imported.
class SyncReport {
  const SyncReport({this.days = 0, this.sleepSessions = 0, this.workouts = 0, this.weights = 0, this.error});

  final int days;
  final int sleepSessions;
  final int workouts;
  final int weights;

  /// Non-null if the sync failed.
  final String? error;

  /// True when the sync finished without error.
  bool get ok => error == null;

  @override
  String toString() => ok
      ? 'Synced $days days, $sleepSessions sleeps, $workouts workouts, $weights weigh-ins'
      : 'Sync failed: $error';
}

/// Imports steps, distance, active energy, resting HR, sleep, workouts and
/// weight from Health Connect (where Samsung Health, Google Fit, Fitbit,
/// Garmin etc. write their data) into FiT's local repositories.
abstract class HealthSyncRepository {
  /// Current link status.
  Future<HealthLinkStatus> status();

  /// Asks the user for read permissions. Returns true when granted.
  Future<bool> connect();

  /// Opens the Play Store page for Health Connect.
  Future<void> install();

  /// Pulls the last [days] days into local storage (idempotent upserts).
  Future<SyncReport> sync({int days = 7});
}
