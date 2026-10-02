import 'package:fit/features/insights/domain/calculators/activity_calculator.dart';
import 'package:fit/features/insights/domain/calculators/body_composition_calculator.dart';
import 'package:fit/features/insights/domain/calculators/energy_calculator.dart';
import 'package:fit/features/insights/domain/calculators/nutrition_targets_calculator.dart';
import 'package:fit/features/insights/domain/calculators/recovery_calculator.dart';
import 'package:fit/features/insights/domain/calculators/sleep_calculator.dart';
import 'package:fit/features/insights/domain/calculators/training_load_calculator.dart';
import 'package:fit/features/insights/domain/calculators/weight_trend_calculator.dart';
import 'package:fit/features/nutrition/domain/entities/nutrition_facts.dart';
import 'package:fit/features/profile/domain/entities/user_profile.dart';
import 'package:fit/features/profile/domain/entities/weight_entry.dart';
import 'package:fit/features/sleep/domain/entities/sleep_session.dart';
import 'package:fit/features/workout/domain/entities/exercise.dart';
import 'package:fit/features/workout/domain/entities/workout_session.dart';
import 'package:fit/core/utils/date_utils.dart';
import 'package:flutter_test/flutter_test.dart';

UserProfile person({double kg = 80, double? bf, GoalType goal = GoalType.maintain, double rate = 0}) =>
    UserProfile(
      name: 'Test',
      sex: Sex.male,
      dateOfBirth: DateTime(DateTime.now().year - 30, 1, 1),
      heightCm: 180,
      weightKg: kg,
      bodyFatPct: bf,
      goal: goal,
      weeklyRateKg: rate,
    );

