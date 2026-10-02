import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/daily_briefing.dart';
import '../../domain/usecases/generate_briefing.dart';

// ── Events ──────────────────────────────────────────────────────────────
/// Base class of all insight events.
sealed class InsightsEvent {
  const InsightsEvent();
}

/// Start listening to data changes and compute the first briefing.
class InsightsStarted extends InsightsEvent {
  const InsightsStarted();
}

/// Recompute now (pull-to-refresh, app resume, day rollover).
class InsightsRefreshRequested extends InsightsEvent {
  const InsightsRefreshRequested();
}

// ── State ───────────────────────────────────────────────────────────────
/// Lifecycle of the briefing computation.
enum InsightsStatus { initial, loading, ready, needsOnboarding, failure }

/// State holding the latest [DailyBriefing].
class InsightsState extends Equatable {
  const InsightsState({this.status = InsightsStatus.initial, this.briefing, this.error});

  final InsightsStatus status;

  /// Last computed briefing (kept while a refresh runs, so UI never blanks).
  final DailyBriefing? briefing;
  final String? error;

  InsightsState copyWith({InsightsStatus? status, DailyBriefing? briefing, String? error}) =>
      InsightsState(status: status ?? this.status, briefing: briefing ?? this.briefing, error: error);

  @override
  List<Object?> get props => [status, briefing?.generatedAt, error];
}

// ── Bloc ────────────────────────────────────────────────────────────────

/// Owns the [DailyBriefing]. Every repository change (food logged, steps
/// synced, workout saved, …) triggers a debounced recompute in a background
/// isolate, so every screen always shows up-to-date coaching.
class InsightsBloc extends Bloc<InsightsEvent, InsightsState> {
  InsightsBloc({
    required GenerateBriefing generate,
    required Stream<void> changes,
    this.debounce = const Duration(milliseconds: 300),
  }) : _generate = generate,
       _changes = changes,
       super(const InsightsState()) {
    on<InsightsStarted>(_onStarted);
    on<InsightsRefreshRequested>(_onRefresh, transformer: _restartable());
  }

  final GenerateBriefing _generate;
  final Stream<void> _changes;
  final Duration debounce;
  StreamSubscription<void>? _sub;
  Timer? _timer;

  /// Drops an in-flight refresh when a newer one arrives.
  static EventTransformer<E> _restartable<E>() =>
      (events, mapper) => events.asyncExpand(mapper);

  Future<void> _onStarted(InsightsStarted e, Emitter<InsightsState> emit) async {
    _sub ??= _changes.listen((_) {
      _timer?.cancel();
      _timer = Timer(debounce, () => add(const InsightsRefreshRequested()));
    });
    await _onRefresh(const InsightsRefreshRequested(), emit);
  }

  Future<void> _onRefresh(InsightsRefreshRequested e, Emitter<InsightsState> emit) async {
    if (state.briefing == null) emit(state.copyWith(status: InsightsStatus.loading));
    try {
      final b = await _generate();
      if (b == null) {
        emit(const InsightsState(status: InsightsStatus.needsOnboarding));
      } else {
        emit(InsightsState(status: InsightsStatus.ready, briefing: b));
      }
    } catch (err) {
      emit(state.copyWith(status: InsightsStatus.failure, error: err.toString()));
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    _sub?.cancel();
    return super.close();
  }
}
