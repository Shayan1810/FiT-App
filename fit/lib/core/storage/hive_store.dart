import 'dart:async';

import 'package:hive_ce/hive.dart';

import '../utils/perf_monitor.dart';

/// Converts an entity to/from the plain map stored in Hive.
typedef ToMap<T> = Map<String, dynamic> Function(T value);

/// Converts a Hive map back into an entity.
typedef FromMap<T> = T Function(Map<String, dynamic> map);

/// Recursively converts Hive's `Map<dynamic, dynamic>` / `List<dynamic>`
/// values into JSON-like `Map<String, dynamic>` / `List<dynamic>`.
dynamic deepCast(dynamic value) {
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), deepCast(v)));
  }
  if (value is List) return value.map(deepCast).toList();
  return value;
}

/// A typed, instrumented wrapper around one Hive box.
///
/// Why maps instead of generated TypeAdapters? Plain maps make schema
/// evolution trivial (a missing key just falls back to a default in
/// `fromMap`) and need no `build_runner` step — a contributor can add a
/// field by editing one mapper. Hive keeps every box fully in memory, so
/// reads are synchronous O(1) look-ups; writes append to an on-disk log.
///
/// Every operation is timed by [PerfMonitor] so the Diagnostics screen can
/// prove the sub-15 ms CRUD target on the device.
class HiveStore<T> {
  HiveStore(this._box, {required this.toMap, required this.fromMap});

  final Box<dynamic> _box;
  final ToMap<T> toMap;
  final FromMap<T> fromMap;

  final PerfMonitor _perf = PerfMonitor.instance;

  /// Name of the underlying box (used in perf labels).
  String get name => _box.name;

  /// Number of records.
  int get length => _box.length;

  /// Reads one record by [id]; null if absent. Synchronous (in-memory).
  T? get(String id) => _perf.measureSync('$name.read', () {
    final raw = _box.get(id);
    if (raw == null) return null;
    return fromMap(deepCast(raw) as Map<String, dynamic>);
  });

  /// All records, in insertion/key order.
  List<T> getAll() => _perf.measureSync('$name.readAll', () {
    return _box.values.map((raw) => fromMap(deepCast(raw) as Map<String, dynamic>)).toList();
  });

  /// Records matching [test].
  List<T> where(bool Function(T) test) => getAll().where(test).toList();

  /// Records whose *key* matches [test]. Only matching values are decoded,
  /// so prefix-keyed data (e.g. `2025-06-03#…`) is read in O(matches).
  List<T> whereKey(bool Function(String key) test) => _perf.measureSync('$name.readKeys', () {
    final out = <T>[];
    for (final k in _box.keys) {
      final key = k.toString();
      if (test(key)) {
        out.add(fromMap(deepCast(_box.get(k)) as Map<String, dynamic>));
      }
    }
    return out;
  });

  /// Inserts or replaces the record stored under [id].
  Future<void> put(String id, T value) => _perf.measure('$name.write', () => _box.put(id, toMap(value)));

  /// Inserts or replaces many records in one disk flush.
  Future<void> putAll(Map<String, T> values) =>
      _perf.measure('$name.writeAll', () => _box.putAll(values.map((k, v) => MapEntry(k, toMap(v)))));

  /// Deletes the record stored under [id] (no-op if absent).
  Future<void> delete(String id) => _perf.measure('$name.delete', () => _box.delete(id));

  /// True if a record exists under [id].
  bool contains(String id) => _box.containsKey(id);

  /// Removes every record.
  Future<void> clear() => _box.clear();

  /// Emits whenever any record in the box changes.
  Stream<void> watch() => _box.watch().map((_) {});
}
