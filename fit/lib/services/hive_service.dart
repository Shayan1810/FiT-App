import 'package:hive_flutter/hive_flutter.dart';
import '../models/user_data.dart';
import '../models/food_item.dart';
import '../models/recipe.dart';
import '../models/meal_data.dart';
import '../models/activity_data.dart';

class HiveService {
static const String userBoxName = 'userBox';
static const String macroBoxName = 'macroBox';
static const String powerBoxName = 'powerBox';
static const String foodItemBoxName = 'foodItemBox';
static const String recipeBoxName = 'recipeBox';
static const String _activityBox = 'activity_data';
static const String dayLogBox = 'activity_data';


static Future<void> initHive() async {
await Hive.initFlutter();


Hive.registerAdapter(UserDataAdapter());
Hive.registerAdapter(FoodItemAdapter());
Hive.registerAdapter(RecipeAdapter());
Hive.registerAdapter(RecipeIngredientAdapter());
Hive.registerAdapter(MealDataAdapter());
Hive.registerAdapter(ActivityDataAdapter());

await Hive.openBox<UserData>(userBoxName);
await Hive.openBox<FoodItem>(foodItemBoxName);
await Hive.openBox<Recipe>(recipeBoxName);
await Hive.openBox('calorieLogBox');
await Hive.openBox<ActivityData>(_activityBox);

}

static Future<void> saveRecipe(Recipe recipe) async {
  try {
    final box = Hive.box<Recipe>(recipeBoxName);
    final key = '${recipe.name.toLowerCase().replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}';
    await box.put(key, recipe);
    print('Recipe saved: ${recipe.name}');
  } catch (e) {
    print('Error saving recipe: $e');
    rethrow;
  }
}

static ActivityData? getActivityData() => Hive.box<ActivityData>(_activityBox).get('current_user');
static Future<void> saveActivityData(ActivityData data) => Hive.box<ActivityData>(_activityBox).put('current_user', data);

static Future<void> saveUserData(UserData userData) async {
final box = Hive.box<UserData>(userBoxName);
await box.put('current_user', userData);
}

static Future<void> deleteRecipe(String key) async {
  try {
    final box = Hive.box<Recipe>(recipeBoxName);
    await box.delete(key);
    print('Recipe deleted');
  } catch (e) {
    print('Error deleting recipe: $e');
    rethrow;
  }
}

static List<Recipe> getAllRecipes() {
  try {
    final box = Hive.box<Recipe>(recipeBoxName);
    return box.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  } catch (e) {
    print('Error getting recipes: $e');
    return [];
  }
}

static List<Recipe> searchRecipes(String query) {
  try {
    final box = Hive.box<Recipe>(recipeBoxName);
    final allRecipes = box.values.toList();
    return allRecipes.where((recipe) => 
      recipe.name.toLowerCase().contains(query.toLowerCase())
    ).toList()..sort((a, b) => a.name.compareTo(b.name));
  } catch (e) {
    print('Error searching recipes: $e');
    return [];
  }
}

static UserData? getUserData() {
final box = Hive.box<UserData>(userBoxName);
return box.get('current_user');
}

static Future<void> updateWeight(double newWeight) async {
final box = Hive.box<UserData>(userBoxName);
final userData = box.get('current_user');
if (userData != null) {
userData.weight = newWeight;
userData.lastUpdated = DateTime.now();
await box.put('current_user', userData);
}
}

static Future<void> updateCalories(int caloriesIn, int caloriesOut) async {
final box = Hive.box<UserData>(userBoxName);
final userData = box.get('current_user');
if (userData != null) {
userData.caloriesIn = caloriesIn;
userData.caloriesOut = caloriesOut;
userData.lastUpdated = DateTime.now();
await box.put('current_user', userData);
}
}

static Future<void> saveFoodItem(FoodItem foodItem) async {
  try {
    final box = Hive.box<FoodItem>(foodItemBoxName);
    final key = '${foodItem.name.toLowerCase().replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}';
    await box.put(key, foodItem);
    print('Food item saved: ${foodItem.name}');
  } catch (e) {
    print('Error saving food item: $e');
    rethrow;
  }
}

static Future<void> clearAllFoodItems() async {
  try {
    await Hive.box<FoodItem>(foodItemBoxName).clear();
    print('All food items cleared');
  } catch (e) {
    print('Error clearing food items: $e');
    rethrow;
  }
}

static Future<void> deleteFoodItem(String key) async {
  try {
    final box = Hive.box<FoodItem>(foodItemBoxName);
    await box.delete(key);
    print('Food item deleted');
  } catch (e) {
    print('Error deleting food item: $e');
    rethrow;
  }
}

static List<FoodItem> getAllFoodItems() {
  try {
    final box = Hive.box<FoodItem>(foodItemBoxName);
    return box.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  } catch (e) {
    print('Error getting food items: $e');
    return [];
  }
}

static List<FoodItem> searchFoodItems(String query) {
  try {
    final box = Hive.box<FoodItem>(foodItemBoxName);
    final allItems = box.values.toList();
    return allItems.where((item) => 
      item.name.toLowerCase().contains(query.toLowerCase())
    ).toList()..sort((a, b) => a.name.compareTo(b.name));
  } catch (e) {
    print('Error searching food items: $e');
    return [];
  }
}

static String? getUserProfileImage() {
final userData = getUserData();
return userData?.profileImagePath;
}

static String getUserName() {
final userData = getUserData();
return userData?.name ?? 'User';
}

static Future<void> clearAllData() async {
await Hive.box<UserData>(userBoxName).clear();
}
}
