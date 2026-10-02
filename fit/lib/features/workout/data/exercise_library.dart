import '../domain/entities/exercise.dart';

/// Built-in exercise library (≈ 60 common gym movements).
///
/// Add an exercise by appending one `_e(...)` line; ids must stay stable
/// because they are stored in logged sets.
class ExerciseLibrary {
  ExerciseLibrary._();

  static Exercise _e(
    String id,
    String name,
    MuscleGroup m, [
    String equipment = 'Barbell',
    bool compound = false,
  ]) => Exercise(id: 'ex_$id', name: name, muscle: m, equipment: equipment, compound: compound);

  static final List<Exercise> all = [
    // Chest
    _e('bench', 'Bench press', MuscleGroup.chest, 'Barbell', true),
    _e('incline_bench', 'Incline bench press', MuscleGroup.chest, 'Barbell', true),
    _e('db_bench', 'Dumbbell bench press', MuscleGroup.chest, 'Dumbbell', true),
    _e('incline_db', 'Incline dumbbell press', MuscleGroup.chest, 'Dumbbell', true),
    _e('pushup', 'Push-up', MuscleGroup.chest, 'Bodyweight', true),
    _e('dips', 'Dips', MuscleGroup.chest, 'Bodyweight', true),
    _e('cable_fly', 'Cable fly', MuscleGroup.chest, 'Cable'),
    _e('pec_deck', 'Pec deck', MuscleGroup.chest, 'Machine'),
    // Back
    _e('deadlift', 'Deadlift', MuscleGroup.back, 'Barbell', true),
    _e('pullup', 'Pull-up', MuscleGroup.back, 'Bodyweight', true),
    _e('chinup', 'Chin-up', MuscleGroup.back, 'Bodyweight', true),
    _e('lat_pulldown', 'Lat pulldown', MuscleGroup.back, 'Cable', true),
    _e('bb_row', 'Barbell row', MuscleGroup.back, 'Barbell', true),
    _e('db_row', 'Dumbbell row', MuscleGroup.back, 'Dumbbell', true),
    _e('seated_row', 'Seated cable row', MuscleGroup.back, 'Cable', true),
    _e('tbar_row', 'T-bar row', MuscleGroup.back, 'Barbell', true),
    _e('face_pull', 'Face pull', MuscleGroup.back, 'Cable'),
    _e('shrug', 'Shrug', MuscleGroup.back, 'Dumbbell'),
    // Shoulders
    _e('ohp', 'Overhead press', MuscleGroup.shoulders, 'Barbell', true),
    _e('db_ohp', 'Dumbbell shoulder press', MuscleGroup.shoulders, 'Dumbbell', true),
    _e('lateral_raise', 'Lateral raise', MuscleGroup.shoulders, 'Dumbbell'),
    _e('front_raise', 'Front raise', MuscleGroup.shoulders, 'Dumbbell'),
    _e('rear_delt', 'Rear delt fly', MuscleGroup.shoulders, 'Dumbbell'),
    _e('arnold', 'Arnold press', MuscleGroup.shoulders, 'Dumbbell', true),
    // Arms
    _e('bb_curl', 'Barbell curl', MuscleGroup.arms),
    _e('db_curl', 'Dumbbell curl', MuscleGroup.arms, 'Dumbbell'),
    _e('hammer_curl', 'Hammer curl', MuscleGroup.arms, 'Dumbbell'),
    _e('preacher', 'Preacher curl', MuscleGroup.arms, 'Machine'),
    _e('tricep_pushdown', 'Triceps pushdown', MuscleGroup.arms, 'Cable'),
    _e('skullcrusher', 'Skull crusher', MuscleGroup.arms),
    _e('overhead_ext', 'Overhead triceps extension', MuscleGroup.arms, 'Dumbbell'),
    _e('cgbp', 'Close-grip bench press', MuscleGroup.arms, 'Barbell', true),
    // Legs
    _e('squat', 'Back squat', MuscleGroup.legs, 'Barbell', true),
    _e('front_squat', 'Front squat', MuscleGroup.legs, 'Barbell', true),
    _e('leg_press', 'Leg press', MuscleGroup.legs, 'Machine', true),
    _e('lunge', 'Walking lunge', MuscleGroup.legs, 'Dumbbell', true),
    _e('bulgarian', 'Bulgarian split squat', MuscleGroup.legs, 'Dumbbell', true),
    _e('goblet', 'Goblet squat', MuscleGroup.legs, 'Dumbbell', true),
    _e('leg_ext', 'Leg extension', MuscleGroup.legs, 'Machine'),
    _e('leg_curl', 'Leg curl', MuscleGroup.legs, 'Machine'),
    _e('calf_raise', 'Calf raise', MuscleGroup.legs, 'Machine'),
    // Glutes / posterior chain
    _e('rdl', 'Romanian deadlift', MuscleGroup.glutes, 'Barbell', true),
    _e('hip_thrust', 'Hip thrust', MuscleGroup.glutes, 'Barbell', true),
    _e('glute_bridge', 'Glute bridge', MuscleGroup.glutes, 'Bodyweight'),
    _e('kb_swing', 'Kettlebell swing', MuscleGroup.glutes, 'Kettlebell', true),
    _e('cable_kickback', 'Cable kickback', MuscleGroup.glutes, 'Cable'),
    // Core
    _e('plank', 'Plank (sets × 30 s)', MuscleGroup.core, 'Bodyweight'),
    _e('crunch', 'Crunch', MuscleGroup.core, 'Bodyweight'),
    _e('hanging_leg', 'Hanging leg raise', MuscleGroup.core, 'Bodyweight'),
    _e('cable_crunch', 'Cable crunch', MuscleGroup.core, 'Cable'),
    _e('russian_twist', 'Russian twist', MuscleGroup.core, 'Bodyweight'),
    _e('ab_wheel', 'Ab wheel rollout', MuscleGroup.core, 'Bodyweight'),
    // Full body
    _e('clean', 'Power clean', MuscleGroup.fullBody, 'Barbell', true),
    _e('thruster', 'Thruster', MuscleGroup.fullBody, 'Barbell', true),
    _e('burpee', 'Burpee', MuscleGroup.fullBody, 'Bodyweight', true),
    _e('farmer', "Farmer's carry", MuscleGroup.fullBody, 'Dumbbell', true),
  ];

  static final Map<String, Exercise> _byId = {for (final e in all) e.id: e};

  /// Looks up an exercise by id.
  static Exercise? byId(String id) => _byId[id];
}
