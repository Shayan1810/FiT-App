import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Answers "are we online?" and notifies when the device comes back online.
///
/// Used by the nutrition pipeline (skip Gemini when offline) and by the
/// `SyncCoordinator` (drain the offline queue on reconnect).
abstract class ConnectivityService {
  /// Current best guess of connectivity.
  Future<bool> isOnline();

  /// Emits `true` when going online and `false` when going offline.
  Stream<bool> get onStatusChange;
}

/// [ConnectivityService] backed by `connectivity_plus`.
class ConnectivityPlusService implements ConnectivityService {
  ConnectivityPlusService([Connectivity? connectivity]) : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  static bool _hasNetwork(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  @override
  Future<bool> isOnline() async {
    try {
      return _hasNetwork(await _connectivity.checkConnectivity());
    } catch (_) {
      return true; // Unknown → let the request try; retry logic handles it.
    }
  }

  @override
  Stream<bool> get onStatusChange => _connectivity.onConnectivityChanged.map(_hasNetwork).distinct();
}

/// Fixed-answer implementation for tests.
class FakeConnectivityService implements ConnectivityService {
  FakeConnectivityService({this.online = true});

  bool online;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  /// Changes the fake status and emits it.
  void set(bool value) {
    online = value;
    _controller.add(value);
  }

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<bool> get onStatusChange => _controller.stream;
}
