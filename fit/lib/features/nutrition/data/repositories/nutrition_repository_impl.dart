import '../../../../core/storage/hive_store.dart';
import '../../../../core/utils/streams.dart';
import '../../domain/entities/food_item.dart';
import '../../domain/entities/food_log_entry.dart';
import '../../domain/entities/recipe.dart';
import '../../domain/repositories/nutrition_repository.dart';
import '../parsing/food_matcher.dart';

/// Hive-backed [NutritionRepository].
class NutritionRepositoryImpl implements NutritionRepository {
  NutritionRepositoryImpl({
    required HiveStore<FoodLogEntry> log,
    required HiveStore<FoodItem> customFoods,
    required HiveStore<Recipe> recipes,
    required HiveStore<int> water,
  }) : _log = log,
       _custom = customFoods,
       _recipes = recipes,
       _water = water;

  final HiveStore<FoodLogEntry> _log;
  final HiveStore<FoodItem> _custom;
  final HiveStore<Recipe> _recipes;
  final HiveStore<int> _water;

  @override
  List<FoodLogEntry> entriesForDay(String dayKey) =>
      _log.whereKey((k) => k.startsWith('$dayKey#'))..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  @override
  Map<String, List<FoodLogEntry>> entriesForDays(Iterable<String> dayKeys) {
    final wanted = dayKeys.toSet();
    final out = {for (final k in wanted) k: <FoodLogEntry>[]};
    final entries = _log.whereKey((k) {
      final hash = k.indexOf('#');
      return hash > 0 && wanted.contains(k.substring(0, hash));
    });
    for (final e in entries) {
      out[e.dayKey]!.add(e);
    }
    return out;
  }

  @override
  Future<void> saveEntry(FoodLogEntry entry) => _log.put(entry.id, entry);

  @override
  Future<void> deleteEntry(String id) => _log.delete(id);

  @override
  FoodLogEntry? entryById(String id) => _log.get(id);

  @override
  int waterFor(String dayKey) => _water.get(dayKey) ?? 0;

  @override
  Future<void> setWater(String dayKey, int ml) => _water.put(dayKey, ml < 0 ? 0 : ml);

  @override
  List<FoodItem> customFoods() => _custom.getAll()..sort((a, b) => a.name.compareTo(b.name));

  @override
  Future<void> saveCustomFood(FoodItem food) => _custom.put(food.id, food);

  @override
  Future<void> deleteCustomFood(String id) => _custom.delete(id);

  @override
  List<Recipe> recipes() => _recipes.getAll()..sort((a, b) => a.name.compareTo(b.name));

  @override
  Future<void> saveRecipe(Recipe recipe) => _recipes.put(recipe.id, recipe);

  @override
  Future<void> deleteRecipe(String id) => _recipes.delete(id);

  /// Your foods + recipes (the offline parser's vocabulary).
  List<FoodItem> allFoods() => [...customFoods(), ...recipes().map((r) => r.toFoodItem())];

  @override
  List<FoodItem> searchFoods(String query, {int limit = 30}) {
    final q = query.trim();
    if (q.isEmpty) {
      return allFoods().take(limit).toList();
    }
    return FoodMatcher.rank(q, allFoods(), limit: limit).map((m) => m.food).toList();
  }

  @override
  FoodItem? foodById(String id) {
    return _custom.get(id) ?? _recipes.get(id)?.toFoodItem();
  }

  @override
  Stream<void> watch() => mergeChanges([_log.watch(), _custom.watch(), _recipes.watch(), _water.watch()]);
}
