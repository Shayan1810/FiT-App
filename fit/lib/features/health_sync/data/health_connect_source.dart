import 'dart:io';

import 'package:health/health.dart';

import '../domain/health_sync_repository.dart';

/// A night of sleep read from the health hub.
class DeviceSleep {
  const DeviceSleep(this.id, this.start, this.end);
  final String id;
  final DateTime start;
  final DateTime end;
}

/// Thin wrapper over the `health` plugin: Health Connect on Android,
/// HealthKit (Apple Health) on iOS.
///
/// Kept separate from the repository so the plugin can be faked in tests
/// and so all platform calls and per-platform data types live in one file.
class HealthConnectSource {
  HealthConnectSource({Health? health, bool Function()? wasAuthorized})
    : _health = health ?? Health(),
      _wasAuthorized = wasAuthorized ?? (() => false);

  final Health _health;
  final bool Function() _wasAuthorized;
  bool _configured = false;

  bool get _ios => Platform.isIOS;

  /// Distance type: Health Connect records deltas; HealthKit walking+running.
  HealthDataType get distanceType =>
      _ios ? HealthDataType.DISTANCE_WALKING_RUNNING : HealthDataType.DISTANCE_DELTA;

  /// Sleep type: whole sessions on Android, "asleep" segments on iOS.
  HealthDataType get sleepType => _ios ? HealthDataType.SLEEP_ASLEEP : HealthDataType.SLEEP_SESSION;

  /// Data types FiT reads (read-only — FiT never writes health data).
  List<HealthDataType> get types => [
    HealthDataType.STEPS,
    distanceType,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.RESTING_HEART_RATE,
    sleepType,
    HealthDataType.WORKOUT,
    HealthDataType.WEIGHT,
  ];

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  /// Availability + permission status.
  Future<HealthLinkStatus> status() async {
    try {
      if (_ios) {
        // HealthKit never reveals whether *read* access was granted, so the
        // link counts as connected once the user went through the prompt.
        return _wasAuthorized() ? HealthLinkStatus.connected : HealthLinkStatus.notAuthorized;
      }
      if (!Platform.isAndroid) return HealthLinkStatus.unavailable;
      await _ensureConfigured();
      final sdk = await _health.getHealthConnectSdkStatus();
      if (sdk != HealthConnectSdkStatus.sdkAvailable) return HealthLinkStatus.needsInstall;
      final granted = await _health.hasPermissions(types) ?? false;
      return granted ? HealthLinkStatus.connected : HealthLinkStatus.notAuthorized;
    } catch (_) {
      return HealthLinkStatus.unavailable;
    }
  }

  /// Shows the system permission screen for read access.
  Future<bool> requestPermissions() async {
    await _ensureConfigured();
    final t = types;
    return _health.requestAuthorization(t, permissions: List.filled(t.length, HealthDataAccess.READ));
  }

  /// Opens the store page for Health Connect (Android only).
  Future<void> install() async {
    if (_ios) return;
    await _health.installHealthConnect();
  }

  /// Total de-duplicated steps between [start] and [end].
  Future<int> steps(DateTime start, DateTime end) async {
    await _ensureConfigured();
    return await _health.getTotalStepsInInterval(start, end) ?? 0;
  }

  /// Raw data points of [types] between [start] and [end].
  Future<List<HealthDataPoint>> points(List<HealthDataType> types, DateTime start, DateTime end) async {
    await _ensureConfigured();
    final pts = await _health.getHealthDataFromTypes(types: types, startTime: start, endTime: end);
    return _health.removeDuplicates(pts);
  }

  /// Nights of sleep between [start] and [end]. HealthKit stores sleep as
  /// many short "asleep" segments; they are merged into one session when the
  /// gap between them is under 60 minutes.
  Future<List<DeviceSleep>> sleep(DateTime start, DateTime end) async {
    final pts = await points([sleepType], start, end)
      ..sort((a, b) => a.dateFrom.compareTo(b.dateFrom));
    if (!_ios) return [for (final p in pts) DeviceSleep('hc_${p.uuid}', p.dateFrom, p.dateTo)];
    return mergeSegments([for (final p in pts) (p.uuid, p.dateFrom, p.dateTo)]);
  }

  /// Merges sorted sleep segments separated by < [gap] into sessions.
  static List<DeviceSleep> mergeSegments(
    List<(String, DateTime, DateTime)> segments, {
    Duration gap = const Duration(minutes: 60),
  }) {
    final out = <DeviceSleep>[];
    String? id;
    DateTime? s, e;
    for (final (uuid, from, to) in segments) {
      if (e != null && from.difference(e) <= gap) {
        if (to.isAfter(e)) e = to;
        continue;
      }
      if (id != null) out.add(DeviceSleep(id, s!, e!));
      id = 'hk_$uuid';
      s = from;
      e = to;
    }
    if (id != null) out.add(DeviceSleep(id, s!, e!));
    return out;
  }
}
