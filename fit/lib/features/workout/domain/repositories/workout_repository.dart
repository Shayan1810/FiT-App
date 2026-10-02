import '../entities/exercise.dart';
import '../entities/workout_session.dart';

/// Gym / cardio sessions and the exercise library.
abstract class WorkoutRepository {
  /// All sessions, newest first.
  List<WorkoutSession> sessions();

  /// Sessions whose start falls in [from, to).
  List<WorkoutSession> sessionsBetween(DateTime from, DateTime to);

  /// Adds or replaces a session.
  Future<void> save(WorkoutSession session);

  /// Deletes a session.
  Future<void> delete(String id);

  /// Built-in library plus the user's custom exercises (custom first).
  List<Exercise> exercises();

  /// Creates or replaces a custom exercise.
  Future<void> saveExercise(Exercise exercise);

  /// Deletes a custom exercise (logged sets keep their name).
  Future<void> deleteExercise(String id);

  /// Emits when sessions or custom exercises change.
  Stream<void> watch();
}
