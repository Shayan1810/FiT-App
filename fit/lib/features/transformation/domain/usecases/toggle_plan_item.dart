import '../../../../core/domain/data_source.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../nutrition/domain/entities/food_log_entry.dart';
import '../../../nutrition/domain/entities/nutrition_facts.dart';
import '../../../nutrition/domain/repositories/nutrition_repository.dart';
import '../../../sleep/domain/entities/sleep_session.dart';
import '../../../sleep/domain/repositories/sleep_repository.dart';
import '../../../workout/domain/entities/workout_session.dart';
import '../../../workout/domain/repositories/workout_repository.dart';
import '../entities/transformation_plan.dart';
import '../repositories/transformation_repository.dart';

/// Use case: tick / untick a plan item on a day.
///
/// Ticking writes the real record so every other screen, the coach and the
/// Progress charts see it — no double entry:
/// * meal → food-diary entry with the planned macros;
/// * workout → gym session with the planned sets × reps × kg;
/// * cardio → cardio session with the planned minutes / distance;
/// * sleep → last night at the planned times (skipped if a night is
///   already recorded, e.g. from Samsung Health).
///
/// Unticking removes exactly the record that ticking created. Records get
/// deterministic ids, so ticking twice never duplicates anything.
class TogglePlanItem {
  TogglePlanItem({
    required TransformationRepository plans,
    required NutritionRepository nutrition,
    required WorkoutRepository workouts,
    required SleepRepository sleep,
  }) : _plans = plans,
       _nutrition = nutrition,
       _workouts = workouts,
       _sleep = sleep;

  final TransformationRepository _plans;
  final NutritionRepository _nutrition;
  final WorkoutRepository _workouts;
  final SleepRepository _sleep;

  static String mealEntryId(String dayKey, PlanItem i) => '$dayKey#plan_${i.id}';
  static String sessionId(String dayKey, PlanItem i) => 'plan_${dayKey}_${i.id}';
  static String sleepId(String dayKey) => 'plan_sleep_$dayKey';

  /// Sets [item] on [day] to [done] and syncs the linked record.
  Future<void> call(TransformationPlan plan, PlanItem item, DateTime day, bool done) async {
    final dayKey = DateKeys.of(day);
    final at = _at(day, item.sortTime);
    switch (item.kind) {
      case PlanItemKind.meal:
        if (done) {
          await _nutrition.saveEntry(
            FoodLogEntry(
              id: mealEntryId(dayKey, item),
              dayKey: dayKey,
              slot: item.slot ?? MealSlotX.forTime(at),
              name: item.title,
              grams: 0,
              facts: item.facts ?? NutritionFacts.zero,
              source: EntrySource.plan,
              createdAt: at,
              query: item.detail.isEmpty ? null : item.detail,
            ),
          );
        } else {
          await _nutrition.deleteEntry(mealEntryId(dayKey, item));
        }
      case PlanItemKind.workout:
      case PlanItemKind.cardio:
        if (done) {
          await _workouts.save(sessionFor(item, day));
        } else {
          await _workouts.delete(sessionId(dayKey, item));
        }
      case PlanItemKind.sleep:
        if (done) {
          final bed = _at(
            plan.bedtimeMin >= 12 * 60 ? day.subtract(const Duration(days: 1)) : day,
            plan.bedtimeMin,
          );
          final wake = _at(day, plan.wakeMin);
          final existing = _sleep.sessionsEndingBetween(
            DateKeys.startOfDay(day),
            DateKeys.startOfDay(day).add(const Duration(days: 1)),
          );
          final recorded = existing.any((s) => s.id != sleepId(dayKey) && s.minutes >= 180);
          if (!recorded && wake.isAfter(bed)) {
            await _sleep.save(SleepSession(id: sleepId(dayKey), start: bed, end: wake));
          }
        } else {
          await _sleep.delete(sleepId(dayKey));
        }
      case PlanItemKind.supplement:
      case PlanItemKind.skincare:
      case PlanItemKind.habit:
        break;
    }
    await _plans.setCheck(dayKey, item.id, done);
  }

  /// The session a planned workout / cardio item becomes when ticked.
  static WorkoutSession sessionFor(PlanItem item, DateTime day) {
    final dayKey = DateKeys.of(day);
    final cardio = item.kind == PlanItemKind.cardio;
    final sets = [
      for (final e in item.exercises)
        for (var k = 0; k < e.sets; k++)
          WorkoutSet(
            exerciseId: e.exerciseId,
            exerciseName: e.name,
            muscle: e.muscle,
            reps: e.reps,
            weightKg: e.weightKg,
          ),
    ];
    return WorkoutSession(
      id: sessionId(dayKey, item),
      start: _at(day, item.sortTime),
      title: item.title,
      type: item.workoutType ?? (cardio ? WorkoutType.walk : WorkoutType.strength),
      durationMin: item.durationMin ?? (cardio ? 30 : (sets.length * 3 + 5).clamp(15, 180)),
      rpe: item.rpe ?? (cardio ? 3 : 7),
      sets: sets,
      distanceKm: item.distanceKm,
      source: DataSource.manual,
    );
  }

  static DateTime _at(DateTime day, int minutes) =>
      DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);
}
