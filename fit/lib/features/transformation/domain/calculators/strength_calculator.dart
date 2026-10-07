import 'dart:math';

import '../../../insights/domain/calculators/training_load_calculator.dart';
import '../../../workout/domain/entities/workout_session.dart';
import '../entities/transformation_plan.dart';

/// What was lifted for one exercise in one session.
class ExercisePerformance {
  const ExercisePerformance({required this.date, required this.sets});

  final DateTime date;

  /// Working sets in order (reps, kg).
  final List<(int reps, double kg)> sets;

  /// Heaviest weight used.
  double get topKg => sets.map((s) => s.$2).fold(0.0, max);

  /// Best estimated 1RM (Epley) from sets of ≤ 12 reps.
  double get e1rm => sets
      .where((s) => s.$1 > 0 && s.$1 <= 12 && s.$2 > 0)
      .map((s) => TrainingLoadCalculator.epley1Rm(s.$2, s.$1))
      .fold(0.0, max);

  /// Σ reps × kg.
  double get volume => sets.fold(0.0, (a, s) => a + s.$1 * s.$2);
}

/// Strength change of one exercise over a period.
class StrengthChange {
  const StrengthChange({
    required this.exerciseId,
    required this.name,
    required this.first,
    required this.latest,
    required this.sessions,
  });

  final String exerciseId;
  final String name;
  final ExercisePerformance first;
  final ExercisePerformance latest;
  final int sessions;

  /// Change of estimated 1RM in % (null when not comparable, e.g. bodyweight).
  double? get e1rmChangePct =>
      first.e1rm <= 0 || latest.e1rm <= 0 ? null : (latest.e1rm / first.e1rm - 1) * 100;

  /// Change of the top working weight in kg.
  double get topKgChange => latest.topKg - first.topKg;

  /// Change of the best set's reps (useful for bodyweight moves).
  int get repsChange => latest.sets.map((s) => s.$1).fold(0, max) - first.sets.map((s) => s.$1).fold(0, max);
}

/// Next-session target for a planned exercise.
class OverloadSuggestion {
  const OverloadSuggestion({
    required this.exercise,
    required this.kg,
    required this.reps,
    required this.sets,
    required this.reason,
    this.last,
  });

  final PlannedExercise exercise;
  final double kg;
  final int reps;
  final int sets;

  /// Plain-language reason ("All 4×8 done last time → +2.5 kg").
  final String reason;
  final ExercisePerformance? last;

  bool get isIncrease => last != null && kg > last!.topKg;
}

/// Strength tracking and double-progression advice.
///
/// * Progressive overload: increase the load 2–10 % once the target
///   repetitions are completed for all sets (ACSM 2009 position stand;
///   "double progression": first add reps, then weight).
/// * Estimated 1RM via Epley (sets of ≤ 12 reps).
class StrengthCalculator {
  StrengthCalculator._();

  /// Performances of [exerciseId] in [sessions], oldest first.
  static List<ExercisePerformance> history(Iterable<WorkoutSession> sessions, String exerciseId) {
    final out = <ExercisePerformance>[];
    for (final s in sessions.toList()..sort((a, b) => a.start.compareTo(b.start))) {
      final sets = [
        for (final set in s.sets)
          if (set.exerciseId == exerciseId) (set.reps, set.weightKg),
      ];
      if (sets.isNotEmpty) out.add(ExercisePerformance(date: s.start, sets: sets));
    }
    return out;
  }

  /// Strength change for every exercise trained in [sessions] (≥ 1 session),
  /// biggest improvement first.
  static List<StrengthChange> changes(Iterable<WorkoutSession> sessions) {
    final names = <String, String>{};
    for (final s in sessions) {
      for (final set in s.sets) {
        names[set.exerciseId] = set.exerciseName;
      }
    }
    final out = <StrengthChange>[];
    names.forEach((id, name) {
      final h = history(sessions, id);
      if (h.isEmpty) return;
      out.add(StrengthChange(exerciseId: id, name: name, first: h.first, latest: h.last, sessions: h.length));
    });
    out.sort((a, b) {
      final x = a.e1rmChangePct ?? a.repsChange.toDouble();
      final y = b.e1rmChangePct ?? b.repsChange.toDouble();
      final c = y.compareTo(x);
      return c != 0 ? c : b.sessions.compareTo(a.sessions);
    });
    return out;
  }

  /// Load increment for an exercise: 2.5 kg for barbell / machine loads of
  /// 20 kg or more, otherwise 1 kg (dumbbells, light cables).
  static double increment(double kg) => kg >= 20 ? 2.5 : 1.0;

  /// Rounds to the nearest 0.5 kg.
  static double _round(double kg) => (kg * 2).round() / 2;

  /// Suggests the next session for [e] from its history (newest last).
  static OverloadSuggestion suggest(PlannedExercise e, List<ExercisePerformance> history) {
    if (history.isEmpty) {
      return OverloadSuggestion(
        exercise: e,
        kg: e.weightKg,
        reps: e.reps,
        sets: e.sets,
        reason: 'First session: start with the planned ${_fmt(e.weightKg)} kg.',
      );
    }
    final last = history.last;
    final top = last.topKg;
    final working = last.sets.where((s) => s.$2 >= top - 0.01).toList();
    final allReps = working.length >= e.sets && working.every((s) => s.$1 >= e.reps);
    if (top <= 0) {
      // Bodyweight: progress reps.
      final best = last.sets.map((s) => s.$1).fold(0, max);
      return OverloadSuggestion(
        exercise: e,
        kg: 0,
        reps: allReps ? best + 1 : max(best, e.reps),
        sets: e.sets,
        last: last,
        reason: allReps
            ? 'All reps done last time: add 1 rep per set.'
            : 'Repeat last time and aim for every rep.',
      );
    }
    if (allReps) {
      final next = _round(top + increment(top));
      return OverloadSuggestion(
        exercise: e,
        kg: next,
        reps: e.reps,
        sets: e.sets,
        last: last,
        reason: 'All ${e.sets}×${e.reps} done at ${_fmt(top)} kg last time: go to ${_fmt(next)} kg.',
      );
    }
    final best = working.isEmpty ? 0 : working.map((s) => s.$1).reduce(max);
    if (working.length < e.sets && working.every((s) => s.$1 >= e.reps)) {
      return OverloadSuggestion(
        exercise: e,
        kg: top,
        reps: e.reps,
        sets: e.sets,
        last: last,
        reason: 'Last time ${working.length} of ${e.sets} sets at ${_fmt(top)} kg: do all ${e.sets}, then add weight.',
      );
    }
    return OverloadSuggestion(
      exercise: e,
      kg: top,
      reps: e.reps,
      sets: e.sets,
      last: last,
      reason: 'Stay at ${_fmt(top)} kg until you get ${e.sets}×${e.reps} (best last time: $best reps).',
    );
  }

  static String _fmt(double kg) => kg % 1 == 0 ? kg.toStringAsFixed(0) : kg.toStringAsFixed(1);
}
