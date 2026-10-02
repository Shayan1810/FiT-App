import '../entities/food_item.dart';
import '../entities/food_log_entry.dart';
import '../entities/nutrition_analysis.dart';
import '../entities/recipe.dart';

/// Food diary, water, custom foods and recipes — all stored offline.
abstract class NutritionRepository {
  /// Entries logged on [dayKey], ordered by time.
  List<FoodLogEntry> entriesForDay(String dayKey);

  /// Entries for every day in [dayKeys] (used by the insight engine).
  Map<String, List<FoodLogEntry>> entriesForDays(Iterable<String> dayKeys);

  /// Adds or replaces an entry.
  Future<void> saveEntry(FoodLogEntry entry);

  /// Removes an entry.
  Future<void> deleteEntry(String id);

  /// Finds an entry by id.
  FoodLogEntry? entryById(String id);

  /// Millilitres of water drunk on [dayKey].
  int waterFor(String dayKey);

  /// Sets the water total for [dayKey].
  Future<void> setWater(String dayKey, int ml);

  /// User-created foods.
  List<FoodItem> customFoods();

  /// Creates or replaces a custom food.
  Future<void> saveCustomFood(FoodItem food);

  /// Deletes a custom food.
  Future<void> deleteCustomFood(String id);

  /// User recipes.
  List<Recipe> recipes();

  /// Creates or replaces a recipe.
  Future<void> saveRecipe(Recipe recipe);

  /// Deletes a recipe.
  Future<void> deleteRecipe(String id);

  /// Searches built-in foods, custom foods and recipes; best matches first.
  List<FoodItem> searchFoods(String query, {int limit = 30});

  /// Looks up any food (built-in, custom or recipe) by id.
  FoodItem? foodById(String id);

  /// Emits whenever diary, water, foods or recipes change.
  Stream<void> watch();
}

/// Turns free-text meal descriptions into nutrition (see the pipeline docs).
abstract class NutritionAnalysisRepository {
  /// Full pipeline: cache → local parser → Gemini (if online & configured)
  /// → partial / pending fallback. Never throws.
  Future<NutritionAnalysis> analyze(String text);

  /// Remote-only analysis used by the offline queue when back online.
  /// Throws if Gemini is unavailable or fails after all retries.
  Future<NutritionAnalysis> analyzeRemote(String text);

  /// True if a Gemini API key is configured.
  bool get remoteAvailable;
}
