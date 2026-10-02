import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/network/retry_policy.dart';
import '../../domain/entities/nutrition_analysis.dart';
import '../../domain/entities/nutrition_facts.dart';

/// Talks to the Google Gemini REST API (`generateContent`) and returns a
/// validated [NutritionAnalysis].
///
/// * **Structured output** — `responseMimeType: application/json` plus a
///   `responseSchema` (OpenAPI subset) force the model to emit exactly the
///   fields we parse; no regex scraping of prose.
/// * **Validation** — [validate] rejects missing/negative/absurd values and
///   repairs calorie totals that disagree with the Atwater macro energy.
/// * **Resilience** — every call goes through [RetryPolicy] (exponential
///   backoff + jitter; retries 408/429/5xx, timeouts, socket errors and
///   schema violations).
///
/// This is the ONLY place in the app that calls an AI model, and it is only
/// reached when the offline database cannot understand the meal text.
class GeminiNutritionClient {
  GeminiNutritionClient({
    required http.Client httpClient,
    required String? Function() apiKey,
    required String Function() model,
    RetryPolicy retryPolicy = const RetryPolicy(),
  }) : _http = httpClient,
       _apiKey = apiKey,
       _model = model,
       _retry = retryPolicy;

  final http.Client _http;
  final String? Function() _apiKey;
  final String Function() _model;
  final RetryPolicy _retry;

  static const String _base = 'https://generativelanguage.googleapis.com/v1beta/models';

  /// Number of HTTP attempts made by the last [analyze] call (diagnostics).
  int lastAttempts = 0;

  /// True if an API key is configured.
  bool get isConfigured => (_apiKey() ?? '').isNotEmpty;

  /// The JSON schema Gemini must follow.
  static const Map<String, dynamic> responseSchema = {
    'type': 'OBJECT',
    'properties': {
      'items': {
        'type': 'ARRAY',
        'items': {
          'type': 'OBJECT',
          'properties': {
            'name': {'type': 'STRING', 'description': 'Food name in English'},
            'grams': {'type': 'NUMBER', 'description': 'Edible portion weight in grams (mL for drinks)'},
            'calories': {'type': 'NUMBER', 'description': 'kcal for this portion'},
            'protein_g': {'type': 'NUMBER'},
            'carbs_g': {'type': 'NUMBER'},
            'fat_g': {'type': 'NUMBER'},
            'fiber_g': {'type': 'NUMBER'},
            'confidence': {'type': 'NUMBER', 'description': '0 to 1'},
          },
          'required': ['name', 'grams', 'calories', 'protein_g', 'carbs_g', 'fat_g'],
          'propertyOrdering': [
            'name',
            'grams',
            'calories',
            'protein_g',
            'carbs_g',
            'fat_g',
            'fiber_g',
            'confidence',
          ],
        },
      },
    },
    'required': ['items'],
  };

  /// Prompt sent with the meal text.
  static String buildPrompt(String meal) => '''
You are a precise nutrition analysis engine.
Split the meal below into individual foods and estimate each portion's nutrition.
Rules:
- Use USDA FoodData Central or the Indian Food Composition Tables (IFCT 2017) as reference values.
- If a quantity is missing, assume ONE typical serving.
- Include cooking oil/ghee only if the text implies it (e.g. "fried", "paratha", "curry").
- grams = edible portion weight (mL for drinks). All numbers must be >= 0.
- confidence = how sure you are about the identification and portion (0..1).
Meal: """$meal"""''';

  /// Request body for `generateContent`.
  static Map<String, dynamic> buildRequest(String meal) => {
    'contents': [
      {
        'role': 'user',
        'parts': [
          {'text': buildPrompt(meal)},
        ],
      },
    ],
    'generationConfig': {
      'temperature': 0.1,
      'responseMimeType': 'application/json',
      'responseSchema': responseSchema,
    },
  };

