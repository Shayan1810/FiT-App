import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/date_utils.dart';
import '../../data/sync/sync_coordinator.dart';
import '../../domain/entities/food_item.dart';
import '../../domain/entities/food_log_entry.dart';
import '../../domain/entities/nutrition_analysis.dart';
import '../../domain/entities/nutrition_facts.dart';
import '../../domain/repositories/nutrition_repository.dart';
import '../../domain/usecases/log_food.dart';

// ── Events ──────────────────────────────────────────────────────────────
/// Base class of food-diary events.
sealed class NutritionEvent {
  const NutritionEvent();
}

/// Load the selected day and start watching storage.
class NutritionStarted extends NutritionEvent {
  const NutritionStarted();
}

/// Show another day of the diary.
class NutritionDaySelected extends NutritionEvent {
  const NutritionDaySelected(this.day);
  final DateTime day;
}

/// Log [grams] of a food into a meal slot.
class NutritionFoodLogged extends NutritionEvent {
  const NutritionFoodLogged(this.food, this.grams, this.slot);
  final FoodItem food;
  final double grams;
  final MealSlot slot;
}

/// Log every item of a text analysis (or a pending placeholder).
class NutritionAnalysisLogged extends NutritionEvent {
  const NutritionAnalysisLogged(this.analysis, this.slot);
  final NutritionAnalysis analysis;
  final MealSlot slot;
}

/// Delete a diary entry.
class NutritionEntryDeleted extends NutritionEvent {
  const NutritionEntryDeleted(this.entry);
  final FoodLogEntry entry;
}

/// Re-inserts a deleted entry (snackbar "Undo").
class NutritionEntryRestored extends NutritionEvent {
  const NutritionEntryRestored(this.entry);
  final FoodLogEntry entry;
}

/// Change the grams of an entry (nutrition rescales).
class NutritionEntryAmountChanged extends NutritionEvent {
  const NutritionEntryAmountChanged(this.entry, this.grams);
  final FoodLogEntry entry;
  final double grams;
}

/// Add (or subtract, if negative) water in mL.
class NutritionWaterAdded extends NutritionEvent {
  const NutritionWaterAdded(this.deltaMl, {this.day});
  final int deltaMl;

  /// Day to change; defaults to the selected day.
  final DateTime? day;
}

class _NutritionChanged extends NutritionEvent {
  const _NutritionChanged();
}

// ── State ───────────────────────────────────────────────────────────────
/// Diary entries, water and pending jobs for the selected day.
class NutritionState extends Equatable {
  const NutritionState({required this.day, this.entries = const [], this.waterMl = 0, this.pendingJobs = 0});

  final DateTime day;
  final List<FoodLogEntry> entries;
  final int waterMl;

  /// Meals waiting for an online analysis.
  final int pendingJobs;

  /// Totals for the selected day.
  NutritionFacts get totals => entries.fold(NutritionFacts.zero, (a, e) => a + e.facts);

  /// Entries of one meal slot.
  List<FoodLogEntry> slot(MealSlot s) => entries.where((e) => e.slot == s).toList();

  @override
  List<Object?> get props => [day, entries, waterMl, pendingJobs];
}

// ── Bloc ────────────────────────────────────────────────────────────────

/// Food diary for the selected day. Writes go to Hive first (instant), and
/// the state is re-read from the repository watch stream — the single
/// source of truth — so offline-queue updates appear automatically.
class NutritionBloc extends Bloc<NutritionEvent, NutritionState> {
  NutritionBloc({required NutritionRepository repo, required LogFood logFood, required SyncCoordinator sync})
    : _repo = repo,
      _log = logFood,
      _sync = sync,
      super(NutritionState(day: DateKeys.startOfDay(DateTime.now()))) {
    on<NutritionStarted>((e, emit) {
      _sub ??= _repo.watch().listen((_) => add(const _NutritionChanged()));
      _emitDay(emit, state.day);
    });
    on<_NutritionChanged>((e, emit) => _emitDay(emit, state.day));
    on<NutritionDaySelected>((e, emit) => _emitDay(emit, DateKeys.startOfDay(e.day)));
    on<NutritionFoodLogged>(
      (e, emit) => _log.fromItem(food: e.food, grams: e.grams, slot: e.slot, day: state.day),
    );
    on<NutritionAnalysisLogged>((e, emit) async {
      await _log.fromAnalysis(analysis: e.analysis, slot: e.slot, day: state.day);
      if (e.analysis.source == AnalysisSource.pending) unawaited(_sync.drain());
    });
    on<NutritionEntryDeleted>((e, emit) => _repo.deleteEntry(e.entry.id));
    on<NutritionEntryRestored>((e, emit) => _repo.saveEntry(e.entry));
    on<NutritionEntryAmountChanged>((e, emit) => _log.changeAmount(e.entry, e.grams));
    on<NutritionWaterAdded>((e, emit) {
      final key = DateKeys.of(e.day ?? state.day);
      return _repo.setWater(key, _repo.waterFor(key) + e.deltaMl);
    });
  }

  final NutritionRepository _repo;
  final LogFood _log;
  final SyncCoordinator _sync;
  StreamSubscription<void>? _sub;

  void _emitDay(Emitter<NutritionState> emit, DateTime day) {
    final key = DateKeys.of(day);
    emit(
      NutritionState(
        day: day,
        entries: _repo.entriesForDay(key),
        waterMl: _repo.waterFor(key),
        pendingJobs: _sync.pending,
      ),
    );
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
