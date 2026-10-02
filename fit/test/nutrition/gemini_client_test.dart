import 'dart:convert';

import 'package:fit/core/network/retry_policy.dart';
import 'package:fit/features/nutrition/data/datasources/gemini_nutrition_client.dart';
import 'package:fit/features/nutrition/domain/entities/nutrition_analysis.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Wraps model JSON in the Gemini REST envelope.
String envelope(Object modelJson) => jsonEncode({
  'candidates': [
    {
      'content': {
        'parts': [
          {'text': jsonEncode(modelJson)},
        ],
      },
    },
  ],
});

const goodJson = {
  'items': [
    {
      'name': 'Quokka steak',
      'grams': 200,
      'calories': 330,
      'protein_g': 44,
      'carbs_g': 0,
      'fat_g': 17,
      'fiber_g': 0,
      'confidence': 0.6,
    },
  ],
};

GeminiNutritionClient client(MockClient http, {String? key = 'test-key'}) => GeminiNutritionClient(
  httpClient: http,
  apiKey: () => key,
  model: () => 'gemini-2.5-flash',
  retryPolicy: RetryPolicy(sleep: (_) async {}),
);

void main() {
  test('request uses JSON mode + response schema and the key header', () async {
    late http.Request captured;
    final c = client(
      MockClient((req) async {
        captured = req;
        return http.Response(envelope(goodJson), 200);
      }),
    );
    await c.analyze('quokka steak');
    final body = jsonDecode(captured.body) as Map;
    expect(body['generationConfig']['responseMimeType'], 'application/json');
    expect(body['generationConfig']['responseSchema']['properties'], contains('items'));
    expect(captured.headers['x-goog-api-key'], 'test-key');
    expect(captured.url.toString(), contains('gemini-2.5-flash:generateContent'));
  });

  test('retries 503 / 429 then succeeds', () async {
    var calls = 0;
    final c = client(
      MockClient((_) async {
        calls++;
        if (calls == 1) return http.Response('busy', 503);
        if (calls == 2) return http.Response('slow down', 429, headers: {'retry-after': '1'});
        return http.Response(envelope(goodJson), 200);
      }),
    );
    final a = await c.analyze('quokka steak');
    expect(calls, 3);
    expect(c.lastAttempts, 3);
    expect(a.source, AnalysisSource.gemini);
    expect(a.items.single.grams, 200);
  });

  test('malformed model output is retried', () async {
    var calls = 0;
    final c = client(
      MockClient((_) async {
        calls++;
        if (calls == 1) return http.Response(envelope({'oops': true}), 200);
        if (calls == 2) {
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': 'not json'},
                    ],
                  },
                },
              ],
            }),
            200,
          );
        }
        return http.Response(envelope(goodJson), 200);
      }),
    );
    await c.analyze('x');
    expect(calls, 3);
  });

  test('400 is not retried', () async {
    var calls = 0;
    final c = client(
      MockClient((_) async {
        calls++;
        return http.Response('bad', 400);
      }),
    );
    await expectLater(c.analyze('x'), throwsA(isA<RemoteCallException>()));
    expect(calls, 1);
  });

  test('no API key → immediate non-retryable failure', () async {
    final c = client(MockClient((_) async => http.Response('', 200)), key: null);
    expect(c.isConfigured, isFalse);
    await expectLater(c.analyze('x'), throwsA(isA<RemoteCallException>()));
  });

  test('validation repairs calories that contradict the macros', () {
    final a = GeminiNutritionClient.validate('x', {
      'items': [
        {'name': 'Thing', 'grams': 100, 'calories': 900, 'protein_g': 10, 'carbs_g': 10, 'fat_g': 1},
      ],
    });
    expect(a.items.single.facts.kcal, 10 * 4 + 10 * 4 + 1 * 9);
  });

  test('validation rejects negative numbers', () {
    expect(
      () => GeminiNutritionClient.validate('x', {
        'items': [
          {'name': 'Thing', 'grams': -5, 'calories': 10, 'protein_g': 1, 'carbs_g': 1, 'fat_g': 1},
        ],
      }),
      throwsA(isA<RemoteCallException>()),
    );
  });

  test('retry layer alone recovers > 95 % of calls even at 50 % server failure', () async {
    // Deterministic pseudo-random failure pattern over 400 queries.
    var seed = 7;
    bool fail() {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return seed % 100 < 50;
    }

    final c = client(
      MockClient((_) async => fail() ? http.Response('busy', 503) : http.Response(envelope(goodJson), 200)),
    );
    var ok = 0;
    const n = 400;
    for (var i = 0; i < n; i++) {
      try {
        await c.analyze('meal $i');
        ok++;
      } catch (_) {}
    }
    // Theory: 1 − 0.5⁵ = 96.9 % from retries alone — the pipeline's cache and
    // offline fallback cover the rest; here we assert the retry layer.
    expect(ok / n, greaterThan(0.95));
  });
}
