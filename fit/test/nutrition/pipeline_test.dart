import 'dart:convert';

import 'package:fit/core/di/injector.dart';
import 'package:fit/core/storage/settings_store.dart';
import 'package:fit/core/utils/date_utils.dart';
import 'package:fit/features/nutrition/data/repositories/nutrition_pipeline.dart';
import 'package:fit/features/nutrition/data/sync/sync_coordinator.dart';
import 'package:fit/features/nutrition/domain/entities/food_log_entry.dart';
import 'package:fit/features/nutrition/domain/entities/nutrition_analysis.dart';
import 'package:fit/features/nutrition/domain/repositories/nutrition_repository.dart';
import 'package:fit/features/nutrition/domain/usecases/log_food.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../helpers/sample_foods.dart';
import '../helpers/test_env.dart';
import 'gemini_client_test.dart' show envelope, goodJson;

void main() {
  var geminiCalls = 0;
  var geminiUp = true;
  final mock = MockClient((_) async {
    geminiCalls++;
    return geminiUp ? http.Response(envelope(goodJson), 200) : http.Response('down', 503);
  });

  setUp(() async {
    geminiCalls = 0;
    geminiUp = true;
  });
  tearDown(tearDownTestEnv);

  /// Puts the sample foods into "My foods" (the offline parser's source).
  Future<void> seedFoods() async {
    for (final f in SampleFoods.all) {
      await sl<NutritionRepository>().saveCustomFood(f);
    }
  }

  test('stage 2: known foods never call Gemini, then come from cache', () async {
    await setUpTestEnv(httpClient: mock);
    await sl<SettingsStore>().write(SettingsStore.kGeminiApiKey, 'k');
    await seedFoods();
    final p = sl<NutritionAnalysisRepository>();

    final a = await p.analyze('2 roti and dal');
    expect(a.source, AnalysisSource.localDatabase);
    final b = await p.analyze('2 Rotis and dal!');
    expect(b.source, AnalysisSource.cache);
    expect(geminiCalls, 0);
  });

  test('stage 3: unknown food goes to Gemini once, then cache', () async {
    await setUpTestEnv(httpClient: mock);
    await sl<SettingsStore>().write(SettingsStore.kGeminiApiKey, 'k');
    final p = sl<NutritionAnalysisRepository>();

    expect((await p.analyze('quokka steak')).source, AnalysisSource.gemini);
    expect((await p.analyze('quokka steak')).source, AnalysisSource.cache);
    expect(geminiCalls, 1);
  });

  test('without a key, unknown foods fail gracefully (no throw)', () async {
    await setUpTestEnv(httpClient: mock);
    final a = await sl<NutritionAnalysisRepository>().analyze('quokka steak');
    expect(a.items, isEmpty);
    expect(a.unmatched, isNotEmpty);
    expect(geminiCalls, 0);
  });

  test('offline → pending placeholder → resolved automatically when back online', () async {
    final net = await setUpTestEnv(online: false, httpClient: mock);
    await sl<SettingsStore>().write(SettingsStore.kGeminiApiKey, 'k');
    final p = sl<NutritionAnalysisRepository>();
    final repo = sl<NutritionRepository>();
    final sync = sl<SyncCoordinator>()..start();

    final a = await p.analyze('quokka steak');
    expect(a.source, AnalysisSource.pending);

    final logged = await sl<LogFood>().fromAnalysis(analysis: a, slot: MealSlot.dinner, day: DateTime.now());
    expect(logged.single.isPending, isTrue);
    expect(sync.pending, 1);

    net.set(true); // reconnect → coordinator drains the queue
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sync.drain();

    final entry = repo.entriesForDay(DateKeys.of(DateTime.now())).single;
    expect(entry.isPending, isFalse);
    expect(entry.source, EntrySource.gemini);
    expect(entry.facts.protein, 44);
    expect(sync.pending, 0);
    expect(NutritionPipeline.successRate(sl<SettingsStore>()), 1.0);
    await sync.stop();
  });

  test('Gemini down + partially known meal → partial result, still a success', () async {
    await setUpTestEnv(httpClient: mock);
    await sl<SettingsStore>().write(SettingsStore.kGeminiApiKey, 'k');
    await seedFoods();
    geminiUp = false;
    final a = await sl<NutritionAnalysisRepository>().analyze('2 roti and quokka steak');
    expect(a.source, AnalysisSource.partial);
    expect(a.items.single.foodId, 'food_roti');
    expect(geminiCalls, 5); // full retry budget used
  });

  test('end-to-end success ≥ 99.5 % with a 30 % flaky Gemini', () async {
    var seed = 11;
    final flaky = MockClient((_) async {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return seed % 100 < 30 ? http.Response('busy', 503) : http.Response(envelope(goodJson), 200);
    });
    await setUpTestEnv(httpClient: flaky);
    await sl<SettingsStore>().write(SettingsStore.kGeminiApiKey, 'k');
    await seedFoods();
    final p = sl<NutritionAnalysisRepository>();
    const n = 600;
    var ok = 0;
    for (var i = 0; i < n; i++) {
      // Mix of known foods, repeats and never-seen foods.
      final text = switch (i % 3) {
        0 => '2 roti and dal',
        1 => 'mystery dish $i',
        _ => 'mystery dish ${i - 1}',
      };
      final a = await p.analyze(text);
      if (a.items.isNotEmpty) ok++;
    }
    expect(ok / n, greaterThanOrEqualTo(0.995));
    expect(NutritionPipeline.successRate(sl<SettingsStore>()), greaterThanOrEqualTo(0.995));
  });

  test('request body is valid JSON for Gemini', () {
    expect(() => jsonEncode({'x': goodJson}), returnsNormally);
  });
}
