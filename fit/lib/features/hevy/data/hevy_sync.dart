import 'dart:math';

import '../../../core/domain/data_source.dart';
import '../../../core/network/retry_policy.dart';
import '../../../core/storage/settings_store.dart';
import '../../../core/utils/date_utils.dart';
import '../../transformation/domain/repositories/transformation_repository.dart';
import '../../workout/domain/entities/exercise.dart';
import '../../workout/domain/entities/workout_session.dart';
import '../../workout/domain/repositories/workout_repository.dart';
import 'hevy_client.dart';

/// Result of a Hevy sync.
class HevyReport {
  const HevyReport({this.imported = 0, this.deleted = 0, this.planTicks = 0, this.error});
  final int imported;
  final int deleted;
  final int planTicks;
  final String? error;

  bool get ok => error == null;

  @override
  String toString() =>
      error ??
      (imported + deleted == 0
          ? 'Hevy: up to date'
          : 'Hevy: $imported workout${imported == 1 ? '' : 's'} synced'
                '${deleted > 0 ? ', $deleted removed' : ''}'
                '${planTicks > 0 ? ', $planTicks planned workout${planTicks == 1 ? '' : 's'} ticked' : ''}');
}

/// Imports Hevy workouts into FiT.
///
/// * First sync: the last [initialDays] days; later: only changes (Hevy
///   workout events), including deletions.
/// * Ids are `hevy_<id>`, so re-syncing never duplicates.
/// * Exercises are matched to FiT's library by name, so strength history
///   (e1RM, overload targets) continues across apps.
/// * In Transformation mode a Hevy workout ticks that day's planned workout.
class HevySync {
  HevySync({
    required HevyClient client,
    required SettingsStore settings,
    required WorkoutRepository workouts,
    TransformationRepository? plans,
    DateTime Function()? clock,
  }) : _client = client,
       _settings = settings,
       _workouts = workouts,
       _plans = plans,
       _clock = clock ?? DateTime.now;

  static const int initialDays = 90;

  final HevyClient _client;
  final SettingsStore _settings;
  final WorkoutRepository _workouts;
  final TransformationRepository? _plans;
  final DateTime Function() _clock;
  bool _running = false;

  String? get apiKey {
    final k = _settings.read<String>(SettingsStore.kHevyApiKey)?.trim();
    return k == null || k.isEmpty ? null : k;
  }

  bool get configured => apiKey != null;

