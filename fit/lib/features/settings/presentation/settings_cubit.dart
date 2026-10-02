import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/storage/hive_boxes.dart';
import '../../../core/storage/settings_store.dart';
import '../../../core/utils/perf_monitor.dart';
import '../../nutrition/data/repositories/nutrition_pipeline.dart';
import '../../nutrition/data/sync/sync_coordinator.dart';

/// AI settings and diagnostics numbers shown in Settings.
class SettingsState extends Equatable {
  const SettingsState({
    this.hasApiKey = false,
    this.model = SettingsStore.defaultModel,
    this.perf = const [],
    this.avgMs = 0,
    this.successRate = 1,
    this.queries = 0,
    this.cacheHits = 0,
    this.localHits = 0,
    this.geminiCalls = 0,
    this.geminiAttempts = 0,
    this.pendingJobs = 0,
  });

  final bool hasApiKey;
  final String model;
  final List<PerfStats> perf;
  final double avgMs;
  final double successRate;
  final int queries;
  final int cacheHits;
  final int localHits;
  final int geminiCalls;
  final int geminiAttempts;
  final int pendingJobs;

  @override
  List<Object?> get props => [
    hasApiKey,
    model,
    perf.length,
    avgMs,
    successRate,
    queries,
    cacheHits,
    localHits,
    geminiCalls,
    geminiAttempts,
    pendingJobs,
  ];
}

/// Settings + Diagnostics.
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(this._settings, this._sync) : super(const SettingsState());

  final SettingsStore _settings;
  final SyncCoordinator _sync;

  /// Re-reads settings and statistics.
  void refresh() {
    emit(
      SettingsState(
        hasApiKey: (_settings.geminiApiKey ?? '').isNotEmpty,
        model: _settings.geminiModel,
        perf: PerfMonitor.instance.stats(),
        avgMs: PerfMonitor.instance.overallAverageMs(),
        successRate: NutritionPipeline.successRate(_settings),
        queries: _settings.counterValue(PipelineStats.queries),
        cacheHits: _settings.counterValue(PipelineStats.cacheHits),
        localHits: _settings.counterValue(PipelineStats.localHits),
        geminiCalls: _settings.counterValue(PipelineStats.geminiCalls),
        geminiAttempts: _settings.counterValue(PipelineStats.geminiAttempts),
        pendingJobs: _sync.pending,
      ),
    );
  }

  /// Stores (or clears, if empty) the Gemini API key, then retries the queue.
  Future<void> setApiKey(String key) async {
    await _settings.write(SettingsStore.kGeminiApiKey, key.trim());
    refresh();
    await _sync.drain();
    refresh();
  }

  /// Changes the Gemini model id.
  Future<void> setModel(String model) async {
    await _settings.write(SettingsStore.kGeminiModel, model.trim());
    refresh();
  }

  /// Deletes every record in every box (irreversible).
  Future<void> resetAll() async {
    await HiveBoxes.clearAll();
    PerfMonitor.instance.reset();
    refresh();
  }
}
