import 'package:equatable/equatable.dart';

import '../../../../core/utils/date_utils.dart';
import '../../../nutrition/domain/entities/food_log_entry.dart';
import '../../../nutrition/domain/entities/nutrition_facts.dart';
import '../../../workout/domain/entities/exercise.dart';
import '../../../workout/domain/entities/workout_session.dart';

/// What a transformation works on (multi-select).
enum GoalArea { body, skin }

/// The body goal (single choice).
enum BodyGoal { fatLoss, weightGain, recomposition }

extension BodyGoalX on BodyGoal {
  String get label => switch (this) {
    BodyGoal.fatLoss => 'Fat loss',
    BodyGoal.weightGain => 'Weight gain',
    BodyGoal.recomposition => 'Recomposition',
  };

  /// Compact label for segmented buttons.
  String get shortLabel => switch (this) {
    BodyGoal.fatLoss => 'Fat loss',
    BodyGoal.weightGain => 'Gain',
    BodyGoal.recomposition => 'Recomp',
  };

  /// Whether the goal needs a starting body-fat %.
  bool get needsBodyFat => this != BodyGoal.weightGain;
}

/// Kind of a recurring plan item.
enum PlanItemKind { meal, workout, cardio, supplement, skincare, habit, sleep }

extension PlanItemKindX on PlanItemKind {
  String get label => switch (this) {
    PlanItemKind.meal => 'Meal',
    PlanItemKind.workout => 'Workout',
    PlanItemKind.cardio => 'Cardio',
    PlanItemKind.supplement => 'Supplement / medicine',
    PlanItemKind.skincare => 'Skincare',
    PlanItemKind.habit => 'Habit',
    PlanItemKind.sleep => 'Sleep',
  };

  /// Whether ticking this kind writes a real record (food, workout, sleep).
  bool get autoLogs => switch (this) {
    PlanItemKind.meal || PlanItemKind.workout || PlanItemKind.cardio || PlanItemKind.sleep => true,
    _ => false,
  };
}

/// Part of the day a skincare routine belongs to.
enum RoutineSlot { morning, afternoon, evening }

extension RoutineSlotX on RoutineSlot {
  String get label => switch (this) {
    RoutineSlot.morning => 'Morning',
    RoutineSlot.afternoon => 'Afternoon',
    RoutineSlot.evening => 'Evening',
  };

  /// Default time (minutes after midnight) when none is set.
  int get defaultTime => switch (this) {
    RoutineSlot.morning => 8 * 60,
    RoutineSlot.afternoon => 13 * 60,
    RoutineSlot.evening => 20 * 60,
  };
}

/// One exercise of a planned workout (sets × reps × kg).
class PlannedExercise extends Equatable {
  const PlannedExercise({
    required this.exerciseId,
    required this.name,
    required this.muscle,
    this.sets = 3,
    this.reps = 10,
    this.weightKg = 0,
  });

  final String exerciseId;
  final String name;
  final MuscleGroup muscle;
  final int sets;
  final int reps;
  final double weightKg;

  PlannedExercise copyWith({int? sets, int? reps, double? weightKg}) => PlannedExercise(
    exerciseId: exerciseId,
    name: name,
    muscle: muscle,
    sets: sets ?? this.sets,
    reps: reps ?? this.reps,
    weightKg: weightKg ?? this.weightKg,
  );

  @override
  List<Object?> get props => [exerciseId, name, muscle, sets, reps, weightKg];
}

/// A recurring thing the user plans to do (meal, workout, cardio session,
/// supplement, skincare routine, habit). It is shown on the matching days
/// as a checklist item; ticking it marks it done and, for meals, workouts,
/// cardio and sleep, logs the real record automatically.
class PlanItem extends Equatable {
  const PlanItem({
    required this.id,
    required this.kind,
    required this.title,
    this.detail = '',
    this.weekdays = const {},
    this.time,
    this.slot,
    this.facts,
    this.workoutType,
    this.durationMin,
    this.rpe,
    this.distanceKm,
    this.exercises = const [],
    this.routineSlot,
  });

