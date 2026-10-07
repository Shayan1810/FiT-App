import 'dart:math';

import '../../../../core/utils/date_utils.dart';
import '../../../insights/domain/calculators/energy_calculator.dart';
import '../../../insights/domain/calculators/weight_trend_calculator.dart';
import '../../../insights/domain/entities/health_snapshot.dart';
import '../../../nutrition/domain/entities/nutrition_facts.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../../profile/domain/entities/weight_entry.dart';
import '../entities/transformation_plan.dart';
import 'strength_calculator.dart';

/// Everything about the active transformation that the engine needs; built
/// by `BuildHealthSnapshot` from the repositories.
class TransformationInput {
  const TransformationInput({required this.plan, required this.days, required this.checks});

  final TransformationPlan plan;

  /// Every day from the plan start (or today, if it hasn't started) up to
  /// today, oldest first.
  final List<DaySnapshot> days;

  /// Ticked item ids per day key.
  final Map<String, Set<String>> checks;
}

/// One day of a transformation.
class PlanDay {
  const PlanDay({
    required this.date,
    required this.dayKey,
    required this.dayNumber,
    required this.intake,
    required this.logged,
    required this.expenditure,
    required this.kcalTarget,
    required this.items,
    required this.doneIds,
    required this.isToday,
  });

  final DateTime date;
  final String dayKey;
  final int dayNumber;
  final NutritionFacts intake;

  /// Food was logged (or planned meals ticked) that day.
  final bool logged;

  /// Estimated total expenditure (BMR + movement + exercise + TEF).
  final double expenditure;
  final double kcalTarget;
  final List<PlanItem> items;
  final Set<String> doneIds;
  final bool isToday;

  /// Intake − expenditure for completed, logged days (null otherwise).
  double? get balance => logged && !isToday ? intake.kcal - expenditure : null;

  int get planned => items.length;
  int get done => items.where((i) => doneIds.contains(i.id)).length;

  /// Share of the plan completed (0–1).
  double get adherence => planned == 0 ? 1 : done / planned;

  bool get isRest => !items.any((i) => i.kind == PlanItemKind.workout);

  List<PlanItem> get skincare => [
    for (final i in items)
      if (i.kind == PlanItemKind.skincare) i,
  ];
  bool get skincareComplete => skincare.isNotEmpty && skincare.every((i) => doneIds.contains(i.id));
}

/// Progress of a transformation. Body changes are estimated from **energy
/// balance**, not the scale: day-to-day weight swings of 1–2 kg are mostly
/// water and glycogen, while the energy deficit tracks fat tissue.
///
/// * 1 kg of body fat ≈ 7 700 kcal (Hall 2008).
/// * 1 kg of tissue gained with resistance training ≈ 5 500 kcal (mixed
///   lean + fat tissue incl. synthesis cost; Forbes 1987, Slater 2019).
class TransformationStatus {
  const TransformationStatus({
    required this.plan,
    required this.days,
    required this.today,
    required this.tomorrowItems,
    required this.dayNumber,
    required this.daysLeft,
    required this.countedDays,
    required this.netKcal,
    required this.fatLostKg,
    required this.massGainedKg,
    required this.estimatedWeightKg,
    required this.estimatedBodyFatPct,
    required this.trendWeightKg,
    required this.plannedWeightKg,
    required this.projectedEndWeightKg,
    required this.avgDailyBalance,
    required this.adherence7,
    required this.adherenceAll,
    required this.streak,
    required this.skinStreak,
    required this.yesterday,
    this.strength = const [],
  });

  static const double kcalPerKgFat = 7700;
  static const double kcalPerKgGain = 5500;

  final TransformationPlan plan;

  /// Days from the start to today (empty before the start).
  final List<PlanDay> days;

  /// Today's checklist (null if today is outside the plan).
  final PlanDay? today;
  final PlanDay? yesterday;
  final List<PlanItem> tomorrowItems;

  /// Today's day number (≤ 0 before the start).
  final int dayNumber;
  final int daysLeft;

  /// Completed days with food logged (used for the energy balance).
  final int countedDays;

  /// Σ (intake − expenditure) over counted days.
  final double netKcal;
  final double fatLostKg;
  final double massGainedKg;

  /// Start weight − fat lost + mass gained.
  final double? estimatedWeightKg;
  final double? estimatedBodyFatPct;

  /// Smoothed scale weight (EMA) — shown for reference only.
  final double? trendWeightKg;

  /// Where the straight-line plan says you should be today.
  final double? plannedWeightKg;

  /// Weight at the end if the average balance so far continues.
  final double? projectedEndWeightKg;
  final double? avgDailyBalance;

  /// Average plan completion of the last 7 completed days / all days.
  final double? adherence7;
  final double? adherenceAll;

  /// Consecutive completed days with ≥ 80 % of the plan done.
  final int streak;

  /// Consecutive days with every skincare routine done.
  final int skinStreak;

  /// Strength change per exercise since the plan started (best first).
  final List<StrengthChange> strength;

  bool get started => dayNumber >= 1;
  bool get finished => dayNumber > plan.totalDays;

  /// 0–1 share of the plan's time elapsed.
  double get timeProgress => (max(0, dayNumber - 1) / plan.totalDays).clamp(0.0, 1.0);

  /// Change the plan wants in total (negative = loss).
  double? get plannedChangeKg => plan.startWeightKg == null || plan.goalWeightKg == null
      ? null
      : plan.goalWeightKg! - plan.startWeightKg!;
}