  DateTime? get lastSync {
    final ms = _settings.read<int>(SettingsStore.kHevyLastSync);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Saves (and checks) an API key. Returns an error message or null.
  Future<String?> connect(String key) async {
    try {
      await _client.workoutCount(key.trim());
    } on RemoteCallException catch (e) {
      return e.statusCode == 401 || e.statusCode == 403
          ? 'Hevy rejected this API key. Copy it again from Hevy > Settings > Developer.'
          : 'Could not reach Hevy (${e.message}). Try again later.';
    } catch (_) {
      return 'Could not reach Hevy. Check your internet connection.';
    }
    await _settings.write(SettingsStore.kHevyApiKey, key.trim());
    await _settings.write(SettingsStore.kHevyLastSync, null);
    return null;
  }

  /// Forgets the key (imported workouts stay).
  Future<void> disconnect() async {
    await _settings.write(SettingsStore.kHevyApiKey, null);
    await _settings.write(SettingsStore.kHevyLastSync, null);
  }

  /// Pulls new, changed and deleted workouts.
  Future<HevyReport> sync() async {
    final key = apiKey;
    if (key == null) return const HevyReport(error: 'Hevy is not connected.');
    if (_running) return const HevyReport();
    _running = true;
    try {
      final now = _clock();
      final last = lastSync;
      var imported = 0, deleted = 0;
      final touched = <WorkoutSession>[];
      if (last == null) {
        for (final w in await _client.workoutsSince(key, now.subtract(const Duration(days: initialDays)))) {
          final s = toSession(w);
          if (s == null) continue;
          await _workouts.save(s);
          touched.add(s);
          imported++;
        }
      } else {
        for (final e in await _client.eventsSince(key, last.subtract(const Duration(hours: 1)))) {
          if (e.deletedId != null) {
            await _workouts.delete('hevy_${e.deletedId}');
            deleted++;
          } else {
            final s = toSession(e.workout!);
            if (s == null) continue;
            await _workouts.save(s);
            touched.add(s);
            imported++;
          }
        }
      }
      final ticks = await _tickPlan(touched);
      await _settings.write(SettingsStore.kHevyLastSync, now.millisecondsSinceEpoch);
      return HevyReport(imported: imported, deleted: deleted, planTicks: ticks);
    } on RemoteCallException catch (e) {
      return HevyReport(
        error: e.statusCode == 401 || e.statusCode == 403
            ? 'Hevy rejected the API key.'
            : 'Hevy sync failed: ${e.message}',
      );
    } catch (e) {
      return HevyReport(error: 'Hevy sync failed: $e');
    } finally {
      _running = false;
    }
  }

  /// Ticks the planned workout on the day of each imported Hevy workout.
  Future<int> _tickPlan(List<WorkoutSession> sessions) async {
    final repo = _plans;
    final plan = repo?.activePlan();
    if (repo == null || plan == null || repo.mode != AppMode.transformation) return 0;
    var ticks = 0;
    final byDay = <String, int>{};
    for (final s in sessions..sort((a, b) => a.start.compareTo(b.start))) {
      if (!plan.contains(s.start) || s.sets.isEmpty) continue;
      final key = DateKeys.of(s.start);
      final planned = plan.workoutsOn(s.start);
      final done = repo.checksFor(key);
      final open = [
        for (final w in planned)
          if (!done.contains(w.id)) w,
      ];
      final k = byDay[key] ?? 0;
      if (k < open.length) {
        await repo.setCheck(key, open[k].id, true);
        byDay[key] = k + 1;
        ticks++;
      }
    }
    return ticks;
  }

  // ── Mapping ──────────────────────────────────────────────────────────

  /// Converts a Hevy workout; null if it has no usable sets.
  WorkoutSession? toSession(HevyWorkout w) {
    final library = _workouts.exercises();
    final sets = <WorkoutSet>[];
    var distance = 0.0;
    final rpes = <double>[];
    for (final e in w.exercises) {
      final ex = matchExercise(e.title, e.templateId, library);
      for (final s in e.sets) {
        if (s.type == 'warmup') continue;
        if (s.distanceMeters != null) distance += s.distanceMeters!;
        if (s.rpe != null) rpes.add(s.rpe!);
        final reps = s.reps ?? (s.durationSeconds != null ? max(1, s.durationSeconds! ~/ 30) : 0);
        if (reps <= 0) continue;
        sets.add(
          WorkoutSet(
            exerciseId: ex.id,
            exerciseName: ex.name,
            muscle: ex.muscle,
            reps: reps,
            weightKg: s.weightKg ?? 0,
          ),
        );
      }
    }
    final minutes = max(1, w.end.difference(w.start).inMinutes);
    if (sets.isEmpty && distance == 0) return null;
    return WorkoutSession(
      id: 'hevy_${w.id}',
      start: w.start,
      title: w.title,
      type: sets.isEmpty ? WorkoutType.cardio : WorkoutType.strength,
      durationMin: minutes,
      rpe: rpes.isEmpty ? 7 : (rpes.reduce((a, b) => a + b) / rpes.length).round().clamp(1, 10),
      sets: sets,
      distanceKm: distance > 0 ? distance / 1000 : null,
      source: DataSource.hevy,
    );
  }

  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'\(.*?\)'), ' ')
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Matches a Hevy exercise title ("Bench Press (Barbell)") to FiT's
  /// library; unknown exercises get a stable id and a guessed muscle group.
  static Exercise matchExercise(String title, String templateId, List<Exercise> library) {
    final t = _norm(title);
    final equipment = RegExp(r'\((.*?)\)').firstMatch(title)?.group(1)?.toLowerCase() ?? '';
    Exercise? best;
    var bestScore = 0;
    for (final ex in library) {
      final n = _norm(ex.name);
      var score = 0;
      if (n == t) {
        score = 100;
      } else if (n.contains(t) || t.contains(n)) {
        score = 60 + min(n.length, t.length);
      }
      if (score > 0 && equipment.isNotEmpty && ex.equipment.toLowerCase().contains(equipment)) score += 15;
      if (score > bestScore) {
        bestScore = score;
        best = ex;
      }
    }
    if (best != null && bestScore >= 64) return best;
    return Exercise(
      id: 'hevy_${templateId.isEmpty ? t.replaceAll(' ', '_') : templateId}',
      name: title,
      muscle: guessMuscle(t),
      equipment: equipment.isEmpty ? 'Other' : equipment,
      custom: true,
    );
  }

  static MuscleGroup guessMuscle(String t) {
    bool has(List<String> ws) => ws.any(t.contains);
    // Order matters: more specific phrases first.
    const rules = <(List<String>, MuscleGroup)>[
      (
        ['run', 'cycl', 'bike', 'elliptical', 'treadmill', 'walk', 'swim', 'jump rope', 'rowing machine'],
        MuscleGroup.cardio,
      ),
      (
        ['crunch', 'plank', 'sit up', 'leg raise', 'russian twist', 'ab wheel', 'oblique', 'core'],
        MuscleGroup.core,
      ),
      (
        ['lateral raise', 'front raise', 'shoulder', 'overhead press', 'military', 'arnold', 'delt'],
        MuscleGroup.shoulders,
      ),
      (['hip thrust', 'glute', 'romanian', 'good morning', 'kickback'], MuscleGroup.glutes),
      (['squat', 'leg press', 'leg extension', 'leg curl', 'lunge', 'calf', 'step up'], MuscleGroup.legs),
      (['bench', 'chest', 'fly', 'push up', 'pushup', 'dip', 'pec'], MuscleGroup.chest),
      (['deadlift', 'row', 'pull', 'chin up', 'lat pulldown', 'shrug', 'back extension'], MuscleGroup.back),
      (['curl', 'tricep', 'skull', 'pushdown', 'extension'], MuscleGroup.arms),
    ];
    for (final (words, muscle) in rules) {
      if (has(words)) return muscle;
    }
    return MuscleGroup.fullBody;
  }
}
