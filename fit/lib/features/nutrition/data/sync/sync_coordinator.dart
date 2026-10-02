import 'dart:async';

import '../../../../core/network/connectivity_service.dart';
import '../../../../core/storage/settings_store.dart';
import '../../domain/entities/food_log_entry.dart';
import '../../domain/entities/nutrition_analysis.dart';
import '../../domain/repositories/nutrition_repository.dart';
import '../repositories/nutrition_pipeline.dart';
import 'sync_queue.dart';

/// Offline → online hand-off.
///
/// When a meal was logged while offline (or Gemini failed), a placeholder
/// diary entry is saved instantly (so the UI never waits) and a job is
/// queued. This coordinator listens for connectivity and, as soon as the
/// device is online, drains the queue: each job is analysed remotely and its
/// placeholder entry is replaced in Hive — the diary updates live through
/// the repository's watch stream.
class SyncCoordinator {
  SyncCoordinator({
    required SyncQueue queue,
    required NutritionAnalysisRepository analyzer,
    required NutritionRepository nutrition,
    required ConnectivityService connectivity,
    required SettingsStore settings,
  }) : _queue = queue,
       _analyzer = analyzer,
       _nutrition = nutrition,
       _connectivity = connectivity,
       _settings = settings;

  final SyncQueue _queue;
  final NutritionAnalysisRepository _analyzer;
  final NutritionRepository _nutrition;
  final ConnectivityService _connectivity;
  final SettingsStore _settings;

  /// Jobs are abandoned (entry stays editable) after this many failures.
  static const int maxAttempts = 8;

  StreamSubscription<bool>? _sub;
  bool _draining = false;

  /// Starts listening for connectivity and drains once immediately.
  void start() {
    _sub ??= _connectivity.onStatusChange.listen((online) {
      if (online) drain();
    });
    drain();
  }

  /// Stops listening.
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  /// Number of jobs waiting.
  int get pending => _queue.length;

  /// Processes all queued jobs; returns how many were resolved.
  Future<int> drain() async {
    if (_draining || !_analyzer.remoteAvailable) return 0;
    if (!await _connectivity.isOnline()) return 0;
    _draining = true;
    var resolved = 0;
    try {
      for (final job in _queue.all()) {
        if (job.attempts >= maxAttempts) continue;
        final entry = _nutrition.entryById(job.entryId);
        if (entry == null) {
          await _queue.remove(job.id); // user deleted the placeholder
          continue;
        }
        try {
          final result = await _analyzer.analyzeRemote(job.text);
          await _nutrition.saveEntry(applyAnalysis(entry, result));
          await _queue.remove(job.id);
          await _settings.increment(PipelineStats.success);
          resolved++;
        } catch (e) {
          await _queue.update(job.failed(e.toString()));
          if (job.attempts + 1 >= maxAttempts) {
            await _settings.increment(PipelineStats.failure);
          }
        }
      }
    } finally {
      _draining = false;
    }
    return resolved;
  }

  /// Fills a pending placeholder [entry] with an [analysis] result.
  static FoodLogEntry applyAnalysis(FoodLogEntry entry, NutritionAnalysis analysis) {
    final names = analysis.items.map((i) => i.name).toList();
    final name = names.length <= 2
        ? names.join(' + ')
        : '${names.take(2).join(', ')} +${names.length - 2} more';
    return entry.copyWith(
      name: name.isEmpty ? entry.name : name,
      grams: analysis.items.fold<double>(0, (a, i) => a + i.grams),
      facts: analysis.total,
      source: EntrySource.gemini,
    );
  }
}
