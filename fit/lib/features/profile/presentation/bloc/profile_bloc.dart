import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/storage/settings_store.dart';
import '../../../../core/utils/date_utils.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/weight_entry.dart';
import '../../domain/repositories/profile_repository.dart';

// ── Events ──────────────────────────────────────────────────────────────
/// Base class of profile events.
sealed class ProfileEvent {
  const ProfileEvent();
}

/// Load the profile and start watching storage.
class ProfileStarted extends ProfileEvent {
  const ProfileStarted();
}

/// Saves the profile (also used at the end of onboarding).
class ProfileSaved extends ProfileEvent {
  const ProfileSaved(this.profile, {this.completeOnboarding = false});
  final UserProfile profile;
  final bool completeOnboarding;
}

/// Record a weigh-in.
class WeightLogged extends ProfileEvent {
  const WeightLogged(this.kg, this.date, {this.bodyFatPct});
  final double kg;
  final DateTime date;
  final double? bodyFatPct;
}

/// Remove the weigh-in of a day.
class WeightDeleted extends ProfileEvent {
  const WeightDeleted(this.dayKey);
  final String dayKey;
}

class _ProfileChanged extends ProfileEvent {
  const _ProfileChanged();
}

// ── State ───────────────────────────────────────────────────────────────
/// Profile, weight history and whether storage was read.
class ProfileState extends Equatable {
  const ProfileState({this.profile, this.weights = const [], this.loaded = false});

  final UserProfile? profile;

  /// Oldest first.
  final List<WeightEntry> weights;
  final bool loaded;

  @override
  List<Object?> get props => [profile, weights, loaded];
}

// ── Bloc ────────────────────────────────────────────────────────────────
/// Owns the user profile and weight log.
class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  ProfileBloc(this._repo, this._settings) : super(const ProfileState()) {
    on<ProfileStarted>((e, emit) {
      _sub ??= _repo.watch().listen((_) => add(const _ProfileChanged()));
      _emitCurrent(emit);
    });
    on<_ProfileChanged>((e, emit) => _emitCurrent(emit));
    on<ProfileSaved>(_onSaved);
    on<WeightLogged>(_onWeight);
    on<WeightDeleted>((e, emit) => _repo.deleteWeight(e.dayKey));
  }

  final ProfileRepository _repo;
  final SettingsStore _settings;
  StreamSubscription<void>? _sub;

  void _emitCurrent(Emitter<ProfileState> emit) =>
      emit(ProfileState(profile: _repo.getProfile(), weights: _repo.getWeights(), loaded: true));

  Future<void> _onSaved(ProfileSaved e, Emitter<ProfileState> emit) async {
    final previous = _repo.getProfile();
    await _repo.saveProfile(e.profile);
    // A changed weight on the profile form is also a weigh-in for today.
    if (previous == null || previous.weightKg != e.profile.weightKg) {
      final now = DateTime.now();
      await _repo.logWeight(
        WeightEntry(
          dayKey: DateKeys.of(now),
          date: now,
          kg: e.profile.weightKg,
          bodyFatPct: e.profile.bodyFatPct,
        ),
      );
    }
    if (e.completeOnboarding) await _settings.write(SettingsStore.kOnboarded, true);
    _emitCurrent(emit);
  }

  Future<void> _onWeight(WeightLogged e, Emitter<ProfileState> emit) => _repo.logWeight(
    WeightEntry(dayKey: DateKeys.of(e.date), date: e.date, kg: e.kg, bodyFatPct: e.bodyFatPct),
  );

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
