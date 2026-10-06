import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/get_progress.dart';
import '../domain/progress_calculator.dart';

/// Time ranges offered on the Progress screen.
enum ProgressRange { plan, month, quarter, half, year }

extension ProgressRangeX on ProgressRange {
  /// Days covered; [ProgressRange.plan] is resolved by the cubit.
  int get days => switch (this) {
    ProgressRange.plan => 30,
    ProgressRange.month => 30,
    ProgressRange.quarter => 90,
    ProgressRange.half => 180,
    ProgressRange.year => 365,
  };

  String get label => switch (this) {
    ProgressRange.plan => 'Plan',
    ProgressRange.month => '30 D',
    ProgressRange.quarter => '90 D',
    ProgressRange.half => '6 M',
    ProgressRange.year => '1 Y',
  };
}

/// State of the Progress screen.
class ProgressState extends Equatable {
  const ProgressState({
    this.range = ProgressRange.month,
    this.category = ProgressCategory.nutrition,
    this.report,
    this.loading = false,
    this.version = 0,
  });

  final ProgressRange range;
  final ProgressCategory category;
  final ProgressReport? report;
  final bool loading;

  /// Bumped on every new report (reports aren't value-comparable).
  final int version;

  ProgressState copyWith({
    ProgressRange? range,
    ProgressCategory? category,
    ProgressReport? report,
    bool? loading,
    int? version,
  }) => ProgressState(
    range: range ?? this.range,
    category: category ?? this.category,
    report: report ?? this.report,
    loading: loading ?? this.loading,
    version: version ?? this.version,
  );

  @override
  List<Object?> get props => [range, category, loading, version];
}

/// Computes [ProgressReport]s in a background isolate and recomputes
/// (debounced) whenever any repository changes.
class ProgressCubit extends Cubit<ProgressState> {
  ProgressCubit(
    this._get,
    Stream<void> changes, {
    this.debounce = const Duration(milliseconds: 800),
    int? Function()? planDays,
  }) : _planDays = planDays ?? (() => null),
       super(const ProgressState()) {
    _sub = changes.listen((_) {
      _timer?.cancel();
      _timer = Timer(debounce, load);
    });
  }

  final GetProgress _get;

  /// Days since the active transformation started (null = none active).
  final int? Function() _planDays;

  /// Whether the "Plan" range is available.
  bool get hasPlan => _planDays() != null;
  final Duration debounce;
  StreamSubscription<void>? _sub;
  Timer? _timer;
  int _request = 0;
  bool _planSeen = false;

  /// (Re)computes the report for the current range.
  Future<void> load() async {
    final id = ++_request;
    final planDays = _planDays();
    // Follow the transformation: default to its period, fall back when it ends.
    if (planDays != null && !_planSeen) {
      _planSeen = true;
      emit(state.copyWith(range: ProgressRange.plan, category: ProgressCategory.plan));
    } else if (planDays == null && state.range == ProgressRange.plan) {
      _planSeen = false;
      emit(state.copyWith(range: ProgressRange.month, category: ProgressCategory.nutrition));
    }
    emit(state.copyWith(loading: true));
    final days = state.range == ProgressRange.plan ? (planDays ?? 30).clamp(2, 3650) : state.range.days;
    final report = await _get(days);
    if (isClosed || id != _request) return;
    emit(state.copyWith(report: report, loading: false, version: state.version + 1));
  }

  void setRange(ProgressRange r) {
    if (r == state.range) return;
    emit(state.copyWith(range: r));
    load();
  }

  void setCategory(ProgressCategory c) => emit(state.copyWith(category: c));

  @override
  Future<void> close() {
    _timer?.cancel();
    _sub?.cancel();
    return super.close();
  }
}
