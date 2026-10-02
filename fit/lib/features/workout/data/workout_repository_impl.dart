import '../../../core/domain/data_source.dart';
import '../../../core/storage/hive_store.dart';
import '../../../core/utils/streams.dart';
import '../domain/entities/exercise.dart';
import '../domain/entities/workout_session.dart';
import '../domain/repositories/workout_repository.dart';
import 'exercise_library.dart';

/// [WorkoutSession] ↔ map.
class WorkoutSessionMapper {
  WorkoutSessionMapper._();

  static Map<String, dynamic> toMap(WorkoutSession s) => {
    'id': s.id,
    'start': s.start.millisecondsSinceEpoch,
    'title': s.title,
    'type': s.type.name,
    'durationMin': s.durationMin,
    'rpe': s.rpe,
    'deviceKcal': s.deviceKcal,
    'distanceKm': s.distanceKm,
    'source': s.source.name,
    'sets': s.sets
        .map(
          (x) => {
            'exerciseId': x.exerciseId,
            'exerciseName': x.exerciseName,
            'muscle': x.muscle.name,
            'reps': x.reps,
            'weightKg': x.weightKg,
          },
        )
        .toList(),
  };

  static WorkoutSession fromMap(Map<String, dynamic> m) => WorkoutSession(
    id: m['id'] as String,
    start: DateTime.fromMillisecondsSinceEpoch(m['start'] as int),
    title: m['title'] as String? ?? 'Workout',
    type: WorkoutType.values.firstWhere((t) => t.name == m['type'], orElse: () => WorkoutType.strength),
    durationMin: (m['durationMin'] as num?)?.toInt() ?? 0,
    rpe: (m['rpe'] as num?)?.toInt() ?? 6,
    deviceKcal: (m['deviceKcal'] as num?)?.toDouble(),
    distanceKm: (m['distanceKm'] as num?)?.toDouble(),
    source: DataSource.values.firstWhere((s) => s.name == m['source'], orElse: () => DataSource.manual),
    sets: ((m['sets'] as List?) ?? const []).map((raw) {
      final x = Map<String, dynamic>.from(raw as Map);
      return WorkoutSet(
        exerciseId: x['exerciseId'] as String,
        exerciseName: x['exerciseName'] as String? ?? '',
        muscle: MuscleGroup.values.firstWhere(
          (g) => g.name == x['muscle'],
          orElse: () => MuscleGroup.fullBody,
        ),
        reps: (x['reps'] as num?)?.toInt() ?? 0,
        weightKg: (x['weightKg'] as num?)?.toDouble() ?? 0,
      );
    }).toList(),
  );
}

/// Custom [Exercise] ↔ map.
class ExerciseMapper {
  ExerciseMapper._();

  static Map<String, dynamic> toMap(Exercise e) => {
    'id': e.id,
    'name': e.name,
    'muscle': e.muscle.name,
    'equipment': e.equipment,
    'compound': e.compound,
  };

  static Exercise fromMap(Map<String, dynamic> m) => Exercise(
    id: m['id'] as String,
    name: m['name'] as String? ?? 'Exercise',
    muscle: MuscleGroup.values.firstWhere((g) => g.name == m['muscle'], orElse: () => MuscleGroup.fullBody),
    equipment: m['equipment'] as String? ?? 'Other',
    compound: m['compound'] as bool? ?? false,
    custom: true,
  );
}

/// Hive-backed [WorkoutRepository].
class WorkoutRepositoryImpl implements WorkoutRepository {
  WorkoutRepositoryImpl(this._store, this._exercises);
  final HiveStore<WorkoutSession> _store;
  final HiveStore<Exercise> _exercises;

  @override
  List<WorkoutSession> sessions() => _store.getAll()..sort((a, b) => b.start.compareTo(a.start));

  @override
  List<WorkoutSession> sessionsBetween(DateTime from, DateTime to) =>
      _store.where((s) => !s.start.isBefore(from) && s.start.isBefore(to))
        ..sort((a, b) => b.start.compareTo(a.start));

  @override
  Future<void> save(WorkoutSession session) => _store.put(session.id, session);

  @override
  Future<void> delete(String id) => _store.delete(id);

  @override
  List<Exercise> exercises() => [
    ..._exercises.getAll()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
    ...ExerciseLibrary.all,
  ];

  @override
  Future<void> saveExercise(Exercise exercise) => _exercises.put(exercise.id, exercise);

  @override
  Future<void> deleteExercise(String id) => _exercises.delete(id);

  @override
  Stream<void> watch() => mergeChanges([_store.watch(), _exercises.watch()]);
}
