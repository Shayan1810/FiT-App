import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/id_generator.dart';
import '../entities/food_item.dart';
import '../entities/food_log_entry.dart';
import '../entities/nutrition_analysis.dart';
import '../repositories/nutrition_repository.dart';

/// Hook used to queue an analysis job for a pending entry.
typedef EnqueuePending = Future<void> Function(String jobId, String text, String entryId);

/// Use case: logging food into the diary — from a database item, from an
/// analysed text, or as an offline placeholder.
class LogFood {
  LogFood(this._repo, {required EnqueuePending enqueue}) : _enqueue = enqueue;

  final NutritionRepository _repo;
  final EnqueuePending _enqueue;

  /// Logs [grams] of [food] on [day] in [slot].
  Future<FoodLogEntry> fromItem({
    required FoodItem food,
    required double grams,
    required MealSlot slot,
    required DateTime day,
  }) async {
    final key = DateKeys.of(day);
    final entry = FoodLogEntry(
      id: FoodLogEntry.newId(key),
      dayKey: key,
      slot: slot,
      name: food.name,
      grams: grams,
      facts: food.factsFor(grams),
      source: switch (food.origin) {
        FoodOrigin.custom => EntrySource.custom,
        FoodOrigin.recipe => EntrySource.recipe,
      },
      createdAt: DateTime.now(),
      foodId: food.id,
    );
    await _repo.saveEntry(entry);
    return entry;
  }

  /// Logs every item of an [analysis] as separate diary entries.
  /// A `pending` analysis becomes one placeholder entry + a queued job.
  Future<List<FoodLogEntry>> fromAnalysis({
    required NutritionAnalysis analysis,
    required MealSlot slot,
    required DateTime day,
  }) async {
    final key = DateKeys.of(day);
    final now = DateTime.now();

    if (analysis.source == AnalysisSource.pending) {
      final entry = FoodLogEntry(
        id: FoodLogEntry.newId(key),
        dayKey: key,
        slot: slot,
        name: analysis.query,
        grams: 0,
        facts: analysis.total,
        source: EntrySource.pending,
        createdAt: now,
        query: analysis.query,
      );
      await _repo.saveEntry(entry);
      await _enqueue(IdGenerator.next('job_'), analysis.query, entry.id);
      return [entry];
    }

    final source = switch (analysis.source) {
      AnalysisSource.gemini => EntrySource.gemini,
      AnalysisSource.cache => EntrySource.cache,
      _ => EntrySource.localParser,
    };
    final entries = <FoodLogEntry>[];
    for (final item in analysis.items) {
      final e = FoodLogEntry(
        id: FoodLogEntry.newId(key),
        dayKey: key,
        slot: slot,
        name: item.name,
        grams: item.grams,
        facts: item.facts,
        source: source,
        createdAt: now,
        foodId: item.foodId,
        query: analysis.query,
      );
      await _repo.saveEntry(e);
      entries.add(e);
    }
    return entries;
  }

  /// Changes the amount of an existing entry, rescaling its nutrition.
  Future<void> changeAmount(FoodLogEntry entry, double grams) async {
    if (entry.grams <= 0 || grams <= 0) return;
    await _repo.saveEntry(entry.copyWith(grams: grams, facts: entry.facts.scale(grams / entry.grams)));
  }
}
