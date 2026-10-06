import 'package:flutter/material.dart' show ThemeMode;
import 'package:hive_ce/hive.dart';

/// Small key/value store for app settings and counters (one Hive box).
///
/// Keys are listed as constants so every setting is discoverable here.
class SettingsStore {
  SettingsStore(this._box);

  final Box<dynamic> _box;

  static const String kGeminiApiKey = 'gemini_api_key';
  static const String kGeminiModel = 'gemini_model';
  static const String kOnboarded = 'onboarded';
  static const String kThemeMode = 'theme_mode';
  static const String kHealthConnected = 'health_connected';
  static const String kLastHealthSync = 'last_health_sync';
  static const String kAppMode = 'app_mode';
  static const String kActivePlan = 'active_plan';
  static const String kStatsPrefix = 'stat_';

  /// API key passed at build time with `--dart-define=GEMINI_API_KEY=...`.
  static const String _buildTimeKey = String.fromEnvironment('GEMINI_API_KEY');

  /// Default Gemini model; can be changed in Settings without a rebuild.
  static const String defaultModel = 'gemini-2.5-flash';

  /// Reads a raw value.
  T? read<T>(String key) => _box.get(key) as T?;

  /// Writes a raw value.
  Future<void> write(String key, Object? value) => _box.put(key, value);

  /// The Gemini key: user-entered value first, then the build-time define.
  String? get geminiApiKey {
    final stored = (_box.get(kGeminiApiKey) as String?)?.trim();
    if (stored != null && stored.isNotEmpty) return stored;
    return _buildTimeKey.isEmpty ? null : _buildTimeKey;
  }

  /// The Gemini model id currently configured.
  String get geminiModel => (_box.get(kGeminiModel) as String?)?.trim().isNotEmpty == true
      ? _box.get(kGeminiModel) as String
      : defaultModel;

  /// Saved appearance (defaults to following the system setting).
  ThemeMode get themeMode =>
      ThemeMode.values.firstWhere((m) => m.name == _box.get(kThemeMode), orElse: () => ThemeMode.system);

  /// Whether the onboarding flow has been completed.
  bool get onboarded => _box.get(kOnboarded) == true;

  /// Whether the user connected Health Connect at least once.
  bool get healthConnected => _box.get(kHealthConnected) == true;

  /// Time of the last successful Health Connect sync.
  DateTime? get lastHealthSync {
    final ms = _box.get(kLastHealthSync) as int?;
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Increments the named counter (used for query success statistics).
  Future<void> increment(String counter, [int by = 1]) =>
      _box.put('$kStatsPrefix$counter', counterValue(counter) + by);

  /// Current value of the named counter.
  int counterValue(String counter) => (_box.get('$kStatsPrefix$counter') as int?) ?? 0;
}
