import 'dart:collection';

/// One timed storage operation.
class PerfSample {
  final String op;
  final double millis;
  const PerfSample(this.op, this.millis);
}

/// Aggregated statistics for a single operation name.
class PerfStats {
  final String op;
  final int count;
  final double avgMs;
  final double p95Ms;
  final double maxMs;
  const PerfStats(this.op, this.count, this.avgMs, this.p95Ms, this.maxMs);
}

/// Measures how long storage (CRUD) operations take.
///
/// Every `HiveStore` call is wrapped with [measure] / [measureSync]. The last
/// 500 samples are kept in a ring buffer and summarised on the Settings →
/// Diagnostics screen, which is how the "sub-15 ms CRUD" target is verified
/// on a real device. Also used by `test/core/hive_store_perf_test.dart`.
class PerfMonitor {
  PerfMonitor._();

  /// Shared instance (simple singleton; it holds only in-memory samples).
  static final PerfMonitor instance = PerfMonitor._();

  static const int _capacity = 500;
  final ListQueue<PerfSample> _samples = ListQueue<PerfSample>();

  /// Times a synchronous [body] and records it under [op].
  T measureSync<T>(String op, T Function() body) {
    final sw = Stopwatch()..start();
    try {
      return body();
    } finally {
      _record(op, sw);
    }
  }

  /// Times an asynchronous [body] and records it under [op].
  Future<T> measure<T>(String op, Future<T> Function() body) async {
    final sw = Stopwatch()..start();
    try {
      return await body();
    } finally {
      _record(op, sw);
    }
  }

  void _record(String op, Stopwatch sw) {
    sw.stop();
    if (_samples.length >= _capacity) _samples.removeFirst();
    _samples.add(PerfSample(op, sw.elapsedMicroseconds / 1000.0));
  }

  /// Per-operation statistics, sorted by operation name.
  List<PerfStats> stats() {
    final byOp = <String, List<double>>{};
    for (final s in _samples) {
      (byOp[s.op] ??= []).add(s.millis);
    }
    final out = <PerfStats>[];
    byOp.forEach((op, list) {
      list.sort();
      final avg = list.reduce((a, b) => a + b) / list.length;
      final p95 = list[((list.length - 1) * 0.95).round()];
      out.add(PerfStats(op, list.length, avg, p95, list.last));
    });
    out.sort((a, b) => a.op.compareTo(b.op));
    return out;
  }

  /// Average latency across all recorded operations (0 if none).
  double overallAverageMs() {
    if (_samples.isEmpty) return 0;
    return _samples.map((s) => s.millis).reduce((a, b) => a + b) / _samples.length;
  }

  /// Clears all samples (used by tests).
  void reset() => _samples.clear();
}
