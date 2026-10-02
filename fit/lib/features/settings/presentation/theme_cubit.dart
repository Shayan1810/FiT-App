import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/storage/settings_store.dart';

/// Light / dark / follow-system appearance, persisted in [SettingsStore].
class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit(this._settings) : super(_settings.themeMode);

  final SettingsStore _settings;

  /// Changes and persists the appearance.
  Future<void> set(ThemeMode mode) async {
    emit(mode);
    await _settings.write(SettingsStore.kThemeMode, mode.name);
  }
}