  final String id;
  final PlanItemKind kind;
  final String title;

  /// Free text: foods of a meal, dose of a supplement, skincare steps…
  final String detail;

  /// ISO weekdays (1 = Monday … 7 = Sunday). Empty = every day.
  final Set<int> weekdays;

  /// Planned time in minutes after midnight (optional).
  final int? time;

  // Meal ─────────────────────────────────────────────────────────────
  final MealSlot? slot;
  final NutritionFacts? facts;

  // Workout & cardio ────────────────────────────────────────────────
  final WorkoutType? workoutType;
  final int? durationMin;
  final int? rpe;
  final double? distanceKm;
  final List<PlannedExercise> exercises;

  // Skincare ─────────────────────────────────────────────────────────
  final RoutineSlot? routineSlot;

  /// True if the item is scheduled on [d].
  bool occursOn(DateTime d) => weekdays.isEmpty || weekdays.contains(d.weekday);

  /// Effective time for ordering the checklist.
  int get sortTime =>
      time ??
      switch (kind) {
        PlanItemKind.meal => switch (slot) {
          MealSlot.breakfast => 8 * 60,
          MealSlot.lunch => 13 * 60,
          MealSlot.snacks => 17 * 60,
          MealSlot.dinner || null => 20 * 60,
        },
        PlanItemKind.skincare => (routineSlot ?? RoutineSlot.morning).defaultTime,
        PlanItemKind.sleep => 23 * 60,
        PlanItemKind.workout => 7 * 60,
        PlanItemKind.cardio => 18 * 60,
        _ => 12 * 60,
      };

  /// Human description of the days, e.g. "Every day" or "Mon · Wed · Fri".
  String get daysLabel {
    if (weekdays.isEmpty || weekdays.length == 7) return 'Every day';
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return [
      for (var d = 1; d <= 7; d++)
        if (weekdays.contains(d)) names[d - 1],
    ].join(' · ');
  }

  PlanItem copyWith({
    String? title,
    String? detail,
    Set<int>? weekdays,
    int? time,
    bool clearTime = false,
    MealSlot? slot,
    NutritionFacts? facts,
    WorkoutType? workoutType,
    int? durationMin,
    int? rpe,
    double? distanceKm,
    bool clearDistance = false,
    List<PlannedExercise>? exercises,
    RoutineSlot? routineSlot,
  }) => PlanItem(
    id: id,
    kind: kind,
    title: title ?? this.title,
    detail: detail ?? this.detail,
    weekdays: weekdays ?? this.weekdays,
    time: clearTime ? null : (time ?? this.time),
    slot: slot ?? this.slot,
    facts: facts ?? this.facts,
    workoutType: workoutType ?? this.workoutType,
    durationMin: durationMin ?? this.durationMin,
    rpe: rpe ?? this.rpe,
    distanceKm: clearDistance ? null : (distanceKm ?? this.distanceKm),
    exercises: exercises ?? this.exercises,
    routineSlot: routineSlot ?? this.routineSlot,
  );

  @override
  List<Object?> get props => [
    id,
    kind,
    title,
    detail,
    weekdays.toList()..sort(),
    time,
    slot,
    facts,
    workoutType,
    durationMin,
    rpe,
    distanceKm,
    exercises,
    routineSlot,
  ];
}

/// Daily nutrition goals of a plan.
class MacroGoals extends Equatable {
  const MacroGoals({
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.fiber,
    this.waterMl,
  });

  final double kcal;
  final double protein;
  final double carbs;
  final double fat;
  final double? fiber;
  final int? waterMl;

  @override
  List<Object?> get props => [kcal, protein, carbs, fat, fiber, waterMl];
}

