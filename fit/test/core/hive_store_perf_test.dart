import 'dart:io';

import 'package:fit/core/storage/hive_store.dart';
import 'package:fit/core/utils/perf_monitor.dart';
import 'package:fit/features/nutrition/data/nutrition_mappers.dart';
import 'package:fit/features/nutrition/domain/entities/food_log_entry.dart';
import 'package:fit/features/nutrition/domain/entities/nutrition_facts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

/// Verifies the "sub-15 ms CRUD" claim against a real, disk-backed Hive box.
void main() {
  late Directory dir;
  late HiveStore<FoodLogEntry> store;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('fit_perf_');
    Hive.init(dir.path);
    final box = await Hive.openBox<dynamic>('perf_food');
    store = HiveStore<FoodLogEntry>(
      box,
      toMap: FoodLogEntryMapper.toMap,
      fromMap: FoodLogEntryMapper.fromMap,
    );
  });

  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  FoodLogEntry entry(int i) {
    final day = '2025-06-${(i % 28 + 1).toString().padLeft(2, '0')}';
    return FoodLogEntry(
      id: '$day#$i',
      dayKey: day,
      slot: MealSlot.values[i % 4],
      name: 'Food $i',
      grams: 100,
      facts: const NutritionFacts(kcal: 250, protein: 20, carbs: 30, fat: 5, fiber: 3),
      source: EntrySource.custom,
      createdAt: DateTime(2025, 6, 1).add(Duration(minutes: i)),
    );
  }

  test('create / read / update / delete each average < 15 ms', () async {
    PerfMonitor.instance.reset();
    const n = 1000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < n; i++) {
      await store.put(entry(i).id, entry(i));
    }
    final createMs = sw.elapsedMicroseconds / 1000 / n;

    sw.reset();
    for (var i = 0; i < n; i++) {
      expect(store.get(entry(i).id)?.name, 'Food $i');
    }
    final readMs = sw.elapsedMicroseconds / 1000 / n;

    sw.reset();
    for (var i = 0; i < n; i++) {
      await store.put(entry(i).id, entry(i).copyWith(grams: 150));
    }
    final updateMs = sw.elapsedMicroseconds / 1000 / n;

    sw.reset();
    final day = store.whereKey((k) => k.startsWith('2025-06-05#'));
    final dayQueryMs = sw.elapsedMicroseconds / 1000;
    expect(day, isNotEmpty);

    sw.reset();
    for (var i = 0; i < n; i++) {
      await store.delete(entry(i).id);
    }
    final deleteMs = sw.elapsedMicroseconds / 1000 / n;

    // ignore: avoid_print
    print(
      'Hive CRUD avg ms — create ${createMs.toStringAsFixed(3)}, read ${readMs.toStringAsFixed(3)}, '
      'update ${updateMs.toStringAsFixed(3)}, delete ${deleteMs.toStringAsFixed(3)}, '
      'day query over $n rows ${dayQueryMs.toStringAsFixed(3)}',
    );
    expect(createMs, lessThan(15));
    expect(readMs, lessThan(15));
    expect(updateMs, lessThan(15));
    expect(deleteMs, lessThan(15));
    expect(dayQueryMs, lessThan(15));
    expect(PerfMonitor.instance.stats(), isNotEmpty);
  });
}
