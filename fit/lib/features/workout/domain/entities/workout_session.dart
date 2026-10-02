import 'package:equatable/equatable.dart';

import '../../../../core/domain/data_source.dart';
import 'exercise.dart';

/// Broad kind of session; selects the MET value used for energy.
enum WorkoutType { strength, cardio, hiit, sport, mobility, walk, run }

/// Display label for [WorkoutType].
extension WorkoutTypeX on WorkoutType {
  String get label => switch (this) {
    WorkoutType.strength => 'Strength',
    WorkoutType.cardio => 'Cardio',
    WorkoutType.hiit => 'HIIT',
    WorkoutType.sport => 'Sport',
    WorkoutType.mobility => 'Mobility',
    WorkoutType.walk => 'Walk',
    WorkoutType.run => 'Run',
  };
}

/// One performed set.
class WorkoutSet extends Equatable {
  const WorkoutSet({
    required this.exerciseId,
    required this.exerciseName,
    required this.muscle,
    required this.reps,
    required this.weightKg,
  });

  final String exerciseId;
  final String exerciseName;
  final MuscleGroup muscle;
  final int reps;
  final double weightKg;

  /// Volume load of this set: reps × kg.
  double get volume => reps * weightKg;

  @override
  List<Object?> get props => [exerciseId, exerciseName, muscle, reps, weightKg];
}

/// A gym or cardio session.
class WorkoutSession extends Equatable {
  const WorkoutSession({
    required this.id,
    required this.start,
    required this.title,
    required this.type,
    required this.durationMin,
    required this.rpe,
    this.sets = const [],
    this.deviceKcal,
    this.distanceKm,
    this.source = DataSource.manual,
  });

  final String id;
  final DateTime start;
  final String title;
  final WorkoutType type;
  final int durationMin;

  /// Session rating of perceived exertion, Borg CR-10 (1–10).
  final int rpe;
  final List<WorkoutSet> sets;

  /// Energy reported by a wearable (Health Connect), if any.
  final double? deviceKcal;
  final double? distanceKm;
  final DataSource source;

  /// Foster session-RPE training load in arbitrary units: RPE × minutes.
  double get load => rpe * durationMin.toDouble();

  /// Total volume load (Σ reps × kg).
  double get volume => sets.fold(0.0, (a, s) => a + s.volume);

  @override
  List<Object?> get props => [id, start, title, type, durationMin, rpe, sets, deviceKcal, distanceKm, source];
}