  /// Analyses [meal] with retries. Throws after the final failed attempt.
  Future<NutritionAnalysis> analyze(String meal) async {
    final key = _apiKey();
    if (key == null || key.isEmpty) {
      throw RemoteCallException('No Gemini API key configured', retryable: false);
    }
    lastAttempts = 0;
    return _retry.run((attempt) async {
      lastAttempts = attempt + 1;
      final res = await _http.post(
        Uri.parse('$_base/${_model()}:generateContent'),
        headers: {'Content-Type': 'application/json', 'x-goog-api-key': key},
        body: jsonEncode(buildRequest(meal)),
      );
      if (res.statusCode != 200) {
        final retryAfter = int.tryParse(res.headers['retry-after'] ?? '');
        throw RemoteCallException(
          'Gemini HTTP ${res.statusCode}',
          statusCode: res.statusCode,
          retryable: RetryPolicy.isRetryableStatus(res.statusCode),
          retryAfter: retryAfter == null ? null : Duration(seconds: retryAfter),
        );
      }
      return parseResponse(meal, res.body);
    });
  }

  /// Extracts and validates the model's JSON from a raw API response body.
  static NutritionAnalysis parseResponse(String meal, String body) {
    final decoded = jsonDecode(body);
    final candidates = (decoded is Map ? decoded['candidates'] : null) as List?;
    if (candidates == null || candidates.isEmpty) {
      throw const FormatException('No candidates in Gemini response');
    }
    final parts = ((candidates.first as Map)['content'] as Map?)?['parts'] as List?;
    final text = parts?.map((p) => (p as Map)['text'] ?? '').join() ?? '';
    if (text.trim().isEmpty) throw const FormatException('Empty Gemini text');
    final json = jsonDecode(text);
    return validate(meal, json);
  }

  /// Validates the structured JSON against the schema and sanity limits.
  /// Violations throw a *retryable* [RemoteCallException]: a fresh sample
  /// from the model usually fixes a malformed answer.
  static NutritionAnalysis validate(String meal, dynamic json) {
    if (json is! Map || json['items'] is! List) {
      throw RemoteCallException('Schema: "items" array missing');
    }
    final items = <AnalyzedItem>[];
    for (final raw in json['items'] as List) {
      if (raw is! Map) throw RemoteCallException('Schema: item is not an object');
      double field(String k, {bool required = true}) {
        final v = raw[k];
        if (v is num && v.isFinite && v >= 0) return v.toDouble();
        if (!required && v == null) return 0;
        throw RemoteCallException('Schema: "$k" invalid ($v)');
      }

      final name = (raw['name'] as String?)?.trim();
      if (name == null || name.isEmpty) throw RemoteCallException('Schema: name missing');
      final grams = field('grams');
      if (grams > 3000) throw RemoteCallException('Schema: implausible grams $grams');
      final p = field('protein_g'), c = field('carbs_g'), f = field('fat_g');
      var kcal = field('calories');
      // Energy consistency: replace kcal if it disagrees with 4/4/9 by > 35 %.
      final atwater = p * 4 + c * 4 + f * 9;
      if ((kcal - atwater).abs() > 0.35 * (kcal > atwater ? kcal : atwater) + 20) {
        kcal = atwater;
      }
      if (kcal > 5000) throw RemoteCallException('Schema: implausible kcal $kcal');
      items.add(
        AnalyzedItem(
          name: name,
          grams: grams,
          facts: NutritionFacts(
            kcal: kcal,
            protein: p,
            carbs: c,
            fat: f,
            fiber: field('fiber_g', required: false),
          ),
          confidence: (raw['confidence'] is num)
              ? (raw['confidence'] as num).toDouble().clamp(0.0, 1.0)
              : 0.7,
        ),
      );
    }
    if (items.isEmpty) throw RemoteCallException('Schema: no items recognised');
    return NutritionAnalysis(query: meal, items: items, source: AnalysisSource.gemini);
  }
}
