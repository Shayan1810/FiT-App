import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/exercise.dart';
import '../../domain/entities/workout_session.dart';
import '../../domain/repositories/workout_repository.dart';

/// Base class of workout events.
sealed class WorkoutEvent {
  const WorkoutEvent();
}

/// Load sessions and start watching storage.
class WorkoutsStarted extends WorkoutEvent {
  const WorkoutsStarted();
}

/// Create or update a session.
class WorkoutSaved extends WorkoutEvent {
  const WorkoutSaved(this.session);
  final WorkoutSession session;
}

/// Delete a session.
class WorkoutDeleted extends WorkoutEvent {
  const WorkoutDeleted(this.id);
  final String id;
}

/// Create or update a custom exercise.
class ExerciseSaved extends WorkoutEvent {
  const ExerciseSaved(this.exercise);
  final Exercise exercise;
}

/// Delete a custom exercise.
class ExerciseDeleted extends WorkoutEvent {
  const ExerciseDeleted(this.id);
  final String id;
}

class _WorkoutsChanged extends WorkoutEvent {
  const _WorkoutsChanged();
}

/// Sessions (newest first) and the exercise library.
class WorkoutState extends Equatable {
  const WorkoutState({this.sessions = const [], this.exercises = const []});

  /// Newest first.
  final List<WorkoutSession> sessions;
  final List<Exercise> exercises;

  @override
  List<Object?> get props => [sessions, exercises];
}

/// Workout history + exercise library.
class WorkoutBloc extends Bloc<WorkoutEvent, WorkoutState> {
  WorkoutBloc(this._repo) : super(const WorkoutState()) {
    on<WorkoutsStarted>((e, emit) {
      _sub ??= _repo.watch().listen((_) => add(const _WorkoutsChanged()));
      _emit(emit);
    });
    on<_WorkoutsChanged>((e, emit) => _emit(emit));
    on<WorkoutSaved>((e, emit) => _repo.save(e.session));
    on<WorkoutDeleted>((e, emit) => _repo.delete(e.id));
    on<ExerciseSaved>((e, emit) => _repo.saveExercise(e.exercise));
    on<ExerciseDeleted>((e, emit) => _repo.deleteExercise(e.id));
  }

  final WorkoutRepository _repo;
  StreamSubscription<void>? _sub;

  void _emit(Emitter<WorkoutState> emit) =>
      emit(WorkoutState(sessions: _repo.sessions(), exercises: _repo.exercises()));

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
