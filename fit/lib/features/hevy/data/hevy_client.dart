import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/retry_policy.dart';

/// One set from Hevy.
class HevySet {
  const HevySet({
    required this.type,
    this.weightKg,
    this.reps,
    this.durationSeconds,
    this.distanceMeters,
    this.rpe,
  });

  /// "normal", "warmup", "dropset" or "failure".
  final String type;
  final double? weightKg;
  final int? reps;
  final int? durationSeconds;
  final double? distanceMeters;
  final double? rpe;

  factory HevySet.fromJson(Map<String, dynamic> j) => HevySet(
    type: (j['type'] as String?) ?? 'normal',
    weightKg: (j['weight_kg'] as num?)?.toDouble(),
    reps: (j['reps'] as num?)?.toInt(),
    durationSeconds: (j['duration_seconds'] as num?)?.toInt(),
    distanceMeters: (j['distance_meters'] as num?)?.toDouble(),
    rpe: (j['rpe'] as num?)?.toDouble(),
  );
}

/// One exercise of a Hevy workout.
class HevyExercise {
  const HevyExercise({required this.title, required this.templateId, required this.sets});
  final String title;
  final String templateId;
  final List<HevySet> sets;

  factory HevyExercise.fromJson(Map<String, dynamic> j) => HevyExercise(
    title: (j['title'] as String?) ?? 'Exercise',
    templateId: (j['exercise_template_id'] as String?) ?? '',
    sets: [
      for (final s in (j['sets'] as List? ?? const [])) HevySet.fromJson(Map<String, dynamic>.from(s as Map)),
    ],
  );
}

/// A workout logged in Hevy.
class HevyWorkout {
  const HevyWorkout({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    required this.exercises,
  });
  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final List<HevyExercise> exercises;

  factory HevyWorkout.fromJson(Map<String, dynamic> j) => HevyWorkout(
    id: j['id'] as String,
    title: (j['title'] as String?) ?? 'Workout',
    start: DateTime.parse(j['start_time'] as String).toLocal(),
    end: DateTime.parse((j['end_time'] ?? j['start_time']) as String).toLocal(),
    exercises: [
      for (final e in (j['exercises'] as List? ?? const []))
        HevyExercise.fromJson(Map<String, dynamic>.from(e as Map)),
    ],
  );
}

/// A change since the last sync (Hevy "workout events").
class HevyEvent {
  const HevyEvent.updated(HevyWorkout this.workout) : deletedId = null;
  const HevyEvent.deleted(String this.deletedId) : workout = null;
  final HevyWorkout? workout;
  final String? deletedId;
}

/// Minimal client for the official Hevy public API (`api.hevyapp.com/v1`).
/// Needs an API key from Hevy (Settings → Developer, Hevy Pro).
class HevyClient {
  HevyClient(this._http, {RetryPolicy retry = const RetryPolicy(maxAttempts: 3)}) : _retry = retry;

  static const String baseUrl = 'https://api.hevyapp.com';
  static const int pageSize = 10; // API maximum for workouts

  final http.Client _http;
  final RetryPolicy _retry;

  Future<Map<String, dynamic>> _get(String apiKey, String path, Map<String, String> query) => _retry.run((
    _,
  ) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final res = await _http
        .get(uri, headers: {'api-key': apiKey, 'accept': 'application/json'})
        .timeout(_retry.attemptTimeout);
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw RemoteCallException('Hevy rejected the API key.', statusCode: res.statusCode, retryable: false);
    }
    if (res.statusCode == 404) return const <String, dynamic>{};
    if (res.statusCode != 200) {
      throw RemoteCallException(
        'Hevy error ${res.statusCode}',
        statusCode: res.statusCode,
        retryable: RetryPolicy.isRetryableStatus(res.statusCode),
      );
    }
    return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
  });

  /// Total number of workouts (also used to check the key).
  Future<int> workoutCount(String apiKey) async =>
      ((await _get(apiKey, '/v1/workouts/count', const {}))['workout_count'] as num?)?.toInt() ?? 0;

  /// Workouts newest first, stopping at [since] (inclusive) or [maxPages].
  Future<List<HevyWorkout>> workoutsSince(String apiKey, DateTime since, {int maxPages = 30}) async {
    final out = <HevyWorkout>[];
    for (var page = 1; page <= maxPages; page++) {
      final j = await _get(apiKey, '/v1/workouts', {'page': '$page', 'pageSize': '$pageSize'});
      final list = [
        for (final w in (j['workouts'] as List? ?? const []))
          HevyWorkout.fromJson(Map<String, dynamic>.from(w as Map)),
      ];
      var older = false;
      for (final w in list) {
        if (w.start.isBefore(since)) {
          older = true;
        } else {
          out.add(w);
        }
      }
      final pages = (j['page_count'] as num?)?.toInt() ?? page;
      if (older || list.isEmpty || page >= pages) break;
    }
    return out;
  }

  /// Workouts updated or deleted since [since].
  Future<List<HevyEvent>> eventsSince(String apiKey, DateTime since, {int maxPages = 30}) async {
    final out = <HevyEvent>[];
    for (var page = 1; page <= maxPages; page++) {
      final j = await _get(apiKey, '/v1/workouts/events', {
        'page': '$page',
        'pageSize': '$pageSize',
        'since': since.toUtc().toIso8601String(),
      });
      final events = j['events'] as List? ?? const [];
      for (final raw in events) {
        final e = Map<String, dynamic>.from(raw as Map);
        if (e['type'] == 'deleted') {
          final id = e['id'] as String?;
          if (id != null) out.add(HevyEvent.deleted(id));
        } else if (e['workout'] != null) {
          out.add(HevyEvent.updated(HevyWorkout.fromJson(Map<String, dynamic>.from(e['workout'] as Map))));
        }
      }
      final pages = (j['page_count'] as num?)?.toInt() ?? page;
      if (events.isEmpty || page >= pages) break;
    }
    return out;
  }
}
