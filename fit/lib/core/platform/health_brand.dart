import 'dart:io';

/// Platform-specific names of the phone's health hub, for UI copy.
///
/// Android: Samsung Health → Health Connect. iOS: Apple Health (HealthKit).
class HealthBrand {
  HealthBrand._();

  /// True on iPhone.
  static bool get isIOS => Platform.isIOS;

  /// The app users know (where the data comes from).
  static String get app => isIOS ? 'Apple Health' : 'Samsung Health';

  /// The system hub FiT actually reads from.
  static String get hub => isIOS ? 'Apple Health' : 'Health Connect';

  /// One-time setup steps shown in Settings.
  static String get setup => isIOS
      ? 'FiT reads steps, distance, active calories, resting heart rate, sleep, workouts '
            'and weight from Apple Health (including data from your Apple Watch).\n\n'
            'Tap Connect below and allow FiT to read the data types.'
      : 'FiT reads steps, distance, active calories, resting heart rate, sleep, workouts '
            'and weight from Health Connect — Android\'s health hub, which Samsung Health syncs into.\n\n'
            'One-time setup on your phone:\n'
            '1. Samsung Health > menu > Settings > Health Connect > allow sync.\n'
            '2. Tap Connect below and allow FiT to read the data types.';
}