/// Pure calculator for [TransformationStatus].
class TransformationCalculator {
  TransformationCalculator._();

  /// Expenditure of one day (BMR + NEAT + exercise + TEF) at [weightKg].
  static double expenditure(UserProfile p, DaySnapshot d, double weightKg) => EnergyCalculator.daily(
    profile: p.copyWith(weightKg: weightKg),
    steps: d.activity?.steps ?? 0,
    distanceKm: d.activity?.distanceKm,
    deviceActiveKcal: d.activity?.activeKcal,
    workouts: d.workouts,
    intake: d.intake,
  ).total;

  /// Body-mass change for a cumulative energy balance (kg).
  static double _massChange(double netKcal) => netKcal < 0
      ? netKcal / TransformationStatus.kcalPerKgFat
      : netKcal / TransformationStatus.kcalPerKgGain;

  /// Builds the status for [now].
  static TransformationStatus compute({
    required TransformationInput input,
    required UserProfile profile,
    required List<WeightEntry> weights,
    required DateTime now,
  }) {
    final plan = input.plan;
    final dayNumber = plan.dayNumber(now);
    final todayKey = DateKeys.of(now);
    final startW = plan.startWeightKg ?? profile.weightKg;
    final energyBased = plan.hasBody;

    final days = <PlanDay>[];
    var net = 0.0;
    var counted = 0;
    for (final d in input.days) {
      if (!plan.contains(d.date)) continue;
      final weightNow = startW + _massChange(net);
      final exp = expenditure(profile, d, weightNow);
      final day = PlanDay(
        date: d.date,
        dayKey: d.dayKey,
        dayNumber: plan.dayNumber(d.date),
        intake: d.intake,
        logged: d.foodEntries > 0,
        expenditure: exp,
        kcalTarget: plan.kcalOn(d.date),
        items: plan.itemsFor(d.date),
        doneIds: input.checks[d.dayKey] ?? const {},
        isToday: d.dayKey == todayKey,
      );
      days.add(day);
      final b = day.balance;
      if (b != null) {
        counted++;
        net += b;
      }
    }
    // Net view: fat lost is reduced by later surpluses and vice versa.
    final fatNet = max(0.0, -net / TransformationStatus.kcalPerKgFat);
    final gainNet = max(0.0, net / TransformationStatus.kcalPerKgGain);

    final estWeight = energyBased && counted > 0 ? startW - fatNet + gainNet : (energyBased ? startW : null);
    double? estBf;
    if (plan.startBodyFatPct != null && estWeight != null) {
      final fatMass = startW * plan.startBodyFatPct! / 100 - fatNet + gainNet * 0.5;
      estBf = (fatMass / estWeight * 100).clamp(3.0, 60.0);
    }

    final trend = WeightTrendCalculator.ema([
      for (final w in weights)
        if (!w.date.isBefore(DateKeys.startOfDay(plan.start))) w,
    ]);
    final avg = counted == 0 ? null : net / counted;
    final remaining = max(0, plan.totalDays - max(0, dayNumber - 1));
    double? projected;
    if (avg != null && estWeight != null) {
      final perDay = avg < 0
          ? avg / TransformationStatus.kcalPerKgFat
          : avg / TransformationStatus.kcalPerKgGain;
      projected = estWeight + perDay * remaining;
    }

    final completed = [
      for (final d in days)
        if (!d.isToday) d,
    ];
    double? mean(Iterable<double> xs) => xs.isEmpty ? null : xs.reduce((a, b) => a + b) / xs.length;
    var streak = 0;
    for (final d in completed.reversed) {
      if (d.adherence >= 0.8) {
        streak++;
      } else {
        break;
      }
    }
    var skinStreak = 0;
    if (plan.hasSkin) {
      // Today counts once it's complete; an unfinished today doesn't break it.
      final list = [
        ...completed,
        if (days.isNotEmpty && days.last.isToday && days.last.skincareComplete) days.last,
      ];
      for (final d in list.reversed) {
        if (d.skincare.isEmpty) continue;
        if (d.skincareComplete) {
          skinStreak++;
        } else {
          break;
        }
      }
    }

    final today = days.isNotEmpty && days.last.isToday ? days.last : null;
    final yesterday = completed.isEmpty ? null : completed.last;
    final tomorrow = DateKeys.startOfDay(now).add(const Duration(days: 1));
    return TransformationStatus(
      plan: plan,
      days: days,
      today: today,
      yesterday: yesterday,
      tomorrowItems: plan.itemsFor(tomorrow),
      dayNumber: dayNumber,
      daysLeft: dayNumber < 1 ? plan.totalDays : max(0, plan.totalDays - dayNumber),
      countedDays: counted,
      netKcal: net,
      fatLostKg: fatNet,
      massGainedKg: gainNet,
      estimatedWeightKg: estWeight,
      estimatedBodyFatPct: estBf,
      trendWeightKg: trend.isEmpty ? null : trend.last.trend,
      plannedWeightKg: plan.contains(now) ? plan.plannedWeightOn(now) : null,
      projectedEndWeightKg: projected,
      avgDailyBalance: avg,
      adherence7: mean(completed.reversed.take(7).map((d) => d.adherence)),
      adherenceAll: mean(completed.map((d) => d.adherence)),
      streak: streak,
      skinStreak: skinStreak,
      strength: StrengthCalculator.changes([
        for (final d in input.days)
          if (plan.contains(d.date)) ...d.workouts,
      ]),
    );
  }
}