void main() {
  group('EnergyCalculator', () {
    test('Mifflin–St Jeor reference values', () {
      // 10·80 + 6.25·180 − 5·30 + 5 = 1780
      expect(EnergyCalculator.bmrMifflin(sex: Sex.male, weightKg: 80, heightCm: 180, age: 30), 1780);
      // 10·60 + 6.25·165 − 5·25 − 161 = 1345.25
      expect(EnergyCalculator.bmrMifflin(sex: Sex.female, weightKg: 60, heightCm: 165, age: 25), 1345.25);
    });

    test('Katch–McArdle used when body fat known', () {
      final r = EnergyCalculator.bmr(person(bf: 20));
      expect(r.method, 'Katch–McArdle');
      expect(r.bmr, closeTo(370 + 21.6 * 64, 1e-9)); // LBM 64 kg
    });

    test('walking 0.5 and running 1.0 kcal/kg/km (ACSM)', () {
      expect(EnergyCalculator.walkingKcal(km: 5, weightKg: 70), 175);
      expect(EnergyCalculator.runningKcal(km: 5, weightKg: 70), 350);
      expect(EnergyCalculator.stepsToKm(10000, heightCm: 180, sex: Sex.male), closeTo(7.47, 0.01));
    });

    test('net MET energy subtracts resting 1 MET', () {
      final s = WorkoutSession(
        id: 'a',
        start: DateTime(2025),
        title: 'x',
        type: WorkoutType.strength,
        durationMin: 60,
        rpe: 8,
      );
      // (6.0 − 1) × 80 × 1 h = 400
      expect(EnergyCalculator.workoutKcal(s, weightKg: 80), 400);
    });

    test('running MET from speed (ACSM): 10 km/h → 0.2·166.7+3.5 = 36.8 mL ⇒ 10.5 MET', () {
      final s = WorkoutSession(
        id: 'r',
        start: DateTime(2025),
        title: 'run',
        type: WorkoutType.run,
        durationMin: 60,
        rpe: 6,
        distanceKm: 10,
      );
      expect(EnergyCalculator.metFor(s), closeTo(10.52, 0.01));
    });

    test('TEF from macros (25 / 7.5 / 1.5 %)', () {
      const f = NutritionFacts(kcal: 0, protein: 100, carbs: 200, fat: 50);
      expect(EnergyCalculator.tef(f), closeTo(100 + 60 + 6.75, 1e-9));
    });

    test('device active energy replaces step estimate; HC walks not double-counted', () {
      final p = person();
      final hcWalk = WorkoutSession(
        id: 'w',
        start: DateTime(2025),
        title: 'walk',
        type: WorkoutType.walk,
        durationMin: 30,
        rpe: 3,
        source: DataSource.healthConnect,
        deviceKcal: 120,
      );
      final e1 = EnergyCalculator.daily(
        profile: p,
        steps: 8000,
        workouts: [hcWalk],
        intake: NutritionFacts.zero,
      );
      expect(e1.exercise, 0); // walk already inside the steps
      final e2 = EnergyCalculator.daily(
        profile: p,
        steps: 8000,
        deviceActiveKcal: 450,
        workouts: [hcWalk],
        intake: NutritionFacts.zero,
      );
      expect(e2.neat, 450);
      expect(e2.exercise, 0);
    });
  });

  group('WeightTrendCalculator', () {
    test('EMA smooths noise and tracks a steady loss', () {
      final start = DateTime(2025, 1, 1);
      final entries = [
        for (var i = 0; i < 28; i++)
          WeightEntry(
            dayKey: DateKeys.of(start.add(Duration(days: i))),
            date: start.add(Duration(days: i)),
            kg: 80 - i * 0.07 + (i.isEven ? 0.6 : -0.6), // −0.49 kg/week + noise
          ),
      ];
      final t = WeightTrendCalculator.ema(entries);
      expect(t, hasLength(28));
      final rate = WeightTrendCalculator.weeklyRate(t)!;
      expect(rate, lessThan(0));
      expect(rate, greaterThan(-0.8));
    });

    test('adaptive TDEE from energy balance', () {
      final start = DateTime(2025, 1, 1);
      // Perfectly linear trend: −0.5 kg over 14 days at 2000 kcal/day.
      final trend = [
        for (var i = 0; i <= 14; i++) TrendPoint(start.add(Duration(days: i)), 0, 80 - i * 0.5 / 14),
      ];
      final r = WeightTrendCalculator.adaptiveTdee(dailyIntakeKcal: List.filled(14, 2000), trend: trend)!;
      // 2000 + 0.5 × 7700 / 14 = 2275
      expect(r.tdee, closeTo(2275, 0.5));
    });
  });

  group('TrainingLoadCalculator', () {
    test('Epley 1RM', () {
      expect(TrainingLoadCalculator.epley1Rm(100, 1), 100);
      expect(TrainingLoadCalculator.epley1Rm(100, 10), closeTo(133.33, 0.01));
    });

    test('ACWR zones and a spike', () {
      final today = DateTime(2025, 3, 28, 20);
      WorkoutSession s(int daysAgo, int min, int rpe) => WorkoutSession(
        id: '$daysAgo',
        start: today.subtract(Duration(days: daysAgo)),
        title: 'x',
        type: WorkoutType.strength,
        durationMin: min,
        rpe: rpe,
        sets: const [
          WorkoutSet(
            exerciseId: 'e',
            exerciseName: 'Squat',
            muscle: MuscleGroup.legs,
            reps: 5,
            weightKg: 100,
          ),
        ],
      );
      // Weeks 1–3: 2 × 60 min @ RPE 6 ; this week: 5 × 90 min @ RPE 8.
      final sessions = [
        for (final d in [8, 10, 15, 17, 22, 24]) s(d, 60, 6),
        for (final d in [0, 1, 2, 4, 5]) s(d, 90, 8),
      ];
      final sum = TrainingLoadCalculator.summarize(sessions, today);
      expect(sum.acuteLoad, 5 * 90 * 8);
      expect(sum.acwr, greaterThan(1.5));
      expect(sum.zone, AcwrZone.danger);
      expect(sum.weeklySetsByMuscle[MuscleGroup.legs], 5);
      expect(TrainingLoadCalculator.zoneFor(1.0), AcwrZone.sweetSpot);
      expect(TrainingLoadCalculator.zoneFor(0.6), AcwrZone.detraining);
    });

    WorkoutSession lift(DateTime start, {int min = 20, int rpe = 5, double kg = 20, int reps = 10}) =>
        WorkoutSession(
          id: '${start.millisecondsSinceEpoch}',
          start: start,
          title: 'Deadlift',
          type: WorkoutType.strength,
          durationMin: min,
          rpe: rpe,
          sets: [
            WorkoutSet(
              exerciseId: 'deadlift',
              exerciseName: 'Deadlift',
              muscle: MuscleGroup.back,
              reps: reps,
              weightKg: kg,
            ),
          ],
        );

    test('a first light session is never an injury risk (baseline gating)', () {
      final now = DateTime(2025, 3, 28, 20);
      final sum = TrainingLoadCalculator.summarize([lift(now)], now);
      expect(sum.acwr, isNull);
      expect(sum.zone, AcwrZone.unknown);
      expect(sum.hasBaseline, isFalse);
      // A whole first week of training is still "building a baseline".
      final week = [for (var d = 0; d < 7; d++) lift(now.subtract(Duration(days: d)), min: 60, rpe: 8)];
      expect(TrainingLoadCalculator.summarize(week, now).zone, AcwrZone.unknown);
    });

    test('small absolute loads are never flagged, even with a high ratio', () {
      final now = DateTime(2025, 3, 28, 20);
      // Light baseline (2 × 10 min/week for 4 weeks), then a slightly bigger week.
      final sessions = [
        for (final d in [8, 11, 15, 18, 22, 25, 29, 32])
          lift(now.subtract(Duration(days: d)), min: 10, rpe: 3),
        for (final d in [0, 2, 4]) lift(now.subtract(Duration(days: d)), min: 30, rpe: 6),
      ];
      final sum = TrainingLoadCalculator.summarize(sessions, now);
      expect(sum.hasBaseline, isTrue);
      expect(sum.acwr, greaterThan(1.5));
      expect(sum.acuteLoad, lessThan(TrainingLoadCalculator.minRiskWeeklyLoad));
      expect(sum.zone, AcwrZone.sweetSpot);
    });

    test('poor recovery factor slows muscle recovery', () {
      final now = DateTime(2025, 3, 28, 20);
      final sum = TrainingLoadCalculator.summarize([lift(now.subtract(const Duration(hours: 48)))], now);
      final normal = TrainingLoadCalculator.muscleRecovery(sum, now)[MuscleGroup.back]!;
      final slow = TrainingLoadCalculator.muscleRecovery(sum, now, factor: 0.6)[MuscleGroup.back]!;
      expect(normal, closeTo(48 / 72, 1e-9));
      expect(slow, closeTo(48 / 120, 1e-9));
    });
  });

  group('Recovery factor', () {
    test('well rested, well fed, young → ~1.0', () {
      final r = RecoveryCalculator.recoveryFactor(sleepRatio: 1, energyRatio: 1, proteinPerKg: 1.8, age: 25);
      expect(r.factor, closeTo(1.0, 1e-9));
    });

    test('short sleep, under-eating, low protein, heavy load and age compound', () {
      final r = RecoveryCalculator.recoveryFactor(
        sleepRatio: 0.7, // ~5.5 h of an 8 h need
        energyRatio: 0.65,
        proteinPerKg: 0.8,
        age: 50,
        load48h: 2000,
        chronicDaily: 300,
      );
      expect(r.parts.map((p) => p.$1), ['Sleep', 'Energy', 'Protein', 'Age', 'Training damage']);
      for (final p in r.parts) {
        expect(p.$2, lessThan(1.0), reason: p.$1);
      }
      expect(r.factor, lessThan(0.6));
      expect(r.factor, greaterThanOrEqualTo(0.4));
    });

    test('each input alone slows recovery', () {
      double f({double? s, double? e, double? p, int? a, double l = 0}) => RecoveryCalculator.recoveryFactor(
        sleepRatio: s,
        energyRatio: e,
        proteinPerKg: p,
        age: a,
        load48h: l,
        chronicDaily: 300,
      ).factor;
      expect(f(s: 0.75), lessThan(f(s: 1)));
      expect(f(e: 0.7), lessThan(f(e: 1)));
      expect(f(p: 0.8), lessThan(f(p: 1.6)));
      expect(f(a: 60), lessThan(f(a: 30)));
      expect(f(l: 1800), lessThan(f(l: 300)));
    });

    test('readiness drops when under-fuelled', () {
      RecoveryScore r(double energy, double protein) => RecoveryCalculator.compute(
        sleepScore: 85,
        debt7Minutes: 0,
        zone: AcwrZone.sweetSpot,
        energyRatio: energy,
        proteinPerKg: protein,
      );
      expect(r(0.6, 0.7).score, lessThan(r(1.0, 1.8).score));
      expect(r(0.6, 0.7).factor, lessThan(r(1.0, 1.8).factor));
    });
  });

  group('SleepCalculator', () {
    test('need by age (NSF)', () {
      expect(SleepCalculator.needMinutes(16), 540);
      expect(SleepCalculator.needMinutes(30), 480);
      expect(SleepCalculator.needMinutes(70), 450);
    });

    test('debt, regularity and bedtime', () {
      final today = DateTime(2025, 3, 10, 9);
      final sessions = [
        for (var i = 0; i < 7; i++)
          SleepSession(
            id: '$i',
            start: DateTime(2025, 3, 10 - i - 1, 23, 30),
            end: DateTime(2025, 3, 10 - i, 6, 30), // 7 h each
          ),
      ];
      final s = SleepCalculator.summarize(sessions, today, 30);
      expect(s.lastNightMinutes, 420);
      expect(s.debt7Minutes, 7 * 60); // 1 h short × 7
      expect(s.midpointSdMinutes, closeTo(0, 1e-9));
      expect(s.typicalWake, 6 * 60 + 30);
      final bed = SleepCalculator.recommendBedtime(s, today);
      // wake 06:30 − 8 h need − 15 min latency − 30 min (debt > 2 h) = 21:45
      expect(DateKeys.clock(bed.bedtime), '21:45');
    });

    test('score rewards meeting need', () {
      expect(SleepCalculator.score(minutes: 480, need: 480, sdMinutes: 20, quality: 5), 100);
      expect(SleepCalculator.score(minutes: 240, need: 480, sdMinutes: 20, quality: 5), lessThan(80));
    });
  });

  group('NutritionTargetsCalculator', () {
    test('deficit for 0.5 kg/week ≈ 550 kcal; protein 2 g/kg when cutting', () {
      final p = person(goal: GoalType.lose, rate: 0.5);
      final t = NutritionTargetsCalculator.compute(profile: p, tdee: 2800, bmr: 1780);
      expect(t.goalDeltaKcal, closeTo(-550, 0.1));
      expect(t.kcal, closeTo(2250, 0.1));
      expect(t.protein, 160);
      expect(t.fat * 9 + t.protein * 4 + t.carbs * 4, closeTo(t.kcal, 0.5));
      expect(t.fiber, closeTo(31.5, 0.01));
    });

    test('never below the safety floor', () {
      final p = person(kg: 50, goal: GoalType.lose, rate: 1.0);
      final t = NutritionTargetsCalculator.compute(profile: p, tdee: 1600, bmr: 1300);
      expect(t.kcal, greaterThanOrEqualTo(1500));
    });
  });

  group('ActivityCalculator', () {
    test('progressive step target capped by age plateau', () {
      expect(ActivityCalculator.stepTarget(avg7Steps: 6200, age: 25), 7000);
      expect(ActivityCalculator.stepTarget(avg7Steps: 12000, age: 25), 10000);
      expect(ActivityCalculator.stepTarget(avg7Steps: 7600, age: 65), 8000);
      expect(ActivityCalculator.stepTarget(avg7Steps: 2000, age: 25), 5000);
    });
  });

  group('RecoveryCalculator', () {
    test('missing inputs renormalise; elevated RHR lowers score', () {
      final good = RecoveryCalculator.compute(
        sleepScore: 90,
        debt7Minutes: 0,
        zone: AcwrZone.sweetSpot,
        acwr: 1.0,
      );
      expect(good.readiness, Readiness.primed);
      final sick = RecoveryCalculator.compute(
        sleepScore: 90,
        debt7Minutes: 0,
        zone: AcwrZone.sweetSpot,
        acwr: 1,
        rhrToday: 66,
        rhrBaseline: 58,
      );
      expect(sick.score, lessThan(good.score));
    });
  });

  group('BodyCompositionCalculator', () {
    test('Navy method plausible value', () {
      final bf = BodyCompositionCalculator.navyBodyFat(
        sex: Sex.male,
        heightCm: 180,
        neckCm: 38,
        waistCm: 85,
      )!;
      expect(bf, inInclusiveRange(14, 18));
    });
  });
}
