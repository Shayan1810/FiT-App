import 'package:equatable/equatable.dart';

import '../../../../core/utils/id_generator.dart';
import 'nutrition_facts.dart';

/// The four meal slots shown on the Food tab.
enum MealSlot { breakfast, lunch, dinner, snacks }

/// Display and time-of-day helpers for [MealSlot].
extension MealSlotX on MealSlot {
  /// Display label, e.g. "Breakfast".
  String get label => switch (this) {
    MealSlot.breakfast => 'Breakfast',
    MealSlot.lunch => 'Lunch',
    MealSlot.dinner => 'Dinner',
    MealSlot.snacks => 'Snacks',
  };

  /// Slot that best matches the current time of day (default for new logs).
  static MealSlot forTime(DateTime t) {
    if (t.hour < 11) return MealSlot.breakfast;
    if (t.hour < 16) return MealSlot.lunch;
    if (t.hour < 18) return MealSlot.snacks;
    return MealSlot.dinner;
  }
}

/// How the nutrition numbers of a log entry were obtained.
enum EntrySource {
  custom,
  recipe,
  localParser,
  gemini,
  cache,
  manual,

  /// Logged while offline; waiting for the sync queue to analyse it.
  pending,
}

/// One food the user ate.
class FoodLogEntry extends Equatable {
  const FoodLogEntry({
    required this.id,
    required this.dayKey,
    required this.slot,
    required this.name,
    required this.grams,
    required this.facts,
    required this.source,
    required this.createdAt,
    this.foodId,
    this.query,
  });

  /// Always `<dayKey>#<unique>` (see [newId]) so a day's entries can be
  /// fetched by key prefix without decoding the whole diary.
  final String id;

  /// Creates an id for a new entry on [dayKey].
  static String newId(String dayKey) => '$dayKey#${IdGenerator.next()}';

  /// `yyyy-MM-dd` of the day it was eaten.
  final String dayKey;
  final MealSlot slot;
  final String name;
  final double grams;
  final NutritionFacts facts;
  final EntrySource source;
  final DateTime createdAt;

  /// The FoodItem it came from (lets the user change the amount later).
  final String? foodId;

  /// Original free-text query, for AI/parser/pending entries.
  final String? query;

  /// True while the entry waits for an online analysis.
  bool get isPending => source == EntrySource.pending;

  FoodLogEntry copyWith({
    MealSlot? slot,
    String? name,
    double? grams,
    NutritionFacts? facts,
    EntrySource? source,
  }) {
    return FoodLogEntry(
      id: id,
      dayKey: dayKey,
      slot: slot ?? this.slot,
      name: name ?? this.name,
      grams: grams ?? this.grams,
      facts: facts ?? this.facts,
      source: source ?? this.source,
      createdAt: createdAt,
      foodId: foodId,
      query: query,
    );
  }

  @override
  List<Object?> get props => [id, dayKey, slot, name, grams, facts, source, createdAt, foodId, query];
}
