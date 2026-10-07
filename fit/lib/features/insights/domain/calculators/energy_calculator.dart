import 'dart:math';

import '../../../../core/domain/data_source.dart';
import '../../../nutrition/domain/entities/nutrition_facts.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../../workout/domain/entities/workout_session.dart';

/// Daily energy expenditure split into its four components.
class EnergyBreakdown {
  const EnergyBreakdown({
    required this.bmr,
    required this.neat,
    required this.exercise,
    required this.tef,
    required this.bmrMethod,
  });

  /// Basal metabolic rate (kcal/day).
  final double bmr;

  /// Non-exercise activity (steps / daily movement), kcal.
  final double neat;

  /// Exercise activity thermogenesis (workouts), kcal.
  final double exercise;

  /// Thermic effect of food, kcal.
  final double tef;

  /// "Mifflin–St Jeor" or "Katch–McArdle".
  final String bmrMethod;

  /// Total daily energy expenditure.
  double get total => bmr + neat + exercise + tef;
}

/// Energy-expenditure formulas. All functions are pure and static.
///
/// References:
/// * Mifflin MD et al. (1990) *Am J Clin Nutr* 51:241 — BMR equation.
/// * Katch & McArdle (1996) — BMR from lean body mass.
/// * ACSM's Guidelines for Exercise Testing & Prescription — metabolic
///   equations for walking (0.1 mL O₂/kg/m) and running (0.2 mL O₂/kg/m).
/// * Ainsworth BE et al. (2011) Compendium of Physical Activities — METs.
/// * Westerterp KR (2004) *Nutr Metab* 1:5 — thermic effect of food.
class EnergyCalculator {
  EnergyCalculator._();

  /// Mifflin–St Jeor BMR: 10·kg + 6.25·cm − 5·age + 5 (♂) / −161 (♀).
  static double bmrMifflin({
    required Sex sex,
    required double weightKg,
    required double heightCm,
    required int age,
  }) => 10 * weightKg + 6.25 * heightCm - 5 * age + (sex == Sex.male ? 5 : -161);

  /// Katch–McArdle BMR: 370 + 21.6 · lean body mass (kg).
  static double bmrKatchMcArdle({required double leanMassKg}) => 370 + 21.6 * leanMassKg;

  /// Picks Katch–McArdle when body-fat % is known (more accurate for
  /// lean/muscular people), otherwise Mifflin–St Jeor. The profile's
  /// metabolism adjustment (±30 % max) is applied on top.
  static ({double bmr, String method}) bmr(UserProfile p, {double? weightKg}) {
    final w = weightKg ?? p.weightKg;
    final adj = 1 + p.bmrAdjustPct.clamp(-30, 30) / 100;
    final note = p.bmrAdjustPct == 0
        ? ''
        : ' ${p.bmrAdjustPct > 0 ? '+' : ''}${p.bmrAdjustPct.toStringAsFixed(0)} %';
    if (p.bodyFatPct != null && p.bodyFatPct! > 3 && p.bodyFatPct! < 60) {
      final lbm = w * (1 - p.bodyFatPct! / 100);
      return (bmr: bmrKatchMcArdle(leanMassKg: lbm) * adj, method: 'Katch–McArdle$note');
    }
    return (
      bmr: bmrMifflin(sex: p.sex, weightKg: w, heightCm: p.heightCm, age: p.age) * adj,
      method: 'Mifflin–St Jeor$note',
    );
  }

  /// Stride length in metres ≈ height × 0.415 (♂) or 0.413 (♀).
  static double strideMeters({required double heightCm, required Sex sex}) =>
      heightCm / 100 * (sex == Sex.male ? 0.415 : 0.413);

  /// Distance in km covered by [steps].
  static double stepsToKm(int steps, {required double heightCm, required Sex sex}) =>
      steps * strideMeters(heightCm: heightCm, sex: sex) / 1000;

  /// Net walking energy above rest (kcal).
  ///
  /// ACSM walking equation: horizontal cost 0.1 mL O₂·kg⁻¹·m⁻¹ = 100 mL/kg/km,
  /// × ~5 kcal per litre O₂ ⇒ **0.5 kcal per kg per km**.
  static double walkingKcal({required double km, required double weightKg}) => 0.5 * weightKg * km;

  /// Net running energy above rest: 0.2 mL O₂/kg/m ⇒ **1.0 kcal/kg/km**.
  static double runningKcal({required double km, required double weightKg}) => 1.0 * weightKg * km;

