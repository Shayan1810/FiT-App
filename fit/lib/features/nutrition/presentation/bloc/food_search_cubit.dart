import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/food_item.dart';
import '../../domain/entities/recipe.dart';
import '../../domain/repositories/nutrition_repository.dart';

/// Live food search (built-in + custom + recipes) and custom-food/recipe
/// management for the "My foods" screen.
class FoodSearchCubit extends Cubit<List<FoodItem>> {
  FoodSearchCubit(this._repo) : super(const []) {
    search('');
  }

  final NutritionRepository _repo;
  String _query = '';

  /// Updates results for [query] (fuzzy, typo-tolerant).
  void search(String query) {
    _query = query;
    emit(_repo.searchFoods(query, limit: 40));
  }

  /// User-created foods.
  List<FoodItem> customFoods() => _repo.customFoods();

  /// User recipes.
  List<Recipe> recipes() => _repo.recipes();

  /// Saves a custom food and refreshes results.
  Future<void> saveCustomFood(FoodItem f) async {
    await _repo.saveCustomFood(f);
    search(_query);
  }

  /// Deletes a custom food and refreshes results.
  Future<void> deleteCustomFood(String id) async {
    await _repo.deleteCustomFood(id);
    search(_query);
  }

  /// Saves a recipe and refreshes results.
  Future<void> saveRecipe(Recipe r) async {
    await _repo.saveRecipe(r);
    search(_query);
  }

  /// Deletes a recipe and refreshes results.
  Future<void> deleteRecipe(String id) async {
    await _repo.deleteRecipe(id);
    search(_query);
  }
}
