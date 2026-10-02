import 'dart:math';

/// Generates collision-resistant string IDs without a UUID dependency.
///
/// Format: `<base36 microseconds>-<6 random base36 chars>`. Sortable by
/// creation time, which keeps Hive iteration order roughly chronological.
class IdGenerator {
  IdGenerator._();

  static final Random _rng = Random.secure();

  /// Returns a new unique id, optionally prefixed (e.g. `food_…`).
  static String next([String prefix = '']) {
    final time = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final rand = List.generate(6, (_) => _rng.nextInt(36).toRadixString(36)).join();
    return '$prefix$time-$rand';
  }
}
