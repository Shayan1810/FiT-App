import '../../../../core/storage/hive_store.dart';
import '../../domain/entities/nutrition_analysis.dart';
import '../parsing/food_matcher.dart';

/// A cached analysis with its timestamp.
class CachedAnalysis {
  const CachedAnalysis(this.analysis, this.savedAt);
  final NutritionAnalysis analysis;
  final DateTime savedAt;

  static Map<String, dynamic> toMap(CachedAnalysis c) => {
    'analysis': c.analysis.toMap(),
    'savedAt': c.savedAt.millisecondsSinceEpoch,
  };

  static CachedAnalysis fromMap(Map<String, dynamic> m) => CachedAnalysis(
    NutritionAnalysis.fromMap(Map<String, dynamic>.from(m['analysis'] as Map)),
    DateTime.fromMillisecondsSinceEpoch(m['savedAt'] as int),
  );
}

/// Stage 1 of the pipeline: a persistent (Hive) cache of past analyses.
///
/// * Key = normalised query (case, punctuation and plural-insensitive), so
///   "2 Rotis!" and "2 roti" share one entry.
/// * TTL 90 days; capacity 500 entries with oldest-first eviction.
/// * Survives app restarts — repeat meals never hit the network again.
class NutritionCache {
  NutritionCache(
    this._store, {
    this.ttl = const Duration(days: 90),
    this.maxEntries = 500,
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  final HiveStore<CachedAnalysis> _store;
  final Duration ttl;
  final int maxEntries;
  final DateTime Function() _now;

  /// Cache key for [text].
  static String keyFor(String text) => FoodMatcher.normalize(text);

  /// Returns a fresh cached analysis, or null (expired entries are removed).
  NutritionAnalysis? get(String text) {
    final key = keyFor(text);
    final hit = _store.get(key);
    if (hit == null) return null;
    if (_now().difference(hit.savedAt) > ttl) {
      _store.delete(key);
      return null;
    }
    return hit.analysis;
  }

  /// Stores [analysis] for [text], evicting the oldest entries if full.
  Future<void> put(String text, NutritionAnalysis analysis) async {
    await _store.put(keyFor(text), CachedAnalysis(analysis, _now()));
    if (_store.length > maxEntries) {
      final all = _store.getAll()..sort((a, b) => a.savedAt.compareTo(b.savedAt));
      for (final old in all.take(_store.length - maxEntries)) {
        await _store.delete(keyFor(old.analysis.query));
      }
    }
  }

  /// Number of cached entries.
  int get size => _store.length;

  /// Removes everything.
  Future<void> clear() => _store.clear();
}
