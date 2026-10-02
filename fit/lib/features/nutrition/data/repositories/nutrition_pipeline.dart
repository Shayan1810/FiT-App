import '../../../../core/network/connectivity_service.dart';
import '../../../../core/storage/settings_store.dart';
import '../../domain/entities/food_item.dart';
import '../../domain/entities/nutrition_analysis.dart';
import '../../domain/repositories/nutrition_repository.dart';
import '../datasources/gemini_nutrition_client.dart';
import '../datasources/nutrition_cache.dart';
import '../parsing/local_food_parser.dart';

/// Counter names written to [SettingsStore] for the Diagnostics screen.
class PipelineStats {
  PipelineStats._();
  static const String queries = 'nutrition_queries';
  static const String success = 'nutrition_success';
  static const String failure = 'nutrition_failure';
  static const String deferred = 'nutrition_deferred';
  static const String cacheHits = 'nutrition_cache_hits';
  static const String localHits = 'nutrition_local_hits';
  static const String geminiCalls = 'nutrition_gemini_calls';
  static const String geminiSuccess = 'nutrition_gemini_success';
  static const String geminiAttempts = 'nutrition_gemini_attempts';
}

/// The intelligent nutrition analysis pipeline.
///
/// ```text
///  text ─► [1] Cache (Hive) ──hit──────────────────────────► result
///            │ miss
///            ▼
///          [2] Local parser (offline DB + your foods) ─complete─► result (+cache)
///            │ unmatched fragments
///            ▼
///          [3] Gemini (only if online & key set; JSON schema,
///              5 attempts with exponential backoff) ──ok──► result (+cache)
///            │ failed / offline / no key
///            ▼
///          [4] Fallback: partial local result, or "pending" (queued and
///              resolved automatically when the device is back online)
/// ```
///
/// [analyze] never throws, so the UI never shows a raw error.
class NutritionPipeline implements NutritionAnalysisRepository {
  NutritionPipeline({
    required NutritionCache cache,
    required GeminiNutritionClient gemini,
    required ConnectivityService connectivity,
    required SettingsStore settings,
    required List<FoodItem> Function() foods,
  }) : _cache = cache,
       _gemini = gemini,
       _connectivity = connectivity,
       _settings = settings,
       _foods = foods;

  final NutritionCache _cache;
  final GeminiNutritionClient _gemini;
  final ConnectivityService _connectivity;
  final SettingsStore _settings;
  final List<FoodItem> Function() _foods;

  @override
  bool get remoteAvailable => _gemini.isConfigured;

  @override
  Future<NutritionAnalysis> analyze(String text) async {
    final query = text.trim();
    await _settings.increment(PipelineStats.queries);

    // [1] Cache
    final cached = _cache.get(query);
    if (cached != null) {
      await _settings.increment(PipelineStats.cacheHits);
      await _settings.increment(PipelineStats.success);
      return cached.withSource(AnalysisSource.cache);
    }

    // [2] Local parser
    final local = LocalFoodParser.analyze(query, _foods());
    if (local.isComplete) {
      await _cache.put(query, local);
      await _settings.increment(PipelineStats.localHits);
      await _settings.increment(PipelineStats.success);
      return local;
    }

    // [3] Gemini
    if (_gemini.isConfigured && await _connectivity.isOnline()) {
      try {
        final remote = await _callGemini(query);
        await _settings.increment(PipelineStats.success);
        return remote;
      } catch (_) {
        // fall through to [4]
      }
    }

    // [4] Fallbacks
    if (local.items.isNotEmpty) {
      await _settings.increment(PipelineStats.success);
      return local.withSource(AnalysisSource.partial);
    }
    if (_gemini.isConfigured) {
      await _settings.increment(PipelineStats.deferred);
      return NutritionAnalysis(
        query: query,
        items: const [],
        source: AnalysisSource.pending,
        unmatched: local.unmatched,
      );
    }
    await _settings.increment(PipelineStats.failure);
    return local;
  }

  @override
  Future<NutritionAnalysis> analyzeRemote(String text) => _callGemini(text.trim());

  Future<NutritionAnalysis> _callGemini(String query) async {
    await _settings.increment(PipelineStats.geminiCalls);
    try {
      final result = await _gemini.analyze(query);
      await _settings.increment(PipelineStats.geminiSuccess);
      await _cache.put(query, result);
      return result;
    } finally {
      await _settings.increment(PipelineStats.geminiAttempts, _gemini.lastAttempts);
    }
  }

  /// End-to-end success rate (successes ÷ resolved queries), 0–1.
  static double successRate(SettingsStore s) {
    final ok = s.counterValue(PipelineStats.success);
    final bad = s.counterValue(PipelineStats.failure);
    return ok + bad == 0 ? 1 : ok / (ok + bad);
  }
}
