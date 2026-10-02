import 'dart:typed_data';

import 'package:hive_ce_flutter/hive_flutter.dart';

/// Names of every Hive box, plus the code that opens them.
///
/// Box names are prefixed with `fit_`; data lives in the app's private
/// documents directory (`fit/`).
class HiveBoxes {
  HiveBoxes._();

  static const String profile = 'fit_profile';
  static const String weights = 'fit_weights';
  static const String foodLog = 'fit_food_log';
  static const String customFoods = 'fit_custom_foods';
  static const String recipes = 'fit_recipes';
  static const String water = 'fit_water';
  static const String activity = 'fit_activity';
  static const String workouts = 'fit_workouts';
  static const String sleep = 'fit_sleep';
  static const String nutritionCache = 'fit_nutrition_cache';
  static const String syncQueue = 'fit_sync_queue';
  static const String settings = 'fit_settings';
  static const String customExercises = 'fit_custom_exercises';

  /// Every box the app uses.
  static const List<String> all = [
    profile,
    weights,
    foodLog,
    customFoods,
    recipes,
    water,
    activity,
    workouts,
    sleep,
    nutritionCache,
    syncQueue,
    settings,
    customExercises,
  ];

  /// Initialises Hive in the app documents directory and opens all boxes.
  /// Called once from `main()` before `runApp`.
  static Future<void> init() async {
    await Hive.initFlutter('fit');
    await openAll();
  }

  /// Opens all boxes (also used by tests after `Hive.init(tempDir)`).
  static Future<void> openAll() async {
    await Future.wait(all.map((name) => Hive.openBox<dynamic>(name)));
  }

  /// Opens every box purely in memory (no files). Used by tests and the
  /// screenshot generator so they never touch the disk.
  static Future<void> openAllInMemory() async {
    for (final name in all) {
      if (Hive.isBoxOpen(name)) await Hive.box<dynamic>(name).close();
      await Hive.openBox<dynamic>(name, bytes: Uint8List(0));
    }
  }

  /// Returns an already-opened box.
  static Box<dynamic> box(String name) => Hive.box<dynamic>(name);

  /// Wipes every box (Settings → "Reset all data").
  static Future<void> clearAll() async {
    for (final name in all) {
      await Hive.box<dynamic>(name).clear();
    }
  }
}
