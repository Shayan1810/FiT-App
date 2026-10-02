/// A quantity extracted from text, e.g. "2 cups" → (2, 'cup').
class ParsedQuantity {
  const ParsedQuantity({required this.amount, required this.unit, required this.foodText});

  /// Numeric amount (defaults to 1 when only a unit or nothing is given).
  final double amount;

  /// Canonical unit (`g`, `ml`, `cup`, …) or null for "count of servings".
  final String? unit;

  /// The remaining words naming the food.
  final String foodText;
}

/// Parses amounts and units out of meal fragments.
///
/// Understands digits ("2", "1.5", "1/2"), words ("one", "half", "a",
/// "couple"), mass/volume units (g, kg, ml, l), household measures (cup,
/// bowl, katori, plate, glass, tbsp, tsp, scoop, slice, piece) and "2x".
class QuantityParser {
  QuantityParser._();

  static const Map<String, double> _wordNumbers = {
    'a': 1,
    'an': 1,
    'one': 1,
    'two': 2,
    'three': 3,
    'four': 4,
    'five': 5,
    'six': 6,
    'seven': 7,
    'eight': 8,
    'nine': 9,
    'ten': 10,
    'half': 0.5,
    'quarter': 0.25,
    'couple': 2,
    'few': 3,
    'dozen': 12,
    'some': 1,
  };

  /// Alias → canonical unit.
  static const Map<String, String> _units = {
    'g': 'g',
    'gm': 'g',
    'gms': 'g',
    'gram': 'g',
    'grams': 'g',
    'gr': 'g',
    'kg': 'kg',
    'kgs': 'kg',
    'ml': 'ml',
    'mls': 'ml',
    'millilitre': 'ml',
    'milliliter': 'ml',
    'l': 'l',
    'litre': 'l',
    'liter': 'l',
    'litres': 'l',
    'liters': 'l',
    'ltr': 'l',
    'cup': 'cup',
    'cups': 'cup',
    'mug': 'cup',
    'mugs': 'cup',
    'bowl': 'bowl',
    'bowls': 'bowl',
    'katori': 'bowl',
    'katoris': 'bowl',
    'plate': 'plate',
    'plates': 'plate',
    'glass': 'glass',
    'glasses': 'glass',
    'tbsp': 'tbsp',
    'tablespoon': 'tbsp',
    'tablespoons': 'tbsp',
    'tsp': 'tsp',
    'teaspoon': 'tsp',
    'teaspoons': 'tsp',
    'scoop': 'scoop',
    'scoops': 'scoop',
    'slice': 'slice',
    'slices': 'slice',
    'piece': 'piece',
    'pieces': 'piece',
    'pc': 'piece',
    'pcs': 'piece',
    'nos': 'piece',
    'serving': 'serving',
    'servings': 'serving',
    'portion': 'serving',
    'portions': 'serving',
    'handful': 'serving',
    'handfuls': 'serving',
  };

  /// Default grams for household measures when the food's own serving
  /// label doesn't match the unit (Indian Food Composition Tables / USDA
  /// household-measure conventions).
  static const Map<String, double> householdGrams = {
    'cup': 200,
    'bowl': 150,
    'plate': 250,
    'glass': 250,
    'tbsp': 15,
    'tsp': 5,
    'scoop': 30,
    'slice': 25,
  };

  /// Words that carry no meaning for matching.
  static const Set<String> _filler = {'of', 'some', 'with', 'my', 'the', 'small', 'large', 'big', 'medium'};

  /// Parses one fragment such as "2 cups of rice" or "200g paneer".
  static ParsedQuantity parse(String fragment) {
    var text = fragment.toLowerCase().trim();
    double? amount;
    String? unit;

    // "200g" / "1.5kg" / "250ml" glued to the number.
    final glued = RegExp(r'^(\d+(?:\.\d+)?)\s*(g|gm|gms|kg|ml|l|ltr)\b').firstMatch(text);
    if (glued != null) {
      amount = double.parse(glued.group(1)!);
      unit = _units[glued.group(2)!];
      text = text.substring(glued.end);
    } else {
      // Fraction "1/2", decimal "1.5", integer "2", or "2x".
      final num = RegExp(r'^(\d+)\s*/\s*(\d+)|^(\d+(?:\.\d+)?)\s*x?\b').firstMatch(text);
      if (num != null) {
        amount = num.group(1) != null
            ? double.parse(num.group(1)!) / double.parse(num.group(2)!)
            : double.parse(num.group(3)!);
        text = text.substring(num.end);
      } else {
        final word = RegExp(r'^([a-z]+)\b').firstMatch(text);
        if (word != null && _wordNumbers.containsKey(word.group(1))) {
          amount = _wordNumbers[word.group(1)];
          text = text.substring(word.end);
          // "half a banana" / "a couple of eggs"
          text = text.replaceFirst(RegExp(r'^\s*(a|an|of)\b'), '');
        }
      }
      // Unit word after the number.
      final u = RegExp(r'^\s*([a-z]+)\b').firstMatch(text);
      if (u != null && _units.containsKey(u.group(1))) {
        unit = _units[u.group(1)!];
        text = text.substring(u.end);
      }
    }

    final words = text
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && !_filler.contains(w))
        .toList();
    return ParsedQuantity(amount: amount ?? 1, unit: unit, foodText: words.join(' '));
  }

  /// Splits a meal description into food fragments on commas, "and",
  /// "with", "+", "&", ";" and new lines.
  static List<String> split(String text) => text
      .split(RegExp(r',|;|\+|&|\n|\band\b|\bwith\b', caseSensitive: false))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}