/// A time-boxed transformation: goals, targets and a recurring plan.
///
/// The plan runs from [start] to [end] (both inclusive). While it is active
/// and Transformation mode is on, FiT opens on the plan's daily checklist.
class TransformationPlan extends Equatable {
  const TransformationPlan({
    required this.id,
    required this.name,
    required this.start,
    required this.end,
    required this.areas,
    required this.macros,
    this.bodyGoal,
    this.startWeightKg,
    this.startBodyFatPct,
    this.goalWeightKg,
    this.goalBodyFatPct,
    this.weeklyKcalStep = 0,
    this.stepsGoal,
    this.cardioMinutesGoal,
    this.sleepHours = 8,
    this.bedtimeMin = 23 * 60,
    this.wakeMin = 7 * 60,
    this.items = const [],
    this.notes = '',
  });

  final String id;
  final String name;

  /// First and last day (dates only).
  final DateTime start;
  final DateTime end;
  final Set<GoalArea> areas;

  final BodyGoal? bodyGoal;
  final double? startWeightKg;
  final double? startBodyFatPct;
  final double? goalWeightKg;
  final double? goalBodyFatPct;

  final MacroGoals macros;

  /// Calories added (or removed) each week of the plan, e.g. +50 kcal/week
  /// for a reverse-diet style ramp.
  final double weeklyKcalStep;

  final int? stepsGoal;

  /// Planned cardio minutes per day.
  final int? cardioMinutesGoal;

  final double sleepHours;

  /// Planned lights-out and wake-up, minutes after midnight.
  final int bedtimeMin;
  final int wakeMin;

  final List<PlanItem> items;
  final String notes;

  bool get hasBody => areas.contains(GoalArea.body);
  bool get hasSkin => areas.contains(GoalArea.skin);

  /// Number of days in the plan.
  int get totalDays => DateKeys.startOfDay(end).difference(DateKeys.startOfDay(start)).inDays + 1;

  /// 1-based day number of [d] (may be ≤ 0 before the start).
  int dayNumber(DateTime d) => DateKeys.startOfDay(d).difference(DateKeys.startOfDay(start)).inDays + 1;

  /// True if [d] lies within the plan.
  bool contains(DateTime d) {
    final n = dayNumber(d);
    return n >= 1 && n <= totalDays;
  }

  /// True once [now] is past the last day.
  bool isFinished(DateTime now) => dayNumber(now) > totalDays;

  /// Calorie target on [d], including the weekly step.
  double kcalOn(DateTime d) {
    final week = ((dayNumber(d) - 1).clamp(0, totalDays) ~/ 7);
    return macros.kcal + weeklyKcalStep * week;
  }

  /// The synthetic daily "slept as planned" item.
  PlanItem get sleepItem => PlanItem(
    id: 'sleep',
    kind: PlanItemKind.sleep,
    title: 'Sleep ${sleepHours.toStringAsFixed(sleepHours % 1 == 0 ? 0 : 1)} h',
    detail: 'Lights out ${clockOf(bedtimeMin)} · wake ${clockOf(wakeMin)}',
    time: wakeMin,
  );

  /// Checklist of [d], ordered by time. Skincare only when the skin goal
  /// is selected; sleep (last night) always first.
  List<PlanItem> itemsFor(DateTime d) {
    if (!contains(d)) return const [];
    final list = [
      for (final i in items)
        if (i.occursOn(d) && (i.kind != PlanItemKind.skincare || hasSkin)) i,
    ]..sort((a, b) => a.sortTime.compareTo(b.sortTime));
    return [sleepItem, ...list];
  }

  /// Workouts planned on [d] (none → rest day).
  List<PlanItem> workoutsOn(DateTime d) => [
    for (final i in items)
      if (i.kind == PlanItemKind.workout && i.occursOn(d)) i,
  ];

  bool isRestDay(DateTime d) => workoutsOn(d).isEmpty;

  /// Sum of the planned meals on [d].
  NutritionFacts plannedIntake(DateTime d) => items
      .where((i) => i.kind == PlanItemKind.meal && i.occursOn(d) && i.facts != null)
      .fold(NutritionFacts.zero, (a, i) => a + i.facts!);

  /// Planned weight on [d], linear from start to goal.
  double? plannedWeightOn(DateTime d) {
    if (startWeightKg == null || goalWeightKg == null) return null;
    final t = ((dayNumber(d) - 1) / (totalDays - 1).clamp(1, 100000)).clamp(0.0, 1.0);
    return startWeightKg! + (goalWeightKg! - startWeightKg!) * t;
  }

