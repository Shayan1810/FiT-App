import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/sleep_session.dart';
import '../../domain/repositories/sleep_repository.dart';

/// Base class of sleep events.
sealed class SleepEvent {
  const SleepEvent();
}

/// Load sessions and start watching storage.
class SleepStarted extends SleepEvent {
  const SleepStarted();
}

/// Save a sleep session.
class SleepLogged extends SleepEvent {
  const SleepLogged(this.session);
  final SleepSession session;
}

/// Delete a sleep session.
class SleepDeleted extends SleepEvent {
  const SleepDeleted(this.id);
  final String id;
}

class _SleepChanged extends SleepEvent {
  const _SleepChanged();
}

/// All sleep sessions, newest first.
class SleepState extends Equatable {
  const SleepState({this.sessions = const []});

  /// Newest first.
  final List<SleepSession> sessions;

  @override
  List<Object?> get props => [sessions];
}

/// Sleep history.
class SleepBloc extends Bloc<SleepEvent, SleepState> {
  SleepBloc(this._repo) : super(const SleepState()) {
    on<SleepStarted>((e, emit) {
      _sub ??= _repo.watch().listen((_) => add(const _SleepChanged()));
      emit(SleepState(sessions: _repo.sessions()));
    });
    on<_SleepChanged>((e, emit) => emit(SleepState(sessions: _repo.sessions())));
    on<SleepLogged>((e, emit) => _repo.save(e.session));
    on<SleepDeleted>((e, emit) => _repo.delete(e.id));
  }

  final SleepRepository _repo;
  StreamSubscription<void>? _sub;

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
