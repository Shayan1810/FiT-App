import 'dart:math';

import '../../../profile/domain/entities/user_profile.dart';

/// Body-composition helpers (replaces the original "Body Fat Calculator" page).
///
/// * U.S. Navy circumference method — Hodgdon & Beckett (1984).
/// * WHO BMI classification.
class BodyCompositionCalculator {
  BodyCompositionCalculator._();

  /// Navy body-fat % from circumferences in cm (hip needed for women).
  ///
  /// ♂: 495 / (1.0324 − 0.19077·log10(waist − neck) + 0.15456·log10(height)) − 450
  /// ♀: 495 / (1.29579 − 0.35004·log10(waist + hip − neck) + 0.22100·log10(height)) − 450
  static double? navyBodyFat({
    required Sex sex,
    required double heightCm,
    required double neckCm,
    required double waistCm,
    double? hipCm,
  }) {
    double log10(double x) => log(x) / ln10;
    if (sex == Sex.male) {
      if (waistCm - neckCm <= 0) return null;
      return 495 / (1.0324 - 0.19077 * log10(waistCm - neckCm) + 0.15456 * log10(heightCm)) - 450;
    }
    if (hipCm == null || waistCm + hipCm - neckCm <= 0) return null;
    return 495 / (1.29579 - 0.35004 * log10(waistCm + hipCm - neckCm) + 0.22100 * log10(heightCm)) - 450;
  }

  /// WHO BMI category label.
  static String bmiCategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Healthy';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }
}