  /// "HH:mm" for minutes after midnight.
  static String clockOf(int minutes) {
    final m = minutes % (24 * 60);
    return '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
  }

  TransformationPlan copyWith({
    String? name,
    DateTime? start,
    DateTime? end,
    Set<GoalArea>? areas,
    BodyGoal? bodyGoal,
    double? startWeightKg,
    double? startBodyFatPct,
    double? goalWeightKg,
    double? goalBodyFatPct,
    bool clearBodyFat = false,
    bool clearGoalBodyFat = false,
    MacroGoals? macros,
    double? weeklyKcalStep,
    int? stepsGoal,
    int? cardioMinutesGoal,
    double? sleepHours,
    int? bedtimeMin,
    int? wakeMin,
    List<PlanItem>? items,
    String? notes,
  }) => TransformationPlan(
    id: id,
    name: name ?? this.name,
    start: start ?? this.start,
    end: end ?? this.end,
    areas: areas ?? this.areas,
    bodyGoal: bodyGoal ?? this.bodyGoal,
    startWeightKg: startWeightKg ?? this.startWeightKg,
    startBodyFatPct: clearBodyFat ? null : (startBodyFatPct ?? this.startBodyFatPct),
    goalWeightKg: goalWeightKg ?? this.goalWeightKg,
    goalBodyFatPct: clearGoalBodyFat ? null : (goalBodyFatPct ?? this.goalBodyFatPct),
    macros: macros ?? this.macros,
    weeklyKcalStep: weeklyKcalStep ?? this.weeklyKcalStep,
    stepsGoal: stepsGoal ?? this.stepsGoal,
    cardioMinutesGoal: cardioMinutesGoal ?? this.cardioMinutesGoal,
    sleepHours: sleepHours ?? this.sleepHours,
    bedtimeMin: bedtimeMin ?? this.bedtimeMin,
    wakeMin: wakeMin ?? this.wakeMin,
    items: items ?? this.items,
    notes: notes ?? this.notes,
  );

  /// Problems that block saving (empty = valid).
  List<String> validate() {
    final errors = <String>[];
    if (name.trim().isEmpty) errors.add('Give the transformation a name.');
    if (areas.isEmpty) errors.add('Choose at least one goal (Body or Skin).');
    if (!end.isAfter(start)) errors.add('The end date must be after the start date.');
    if (hasBody) {
      if (bodyGoal == null) errors.add('Choose a body goal.');
      if (startWeightKg == null) errors.add('Enter your starting body weight.');
      if (goalWeightKg == null) errors.add('Enter your goal weight.');
      if (bodyGoal != null && bodyGoal!.needsBodyFat && startBodyFatPct == null) {
        errors.add('Enter your starting body-fat %.');
      }
      if (bodyGoal == BodyGoal.fatLoss &&
          startWeightKg != null &&
          goalWeightKg != null &&
          goalWeightKg! >= startWeightKg!) {
        errors.add('For fat loss the goal weight must be below the starting weight.');
      }
      if (bodyGoal == BodyGoal.weightGain &&
          startWeightKg != null &&
          goalWeightKg != null &&
          goalWeightKg! <= startWeightKg!) {
        errors.add('For weight gain the goal weight must be above the starting weight.');
      }
    }
    if (hasBody && macros.kcal < 800) errors.add('Set a daily calorie goal (at least 800 kcal).');
    return errors;
  }

  @override
  List<Object?> get props => [
    id,
    name,
    start,
    end,
    areas.toList()..sort((a, b) => a.index.compareTo(b.index)),
    bodyGoal,
    startWeightKg,
    startBodyFatPct,
    goalWeightKg,
    goalBodyFatPct,
    macros,
    weeklyKcalStep,
    stepsGoal,
    cardioMinutesGoal,
    sleepHours,
    bedtimeMin,
    wakeMin,
    items,
    notes,
  ];
}
