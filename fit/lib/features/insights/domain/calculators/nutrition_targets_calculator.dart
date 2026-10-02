import 'dart:math';

import '../../../profile/domain/entities/user_profile.dart';
import 'weight_trend_calculator.dart';

/// Daily intake targets.
class NutritionTargets {
  const NutritionTargets({
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.waterMl,
    required this.goalDeltaKcal,
  });

  final double kcal;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final int waterMl;

  /// Deficit (negative) or surplus (positive) applied to TDEE.
  final double goalDeltaKcal;
}

/// Turns expenditure + goal into calorie, macro, fibre and water targets.
///
/// * Morton RW et al. (2018) *Br J Sports Med* — protein ≥ 1.6 g/kg/day
///   maximises resistance-training gains.
/// * Helms ER et al. (2014) *JISSN* — higher protein (≈ 1.8–2.7 g/kg)
///   preserves lean mass during a deficit; recommended loss 0.5–1 %
///   body weight per week.
/// * Dietary Guidelines for Americans 2020–25 — fibre 14 g per 1 000 kcal;
///   fat 20–35 % of energy.
/// * EFSA (2010) — adequate water intake ≈ 35 mL/kg baseline; ACSM adds
///   0.4–0.8 L per hour of exercise.
class NutritionTargetsCalculator {
  NutritionTargetsCalculator._();

  /// Lowest calorie target FiT will ever suggest (safety floor).
  static double kcalFloor(Sex sex) => sex == Sex.male ? 1500 : 1200;

  /// Reference weight for protein when BMI ≥ 30: the weight at BMI 27,
  /// so targets aren't inflated by fat mass.
  static double proteinReferenceKg(UserProfile p) {
    if (p.bmi < 30) return p.weightKg;
    final h = p.heightCm / 100;
    return 27 * h * h;
  }

  /// Daily energy change implied by the user's goal and weekly rate.
  /// The deficit is capped at 1 % body weight/week and 25 % of TDEE; the
  /// surplus at 0.5 % body weight/week (lean-gain guidance).
  static double goalDelta(UserProfile p, double tdee) {
    final rate = p.weeklyRateKg.abs();
    switch (p.goal) {
      case GoalType.maintain:
        return 0;
      case GoalType.lose:
        final r = min(rate, p.weightKg * 0.01);
        final d = r * WeightTrendCalculator.kcalPerKg / 7;
        return -min(d, tdee * 0.25);
      case GoalType.gain:
        final r = min(rate, p.weightKg * 0.005);
        return r * WeightTrendCalculator.kcalPerKg / 7;
    }
  }

  /// Computes targets for a day whose expected expenditure is [tdee] and
  /// whose planned training lasts [trainingMinutes].
  static NutritionTargets compute({
    required UserProfile profile,
    required double tdee,
    required double bmr,
    int trainingMinutes = 0,
  }) {
    final delta = goalDelta(profile, tdee);
    final kcal = max(tdee + delta, max(kcalFloor(profile.sex), bmr * 1.0));

    final refKg = proteinReferenceKg(profile);
    final proteinPerKg = profile.goal == GoalType.lose ? 2.0 : 1.6;
    final protein = refKg * proteinPerKg;

    final fat = max(0.6 * profile.weightKg, kcal * 0.25 / 9);
    final carbs = max(0.0, (kcal - protein * 4 - fat * 9) / 4);
    final fiber = 14 * kcal / 1000;

    final waterRaw = 35 * profile.weightKg + 600 * trainingMinutes / 60;
    final water = (waterRaw / 250).round() * 250;

    return NutritionTargets(
      kcal: kcal,
      protein: protein,
      carbs: carbs,
      fat: fat,
      fiber: fiber,
      waterMl: water,
      goalDeltaKcal: delta,
    );
  }
}