  /// MET value for a session (Compendium of Physical Activities 2011).
  /// Intensity within a type is chosen from the session RPE.
  static double metFor(WorkoutSession s) {
    final hard = s.rpe >= 7;
    final easy = s.rpe <= 4;
    switch (s.type) {
      case WorkoutType.strength:
        return easy ? 3.5 : (hard ? 6.0 : 5.0); // 02054 / 02050 / 02052
      case WorkoutType.cardio:
        return easy ? 4.0 : (hard ? 8.8 : 7.0);
      case WorkoutType.hiit:
        return 8.0; // circuit training, vigorous
      case WorkoutType.sport:
        return easy ? 5.0 : (hard ? 8.0 : 7.0);
      case WorkoutType.mobility:
        return 2.5; // hatha yoga / stretching
      case WorkoutType.walk:
        return _metFromSpeed(s, walking: true) ?? 3.5;
      case WorkoutType.run:
        return _metFromSpeed(s, walking: false) ?? 9.8;
    }
  }

  /// ACSM: VO₂ = 0.1·v + 3.5 (walk) or 0.2·v + 3.5 (run), v in m/min.
  static double? _metFromSpeed(WorkoutSession s, {required bool walking}) {
    if (s.distanceKm == null || s.durationMin <= 0) return null;
    final v = s.distanceKm! * 1000 / s.durationMin;
    final vo2 = (walking ? 0.1 : 0.2) * v + 3.5;
    return vo2 / 3.5;
  }

  /// Net energy of a workout above resting: (MET − 1) × kg × hours.
  /// Subtracting 1 MET avoids double-counting BMR, which is already in TDEE.
  /// If a wearable measured the session, its number is used instead.
  static double workoutKcal(WorkoutSession s, {required double weightKg}) {
    if (s.deviceKcal != null && s.deviceKcal! > 0) return s.deviceKcal!;
    return max(0, metFor(s) - 1) * weightKg * (s.durationMin / 60);
  }

  /// Thermic effect of food from macro composition:
  /// protein 25 %, carbohydrate 7.5 %, fat 1.5 % of their energy
  /// (mid-points of Westerterp's ranges 20–30 / 5–10 / 0–3 %).
  static double tef(NutritionFacts f) => f.protein * 4 * 0.25 + f.carbs * 4 * 0.075 + f.fat * 9 * 0.015;

  /// Builds the full breakdown for one day.
  ///
  /// Activity rule (prevents double counting):
  /// * if the device reported active energy → NEAT = device active kcal,
  ///   and only *manual* workouts are added on top;
  /// * otherwise → NEAT = walking energy from steps, and all workouts are
  ///   added except Health-Connect walks/runs (their steps are already
  ///   in the step count);
  /// * a logged *walk* is never added on top of a day that has a step count
  ///   or device active energy — those already contain the walk.
  static EnergyBreakdown daily({
    required UserProfile profile,
    required int steps,
    double? distanceKm,
    double? deviceActiveKcal,
    required List<WorkoutSession> workouts,
    required NutritionFacts intake,
    double? fallbackIntakeKcal,
  }) {
    final b = bmr(profile);
    final w = profile.weightKg;

    double neat;
    double exercise = 0;
    if (deviceActiveKcal != null && deviceActiveKcal > 0) {
      neat = deviceActiveKcal;
      for (final s in workouts.where(
        (s) => s.source != DataSource.healthConnect && s.type != WorkoutType.walk,
      )) {
        exercise += workoutKcal(s, weightKg: w);
      }
    } else {
      final km = distanceKm ?? stepsToKm(steps, heightCm: profile.heightCm, sex: profile.sex);
      neat = walkingKcal(km: km, weightKg: w);
      for (final s in workouts) {
        final stepBased =
            (s.source == DataSource.healthConnect &&
                (s.type == WorkoutType.walk || s.type == WorkoutType.run)) ||
            (s.type == WorkoutType.walk && steps > 0);
        if (!stepBased) exercise += workoutKcal(s, weightKg: w);
      }
    }

    final tefKcal = intake.kcal > 0
        ? tef(intake)
        : 0.10 * (fallbackIntakeKcal ?? 0); // assume 10 % if nothing logged
    return EnergyBreakdown(bmr: b.bmr, neat: neat, exercise: exercise, tef: tefKcal, bmrMethod: b.method);
  }
}
