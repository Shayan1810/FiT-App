import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/date_utils.dart';
import '../../profile/domain/entities/user_profile.dart';
import '../../profile/domain/entities/weight_entry.dart';
import '../../profile/domain/repositories/profile_repository.dart';
import '../../workout/domain/entities/workout_session.dart';
import '../domain/calculators/strength_calculator.dart';
import '../domain/entities/transformation_plan.dart';
import '../domain/repositories/transformation_repository.dart';
import '../domain/usecases/toggle_plan_item.dart';

/// State of Transformation mode.
class TransformationState extends Equatable {
  const TransformationState({
    this.mode = AppMode.general,
    this.plan,
    this.day,
    this.checks = const {},
    this.message,
    this.version = 0,
  });

  final AppMode mode;
  final TransformationPlan? plan;

  /// Day shown on the checklist (defaults to today).
  final DateTime? day;

  /// Ticked item ids of [day].
  final Set<String> checks;

  /// One-off toast text.
  final String? message;
  final int version;

  /// Transformation mode is on and the plan hasn't ended.
  bool isActive(DateTime now) => mode == AppMode.transformation && plan != null && !plan!.isFinished(now);

  TransformationState copyWith({
    AppMode? mode,
    TransformationPlan? plan,
    bool clearPlan = false,
    DateTime? day,
    Set<String>? checks,
    String? message,
  }) => TransformationState(
    mode: mode ?? this.mode,
    plan: clearPlan ? null : (plan ?? this.plan),
    day: day ?? this.day,
    checks: checks ?? this.checks,
    message: message,
    version: version + 1,
  );

  @override
  List<Object?> get props => [mode, plan, day, checks, message, version];
}

/// Owns the mode switch, the active plan and the checklist ticks.
class TransformationCubit extends Cubit<TransformationState> {
  TransformationCubit({
    required TransformationRepository repo,
    required TogglePlanItem toggle,
    required ProfileRepository profile,
    DateTime Function()? clock,
  }) : _repo = repo,
       _toggle = toggle,
       _profile = profile,
       _clock = clock ?? DateTime.now,
       super(const TransformationState());

  final TransformationRepository _repo;
  final TogglePlanItem _toggle;
  final ProfileRepository _profile;
  final DateTime Function() _clock;
  StreamSubscription<void>? _sub;

  DateTime get _today => DateKeys.startOfDay(_clock());

  /// Loads state, ends a finished transformation, and listens for changes.
  Future<void> start() async {
    _sub ??= _repo.watch().listen((_) => _reload());
    final plan = _repo.activePlan();
    if (_repo.mode == AppMode.transformation && plan != null && plan.isFinished(_clock())) {
      await _repo.setMode(AppMode.general);
      _reload(message: '${plan.name} is complete. FiT is back in General mode.');
      return;
    }
    _reload();
  }

  void _reload({String? message}) {
    if (isClosed) return;
    final plan = _repo.activePlan();
    var day = state.day ?? _today;
    if (plan != null && plan.contains(_clock()) && !plan.contains(day)) day = _today;
    emit(
      state.copyWith(
        mode: _repo.mode,
        plan: plan,
        clearPlan: plan == null,
        day: day,
        checks: _repo.checksFor(DateKeys.of(day)),
        message: message,
      ),
    );
  }

  /// Shows another day of the plan on the checklist.
  void selectDay(DateTime day) {
    emit(state.copyWith(day: DateKeys.startOfDay(day), checks: _repo.checksFor(DateKeys.of(day))));
  }

  /// Switches mode. Turning Transformation on without a plan is refused.
  Future<bool> setMode(AppMode mode) async {
    if (mode == AppMode.transformation) {
      final plan = _repo.activePlan();
      if (plan == null) return false;
      if (plan.isFinished(_clock())) {
        _reload(message: 'This transformation has ended. Create a new one to switch modes.');
        return false;
      }
    }
    await _repo.setMode(mode);
    _reload(message: mode == AppMode.transformation ? 'Transformation mode on' : 'Back to General mode');
    return true;
  }

