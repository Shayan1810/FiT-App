import 'dart:convert';

import '../../../core/utils/id_generator.dart';
import '../../nutrition/domain/entities/food_log_entry.dart';
import '../../nutrition/domain/entities/nutrition_facts.dart';
import '../../workout/domain/entities/exercise.dart';
import '../../workout/domain/entities/workout_session.dart';
import '../domain/entities/transformation_plan.dart';

/// [TransformationPlan] ↔ JSON-compatible map. Used for Hive storage and
/// for the human-readable import / export format (`"format": "fit-plan"`).
class PlanCodec {
  PlanCodec._();

  static const String format = 'fit-plan';
  static const int version = 1;

  static T? _enum<T extends Enum>(List<T> values, Object? name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }

  static double? _d(Object? v) => (v as num?)?.toDouble();
  static int? _i(Object? v) => (v as num?)?.toInt();

  /// Dates are stored as `yyyy-MM-dd` so files stay readable.
  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  static DateTime _parseDate(Object? v) {
    final s = v as String;
    final p = s.split('-').map(int.parse).toList();
    return DateTime(p[0], p[1], p[2]);
  }

  /// "HH:mm" ↔ minutes after midnight.
  static String? _time(int? m) => m == null ? null : TransformationPlan.clockOf(m);
  static int? _parseTime(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toInt();
    final p = (v as String).split(':').map(int.parse).toList();
    return p[0] * 60 + (p.length > 1 ? p[1] : 0);
  }

  static Map<String, dynamic> factsToMap(NutritionFacts f) => {
    'kcal': f.kcal,
    'protein': f.protein,
    'carbs': f.carbs,
    'fat': f.fat,
    if (f.fiber > 0) 'fiber': f.fiber,
  };

  static NutritionFacts factsFromMap(Map<String, dynamic> m) => NutritionFacts(
    kcal: _d(m['kcal']) ?? 0,
    protein: _d(m['protein']) ?? 0,
    carbs: _d(m['carbs']) ?? 0,
    fat: _d(m['fat']) ?? 0,
    fiber: _d(m['fiber']) ?? 0,
  );

  static Map<String, dynamic> itemToMap(PlanItem i) => {
    'id': i.id,
    'kind': i.kind.name,
    'title': i.title,
    if (i.detail.isNotEmpty) 'detail': i.detail,
    if (i.weekdays.isNotEmpty) 'weekdays': (i.weekdays.toList()..sort()),
    if (i.time != null) 'time': _time(i.time),
    if (i.slot != null) 'slot': i.slot!.name,
    if (i.facts != null) 'facts': factsToMap(i.facts!),
    if (i.workoutType != null) 'workoutType': i.workoutType!.name,
    if (i.durationMin != null) 'durationMin': i.durationMin,
    if (i.rpe != null) 'rpe': i.rpe,
    if (i.distanceKm != null) 'distanceKm': i.distanceKm,
    if (i.exercises.isNotEmpty)
      'exercises': [
        for (final e in i.exercises)
          {
            'exerciseId': e.exerciseId,
            'name': e.name,
            'muscle': e.muscle.name,
            'sets': e.sets,
            'reps': e.reps,
            'weightKg': e.weightKg,
          },
      ],
    if (i.routineSlot != null) 'routineSlot': i.routineSlot!.name,
  };

  static PlanItem itemFromMap(Map<String, dynamic> m) {
    final kind = _enum(PlanItemKind.values, m['kind']);
    if (kind == null) throw FormatException('Unknown item kind "${m['kind']}"');
    return PlanItem(
      id: (m['id'] as String?) ?? 'item_${IdGenerator.next()}',
      kind: kind,
      title: (m['title'] as String?)?.trim() ?? kind.label,
      detail: (m['detail'] as String?) ?? '',
      weekdays: {for (final d in (m['weekdays'] as List? ?? const [])) (d as num).toInt()},
      time: _parseTime(m['time']),
      slot: _enum(MealSlot.values, m['slot']),
      facts: m['facts'] == null ? null : factsFromMap(Map<String, dynamic>.from(m['facts'] as Map)),
      workoutType: _enum(WorkoutType.values, m['workoutType']),
      durationMin: _i(m['durationMin']),
      rpe: _i(m['rpe']),
      distanceKm: _d(m['distanceKm']),
      exercises: [
        for (final e in (m['exercises'] as List? ?? const []))
          PlannedExercise(
            exerciseId: (e as Map)['exerciseId'] as String? ?? 'cx_${IdGenerator.next()}',
            name: e['name'] as String,
            muscle: _enum(MuscleGroup.values, e['muscle']) ?? MuscleGroup.fullBody,
            sets: _i(e['sets']) ?? 3,
            reps: _i(e['reps']) ?? 10,
            weightKg: _d(e['weightKg']) ?? 0,
          ),
      ],
      routineSlot: _enum(RoutineSlot.values, m['routineSlot']),
    );
  }

