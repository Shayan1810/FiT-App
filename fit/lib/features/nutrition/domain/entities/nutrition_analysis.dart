import 'package:equatable/equatable.dart';

import 'nutrition_facts.dart';

/// Which stage of the pipeline produced an analysis.
enum AnalysisSource { cache, localDatabase, gemini, partial, pending }

/// One recognised food in a free-text meal description.
class AnalyzedItem extends Equatable {
  const AnalyzedItem({
    required this.name,
    required this.grams,
    required this.facts,
    this.confidence = 1,
    this.foodId,
  });

  final String name;
  final double grams;
  final NutritionFacts facts;

  /// 0–1: how sure the matcher / model is.
  final double confidence;
  final String? foodId;

  Map<String, dynamic> toMap() => {
    'name': name,
    'grams': grams,
    'facts': facts.toMap(),
    'confidence': confidence,
    'foodId': foodId,
  };

  factory AnalyzedItem.fromMap(Map<String, dynamic> m) => AnalyzedItem(
    name: m['name'] as String? ?? 'Food',
    grams: (m['grams'] as num?)?.toDouble() ?? 0,
    facts: NutritionFacts.fromMap(Map<String, dynamic>.from(m['facts'] as Map? ?? const {})),
    confidence: (m['confidence'] as num?)?.toDouble() ?? 1,
    foodId: m['foodId'] as String?,
  );

  @override
  List<Object?> get props => [name, grams, facts, confidence, foodId];
}

/// Result of analysing a meal description such as "2 roti and dal".
class NutritionAnalysis extends Equatable {
  const NutritionAnalysis({
    required this.query,
    required this.items,
    required this.source,
    this.unmatched = const [],
  });

  final String query;
  final List<AnalyzedItem> items;
  final AnalysisSource source;

  /// Fragments the local parser could not recognise.
  final List<String> unmatched;

  /// Sum over all items.
  NutritionFacts get total => items.fold(NutritionFacts.zero, (a, i) => a + i.facts);

  /// True when the result is complete (nothing pending or unmatched).
  bool get isComplete => source != AnalysisSource.pending && unmatched.isEmpty && items.isNotEmpty;

  /// Same analysis re-labelled with another pipeline stage.
  NutritionAnalysis withSource(AnalysisSource s) =>
      NutritionAnalysis(query: query, items: items, source: s, unmatched: unmatched);

  Map<String, dynamic> toMap() => {
    'query': query,
    'items': items.map((i) => i.toMap()).toList(),
    'source': source.name,
    'unmatched': unmatched,
  };

  factory NutritionAnalysis.fromMap(Map<String, dynamic> m) => NutritionAnalysis(
    query: m['query'] as String? ?? '',
    items: ((m['items'] as List?) ?? const [])
        .map((e) => AnalyzedItem.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList(),
    source: AnalysisSource.values.firstWhere(
      (s) => s.name == m['source'],
      orElse: () => AnalysisSource.cache,
    ),
    unmatched: ((m['unmatched'] as List?) ?? const []).cast<String>(),
  );

  @override
  List<Object?> get props => [query, items, source, unmatched];
}