  /// Saves (creates or edits) a plan, turns Transformation mode on and
  /// seeds the profile with the plan's starting numbers.
  Future<void> savePlan(TransformationPlan plan) async {
    final isNew = state.plan?.id != plan.id;
    await _repo.savePlan(plan);
    await _repo.setMode(AppMode.transformation);
    final p = _profile.getProfile();
    if (p != null && plan.hasBody) {
      final goal = switch (plan.bodyGoal) {
        BodyGoal.fatLoss => GoalType.lose,
        BodyGoal.weightGain => GoalType.gain,
        _ => p.goal,
      };
      await _profile.saveProfile(p.copyWith(goal: goal, bodyFatPct: plan.startBodyFatPct));
      final startDay = DateKeys.startOfDay(plan.start);
      final hasStartWeight = _profile.getWeights().any((w) => w.dayKey == DateKeys.of(startDay));
      if (isNew && plan.startWeightKg != null && !startDay.isAfter(_today) && !hasStartWeight) {
        await _profile.logWeight(
          WeightEntry(
            dayKey: DateKeys.of(startDay),
            date: startDay.add(const Duration(hours: 7)),
            kg: plan.startWeightKg!,
            bodyFatPct: plan.startBodyFatPct,
          ),
        );
      }
    }
    _reload(message: isNew ? '${plan.name} saved. Transformation mode on.' : 'Plan updated.');
  }

  /// Deletes the active plan (and its ticks) and returns to General mode.
  Future<void> deletePlan() async {
    final plan = state.plan;
    if (plan == null) return;
    await _repo.deletePlan(plan.id);
    _reload(message: '${plan.name} deleted.');
  }

  /// Ticks / unticks [item] on the selected day (auto-logs the record).
  Future<void> toggle(PlanItem item, bool done) async {
    final plan = state.plan;
    final day = state.day ?? _today;
    if (plan == null) return;
    // Optimistic update so the tick animates instantly.
    final next = {...state.checks};
    done ? next.add(item.id) : next.remove(item.id);
    emit(state.copyWith(checks: next));
    await _toggle(plan, item, day, done);
    _reload();
  }

  /// Next-session targets for each exercise of a planned workout.
  List<OverloadSuggestion> suggestionsFor(PlanItem item) {
    final day = state.day ?? _today;
    return [
      for (final e in item.exercises)
        StrengthCalculator.suggest(e, _toggle.historyOf(e.exerciseId, before: day)),
    ];
  }

  /// Saves the sets actually done for a planned workout and ticks it.
  Future<void> logWorkout(PlanItem item, List<WorkoutSet> sets, {int? durationMin, int? rpe}) async {
    final day = state.day ?? _today;
    await _toggle.logWorkout(item, day, sets: sets, durationMin: durationMin, rpe: rpe);
    _reload(message: '${item.title} logged: ${sets.length} sets');
  }

  /// Ticks every open item of a group at once (e.g. "Morning skincare").
  Future<void> completeAll(List<PlanItem> items) async {
    for (final i in items) {
      if (!state.checks.contains(i.id)) await toggle(i, true);
    }
  }

  /// Saves the morning weigh-in for the selected day.
  Future<void> logWeight(double kg, {double? bodyFatPct}) async {
    final day = state.day ?? _today;
    final at = DateKeys.sameDay(day, _clock()) ? _clock() : day.add(const Duration(hours: 7));
    await _profile.logWeight(WeightEntry(dayKey: DateKeys.of(day), date: at, kg: kg, bodyFatPct: bodyFatPct));
    _reload(message: 'Weigh-in saved: ${kg.toStringAsFixed(1)} kg');
  }

  /// Weigh-in recorded on the selected day, if any.
  WeightEntry? weightOn(DateTime day) {
    final key = DateKeys.of(day);
    for (final w in _profile.getWeights()) {
      if (w.dayKey == key) return w;
    }
    return null;
  }

  /// Plan as shareable JSON.
  String export() => state.plan == null ? '' : _repo.exportPlan(state.plan!);

  /// Imports a plan from JSON and activates it. Returns an error or null.
  Future<String?> import(String json) async {
    try {
      final plan = _repo.importPlan(json);
      final errors = plan.validate();
      if (errors.isNotEmpty) return errors.first;
      await savePlan(plan);
      return null;
    } on FormatException catch (e) {
      return e.message;
    }
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
