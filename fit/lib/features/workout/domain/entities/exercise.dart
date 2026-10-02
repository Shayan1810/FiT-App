import 'package:equatable/equatable.dart';

/// Muscle groups used for weekly-volume tracking.
enum MuscleGroup { chest, back, shoulders, arms, legs, glutes, core, fullBody, cardio }

/// Labels and recovery windows for [MuscleGroup].
extension MuscleGroupX on MuscleGroup {
  String get label => switch (this) {
    MuscleGroup.chest => 'Chest',
    MuscleGroup.back => 'Back',
    MuscleGroup.shoulders => 'Shoulders',
    MuscleGroup.arms => 'Arms',
    MuscleGroup.legs => 'Legs',
    MuscleGroup.glutes => 'Glutes',
    MuscleGroup.core => 'Core',
    MuscleGroup.fullBody => 'Full body',
    MuscleGroup.cardio => 'Cardio',
  };

  /// Hours a muscle group typically needs between hard sessions.
  /// Larger groups / heavier compound work → longer (48–72 h guideline).
  int get recoveryHours => switch (this) {
    MuscleGroup.legs || MuscleGroup.back || MuscleGroup.glutes || MuscleGroup.fullBody => 72,
    MuscleGroup.chest || MuscleGroup.shoulders => 48,
    MuscleGroup.arms || MuscleGroup.core => 36,
    MuscleGroup.cardio => 24,
  };
}

/// An exercise from the built-in library.
class Exercise extends Equatable {
  const Exercise({
    required this.id,
    required this.name,
    required this.muscle,
    this.equipment = 'Barbell',
    this.compound = false,
    this.custom = false,
  });

  final String id;
  final String name;
  final MuscleGroup muscle;
  final String equipment;

  /// Multi-joint lift (squat, bench…) vs isolation (curl, raise…).
  final bool compound;

  /// Created by the user (editable / deletable).
  final bool custom;

  @override
  List<Object?> get props => [id, name, muscle, equipment, compound, custom];
}
