import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/storage/settings_store.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../health_sync/domain/health_sync_repository.dart';
import '../../domain/entities/daily_activity.dart';
import '../../domain/repositories/activity_repository.dart';
import '../../../../core/platform/health_brand.dart';

/// State of the steps / Health Connect cubit.
class ActivityState extends Equatable {
  const ActivityState({
    this.today,
    this.week = const [],
    this.link = HealthLinkStatus.notAuthorized,
    this.syncing = false,
    this.lastSync,
    this.message,
  });

  final DailyActivity? today;

  /// Last 7 days (oldest first); null where nothing was recorded.
  final List<DailyActivity?> week;
  final HealthLinkStatus link;
  final bool syncing;
  final DateTime? lastSync;

  /// One-shot user message (sync result / error).
  final String? message;

  ActivityState copyWith({
    DailyActivity? today,
    List<DailyActivity?>? week,
    HealthLinkStatus? link,
    bool? syncing,
    DateTime? lastSync,
    String? message,
  }) => ActivityState(
    today: today ?? this.today,
    week: week ?? this.week,
    link: link ?? this.link,
    syncing: syncing ?? this.syncing,
    lastSync: lastSync ?? this.lastSync,
    message: message,
  );

  @override
  List<Object?> get props => [today, week, link, syncing, lastSync, message];
}

/// Steps / walking data and the Samsung Health (Health Connect) link.
class ActivityCubit extends Cubit<ActivityState> {
  ActivityCubit({
    required ActivityRepository repo,
    required HealthSyncRepository health,
    required SettingsStore settings,
  }) : _repo = repo,
       _health = health,
       _settings = settings,
       super(const ActivityState());

  final ActivityRepository _repo;
  final HealthSyncRepository _health;
  final SettingsStore _settings;
  StreamSubscription<void>? _sub;

  /// Loads local data, checks the link, and syncs if connected.
  Future<void> start() async {
    _sub ??= _repo.watch().listen((_) => _reload());
    _reload();
    final link = await _health.status();
    emit(state.copyWith(link: link, lastSync: _settings.lastHealthSync));
    if (link == HealthLinkStatus.connected) await sync(quiet: true);
  }

  void _reload() {
    if (isClosed) return;
    final days = DateKeys.lastNDays(DateTime.now(), 7);
    final map = _repo.forDays(days.map(DateKeys.of));
    emit(
      state.copyWith(
        today: map[DateKeys.of(DateTime.now())],
        week: [for (final d in days) map[DateKeys.of(d)]],
      ),
    );
  }

  /// Requests Health Connect permissions, then syncs 28 days of history.
  Future<void> connect() async {
    final link = await _health.status();
    if (link == HealthLinkStatus.needsInstall) {
      await _health.install();
      return;
    }
    if (link == HealthLinkStatus.unavailable) {
      emit(state.copyWith(link: link, message: '${HealthBrand.hub} is not available on this device.'));
      return;
    }
    final ok = await _health.connect();
    final now = await _health.status();
    emit(state.copyWith(link: now, message: ok ? null : 'Permission was not granted.'));
    if (now == HealthLinkStatus.connected) await sync(days: 28);
  }

  /// Pulls recent data from Health Connect.
  Future<void> sync({int days = 7, bool quiet = false}) async {
    if (state.syncing) return;
    emit(state.copyWith(syncing: true));
    final report = await _health.sync(days: days);
    emit(
      state.copyWith(
        syncing: false,
        lastSync: _settings.lastHealthSync,
        message: quiet && report.ok ? null : report.toString(),
      ),
    );
  }

  /// Saves a manually typed step count for [day].
  Future<void> setManualSteps(DateTime day, int steps, {double? distanceKm}) {
    final key = DateKeys.of(day);
    final existing = _repo.forDay(key);
    return _repo.save(
      existing == null
          ? DailyActivity(dayKey: key, steps: steps, distanceKm: distanceKm)
          : DailyActivity(
              dayKey: key,
              steps: steps,
              distanceKm: distanceKm,
              activeKcal: existing.activeKcal,
              restingHr: existing.restingHr,
            ),
    );
  }

  /// Activity for any day (for the history editor).
  DailyActivity? dayRecord(DateTime day) => _repo.forDay(DateKeys.of(day));

  /// Removes a manual override and re-syncs that day from Samsung Health.
  Future<void> revertToDevice(DateTime day) async {
    await _repo.delete(DateKeys.of(day));
    if (state.link == HealthLinkStatus.connected) {
      await sync(
        days: DateKeys.startOfDay(DateTime.now()).difference(DateKeys.startOfDay(day)).inDays + 1,
        quiet: true,
      );
    }
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
