import '../domain/entities/food_item.dart';
import '../domain/entities/food_log_entry.dart';
import '../domain/entities/nutrition_facts.dart';
import '../domain/entities/recipe.dart';

T _enum<T extends Enum>(List<T> values, Object? name, T fallback) =>
    values.firstWhere((v) => v.name == name, orElse: () => fallback);

NutritionFacts _facts(Object? m) =>
    NutritionFacts.fromMap(Map<String, dynamic>.from((m as Map?) ?? const {}));

/// [FoodLogEntry] ↔ map.
class FoodLogEntryMapper {
  FoodLogEntryMapper._();

  static Map<String, dynamic> toMap(FoodLogEntry e) => {
    'id': e.id,
    'dayKey': e.dayKey,
    'slot': e.slot.name,
    'name': e.name,
    'grams': e.grams,
    'facts': e.facts.toMap(),
    'source': e.source.name,
    'createdAt': e.createdAt.millisecondsSinceEpoch,
    'foodId': e.foodId,
    'query': e.query,
  };

  static FoodLogEntry fromMap(Map<String, dynamic> m) => FoodLogEntry(
    id: m['id'] as String,
    dayKey: m['dayKey'] as String,
    slot: _enum(MealSlot.values, m['slot'], MealSlot.snacks),
    name: m['name'] as String? ?? 'Food',
    grams: (m['grams'] as num?)?.toDouble() ?? 0,
    facts: _facts(m['facts']),
    source: _enum(EntrySource.values, m['source'], EntrySource.manual),
    createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int),
    foodId: m['foodId'] as String?,
    query: m['query'] as String?,
  );
}

/// Custom [FoodItem] ↔ map.
class FoodItemMapper {
  FoodItemMapper._();

  static Map<String, dynamic> toMap(FoodItem f) => {
    'id': f.id,
    'name': f.name,
    'aliases': f.aliases,
    'category': f.category,
    'per100g': f.per100g.toMap(),
    'servingGrams': f.servingGrams,
    'servingLabel': f.servingLabel,
    'origin': f.origin.name,
  };

  static FoodItem fromMap(Map<String, dynamic> m) => FoodItem(
    id: m['id'] as String,
    name: m['name'] as String? ?? 'Food',
    aliases: ((m['aliases'] as List?) ?? const []).cast<String>(),
    category: m['category'] as String? ?? 'My foods',
    per100g: _facts(m['per100g']),
    servingGrams: (m['servingGrams'] as num?)?.toDouble() ?? 100,
    servingLabel: m['servingLabel'] as String? ?? '100 g',
    origin: _enum(FoodOrigin.values, m['origin'], FoodOrigin.custom),
  );
}

/// [Recipe] ↔ map.
class RecipeMapper {
  RecipeMapper._();

  static Map<String, dynamic> toMap(Recipe r) => {
    'id': r.id,
    'name': r.name,
    'servings': r.servings,
    'ingredients': r.ingredients
        .map((i) => {'name': i.name, 'grams': i.grams, 'facts': i.facts.toMap(), 'foodId': i.foodId})
        .toList(),
  };

  static Recipe fromMap(Map<String, dynamic> m) => Recipe(
    id: m['id'] as String,
    name: m['name'] as String? ?? 'Recipe',
    servings: (m['servings'] as int?) ?? 1,
    ingredients: ((m['ingredients'] as List?) ?? const []).map((raw) {
      final i = Map<String, dynamic>.from(raw as Map);
      return RecipeIngredient(
        name: i['name'] as String? ?? '',
        grams: (i['grams'] as num?)?.toDouble() ?? 0,
        facts: _facts(i['facts']),
        foodId: i['foodId'] as String?,
      );
    }).toList(),
  );
}
