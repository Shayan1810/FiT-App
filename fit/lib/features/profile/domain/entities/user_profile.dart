import 'package:equatable/equatable.dart';

import '../../../../core/utils/date_utils.dart';

/// Biological sex, used only by sex-specific formulas (BMR, stride length).
enum Sex { male, female }

/// What the user wants their body weight to do.
enum GoalType { lose, maintain, gain }

/// The person using the app.
class UserProfile extends Equatable {
  const UserProfile({
    required this.name,
    required this.sex,
    required this.dateOfBirth,
    required this.heightCm,
    required this.weightKg,
    this.bodyFatPct,
    this.goal = GoalType.maintain,
    this.weeklyRateKg = 0.0,
    this.photoPath,
    this.bmrAdjustPct = 0,
  });

  final String name;
  final Sex sex;
  final DateTime dateOfBirth;
  final double heightCm;

  /// Latest known body weight (kept in sync with the newest WeightEntry).
  final double weightKg;

  /// Optional body-fat %; when present BMR uses Katch–McArdle.
  final double? bodyFatPct;
  final GoalType goal;

  /// Desired weekly change in kg (always positive; direction comes from [goal]).
  final double weeklyRateKg;
  final String? photoPath;

  /// Manual metabolism adjustment in % applied to BMR (e.g. −10 for a
  /// medication or thyroid condition that lowers resting energy use).
  final double bmrAdjustPct;

  /// Age in whole years today.
  int get age => DateKeys.ageFrom(dateOfBirth);

  /// Body-mass index, kg/m².
  double get bmi => weightKg / ((heightCm / 100) * (heightCm / 100));

  /// Lean body mass in kg when body fat is known.
  double? get leanMassKg => bodyFatPct == null ? null : weightKg * (1 - bodyFatPct! / 100);

  /// First name for friendly greetings.
  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  UserProfile copyWith({
    String? name,
    Sex? sex,
    DateTime? dateOfBirth,
    double? heightCm,
    double? weightKg,
    double? bodyFatPct,
    bool clearBodyFat = false,
    GoalType? goal,
    double? weeklyRateKg,
    String? photoPath,
    double? bmrAdjustPct,
  }) {
    return UserProfile(
      name: name ?? this.name,
      sex: sex ?? this.sex,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      bodyFatPct: clearBodyFat ? null : (bodyFatPct ?? this.bodyFatPct),
      goal: goal ?? this.goal,
      weeklyRateKg: weeklyRateKg ?? this.weeklyRateKg,
      photoPath: photoPath ?? this.photoPath,
      bmrAdjustPct: bmrAdjustPct ?? this.bmrAdjustPct,
    );
  }

  @override
  List<Object?> get props => [
    name,
    sex,
    dateOfBirth,
    heightCm,
    weightKg,
    bodyFatPct,
    goal,
    weeklyRateKg,
    photoPath,
    bmrAdjustPct,
  ];
}