  static Map<String, dynamic> toMap(TransformationPlan p) => {
    'format': format,
    'version': version,
    'id': p.id,
    'name': p.name,
    'start': _date(p.start),
    'end': _date(p.end),
    'areas': [for (final a in p.areas) a.name],
    if (p.bodyGoal != null) 'bodyGoal': p.bodyGoal!.name,
    if (p.startWeightKg != null) 'startWeightKg': p.startWeightKg,
    if (p.startBodyFatPct != null) 'startBodyFatPct': p.startBodyFatPct,
    if (p.goalWeightKg != null) 'goalWeightKg': p.goalWeightKg,
    if (p.goalBodyFatPct != null) 'goalBodyFatPct': p.goalBodyFatPct,
    'macros': {
      'kcal': p.macros.kcal,
      'protein': p.macros.protein,
      'carbs': p.macros.carbs,
      'fat': p.macros.fat,
      if (p.macros.fiber != null) 'fiber': p.macros.fiber,
      if (p.macros.waterMl != null) 'waterMl': p.macros.waterMl,
    },
    if (p.weeklyKcalStep != 0) 'weeklyKcalStep': p.weeklyKcalStep,
    if (p.stepsGoal != null) 'stepsGoal': p.stepsGoal,
    if (p.cardioMinutesGoal != null) 'cardioMinutesGoal': p.cardioMinutesGoal,
    'sleep': {'hours': p.sleepHours, 'bedtime': _time(p.bedtimeMin), 'wake': _time(p.wakeMin)},
    'items': [for (final i in p.items) itemToMap(i)],
    if (p.notes.isNotEmpty) 'notes': p.notes,
  };

  static TransformationPlan fromMap(Map<String, dynamic> m) {
    final macros = Map<String, dynamic>.from(m['macros'] as Map? ?? const {});
    final sleep = Map<String, dynamic>.from(m['sleep'] as Map? ?? const {});
    return TransformationPlan(
      id: (m['id'] as String?) ?? 'plan_${IdGenerator.next()}',
      name: (m['name'] as String?) ?? 'My transformation',
      start: _parseDate(m['start']),
      end: _parseDate(m['end']),
      areas: {
        for (final a in (m['areas'] as List? ?? const ['body']))
          if (_enum(GoalArea.values, a) != null) _enum(GoalArea.values, a)!,
      },
      bodyGoal: _enum(BodyGoal.values, m['bodyGoal']),
      startWeightKg: _d(m['startWeightKg']),
      startBodyFatPct: _d(m['startBodyFatPct']),
      goalWeightKg: _d(m['goalWeightKg']),
      goalBodyFatPct: _d(m['goalBodyFatPct']),
      macros: MacroGoals(
        kcal: _d(macros['kcal']) ?? 2000,
        protein: _d(macros['protein']) ?? 120,
        carbs: _d(macros['carbs']) ?? 200,
        fat: _d(macros['fat']) ?? 60,
        fiber: _d(macros['fiber']),
        waterMl: _i(macros['waterMl']),
      ),
      weeklyKcalStep: _d(m['weeklyKcalStep']) ?? 0,
      stepsGoal: _i(m['stepsGoal']),
      cardioMinutesGoal: _i(m['cardioMinutesGoal']),
      sleepHours: _d(sleep['hours']) ?? 8,
      bedtimeMin: _parseTime(sleep['bedtime']) ?? 23 * 60,
      wakeMin: _parseTime(sleep['wake']) ?? 7 * 60,
      items: [
        for (final i in (m['items'] as List? ?? const [])) itemFromMap(Map<String, dynamic>.from(i as Map)),
      ],
      notes: (m['notes'] as String?) ?? '',
    );
  }

  /// Pretty JSON for export.
  static String encode(TransformationPlan p) => const JsonEncoder.withIndent('  ').convert(toMap(p));

  /// Parses exported JSON; throws [FormatException] with a readable message.
  static TransformationPlan decode(String json) {
    final Object? raw;
    try {
      raw = jsonDecode(json.trim());
    } on FormatException {
      throw const FormatException('This is not valid JSON.');
    }
    if (raw is! Map || raw['format'] != format) {
      throw const FormatException('This is not a FiT plan file.');
    }
    try {
      return fromMap(Map<String, dynamic>.from(raw));
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('The plan file is incomplete: $e');
    }
  }
}
