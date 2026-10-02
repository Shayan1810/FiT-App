import 'dart:math';

import '../../domain/entities/food_item.dart';

/// A scored search hit.
class FoodMatch {
  const FoodMatch(this.food, this.score);
  final FoodItem food;

  /// 0–1 similarity.
  final double score;
}

/// Fuzzy food-name matching (no network, no AI).
///
/// Score = best of, over the food name and each alias:
/// * 1.0 for an exact normalised match;
/// * token overlap (Sørensen–Dice on word sets), boosted for prefix hits;
/// * Levenshtein similarity for single-word typos ("chapti" → "chapati").
class FoodMatcher {
  FoodMatcher._();

  /// Lower-cases, strips punctuation, singularises simple plurals.
  static String normalize(String s) {
    final cleaned = s
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.split(' ').map(_singular).join(' ');
  }

  static String _singular(String w) {
    if (w.length > 4 && w.endsWith('ies')) return '${w.substring(0, w.length - 3)}y';
    if (w.length > 3 && w.endsWith('es') && !w.endsWith('ses')) {
      final stem = w.substring(0, w.length - 2);
      if (stem.endsWith('to') || stem.endsWith('ch') || stem.endsWith('sh')) return stem;
    }
    if (w.length > 3 && w.endsWith('s') && !w.endsWith('ss')) return w.substring(0, w.length - 1);
    return w;
  }

  /// Levenshtein edit distance.
  static int levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    var prev = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        cur[j] = min(min(cur[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost);
      }
      prev = cur;
    }
    return prev[b.length];
  }

  /// Similarity 0–1 between a query and one candidate name.
  static double similarity(String query, String candidate) {
    final q = normalize(query);
    final c = normalize(candidate);
    if (q.isEmpty || c.isEmpty) return 0;
    if (q == c) return 1;

    final qt = q.split(' ').toSet();
    final ct = c.split(' ').toSet();
    final common = qt.intersection(ct).length;
    var score = 2 * common / (qt.length + ct.length);

    // Prefix / containment boosts ("chicken" vs "chicken breast cooked").
    if (c.startsWith(q) || q.startsWith(c)) score = max(score, 0.82);
    if (ct.containsAll(qt)) score = max(score, 0.78);

    // Typo tolerance on short phrases.
    final longest = max(q.length, c.length);
    final lev = 1 - levenshtein(q, c) / longest;
    if (longest <= 14) score = max(score, lev * 0.95);
    return score.clamp(0.0, 1.0);
  }

  /// Best score of [query] against a food's name and aliases.
  static double scoreFood(String query, FoodItem food) {
    var best = similarity(query, food.name);
    // Ignore parenthetical descriptors: "Roti (whole wheat)" → "Roti".
    final base = food.name.replaceAll(RegExp(r'\(.*?\)'), '').trim();
    if (base != food.name) best = max(best, similarity(query, base));
    for (final a in food.aliases) {
      best = max(best, similarity(query, a));
      if (best == 1) break;
    }
    return best;
  }

  /// Ranks [foods] for [query]; only scores ≥ [minScore] are returned.
  static List<FoodMatch> rank(
    String query,
    Iterable<FoodItem> foods, {
    double minScore = 0.35,
    int limit = 30,
  }) {
    final hits = <FoodMatch>[];
    for (final f in foods) {
      final s = scoreFood(query, f);
      if (s >= minScore) hits.add(FoodMatch(f, s));
    }
    hits.sort((a, b) {
      final c = b.score.compareTo(a.score);
      if (c != 0) return c;
      // Prefer the user's own foods on ties.
      return a.food.origin.index.compareTo(b.food.origin.index) * -1;
    });
    return hits.take(limit).toList();
  }
}
