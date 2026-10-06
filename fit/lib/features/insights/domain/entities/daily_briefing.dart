import '../../../nutrition/domain/entities/nutrition_facts.dart';
import '../../../transformation/domain/calculators/transformation_calculator.dart';
import '../../../workout/domain/entities/exercise.dart';
import '../calculators/energy_calculator.dart';
import '../calculators/nutrition_targets_calculator.dart';
import '../calculators/recovery_calculator.dart';
import '../calculators/sleep_calculator.dart';
import '../calculators/training_load_calculator.dart';
import '../calculators/weight_trend_calculator.dart';

/// Area an insight is about (drives its icon and colour).
enum InsightCategory { sleep, nutrition, training, activity, body, hydration, plan }

/// Emotional tone of an insight.
enum InsightTone { positive, info, warning, alert }

/// One coach observation with its scientific justification.
class Insight {
  const Insight({
    required this.id,
    required this.category,
    required this.tone,
    required this.title,
    required this.message,
    required this.why,
    required this.reference,
    required this.priority,
  });

  final String id;
  final InsightCategory category;
  final InsightTone tone;
  final String title;

  /// What to do, in plain words.
  final String message;

  /// The physiology behind it.
  final String why;

  /// Citation.
  final String reference;

  /// Higher = shown first.
  final int priority;
}

/// What kind of training tomorrow should be.
class TrainingRecommendation {
  const TrainingRecommendation({
    required this.headline,
    required this.detail,
    required this.rpeRange,
    required this.durationMin,
    required this.focus,
    required this.isRest,
    required this.plannedKcal,
  });

  final String headline;
  final String detail;
  final String rpeRange;
  final int durationMin;
  final List<MuscleGroup> focus;
  final bool isRest;

  /// Estimated net energy of the planned session.
  final double plannedKcal;
}

/// The plan for tomorrow.
class NextDayPlan {
  const NextDayPlan({
    required this.date,
    required this.targets,
    required this.steps,
    required this.training,
    required this.bedtime,
    required this.wake,
  });

  final DateTime date;
  final NutritionTargets targets;
  final int steps;
  final TrainingRecommendation training;

  /// Recommended lights-out tonight and wake-up tomorrow.
  final DateTime bedtime;
  final DateTime wake;
}

/// One bar of the weekly energy chart.
class DayEnergy {
  const DayEnergy(this.dayKey, this.date, this.intake, this.expenditure, this.logged);
  final String dayKey;
  final DateTime date;
  final double intake;
  final double expenditure;
  final bool logged;
}

/// Numbers for the Today dashboard.
class TodaySummary {
  const TodaySummary({
    required this.intake,
    required this.targets,
    required this.energy,
    required this.tdee,
    required this.tdeeMethod,
    required this.steps,
    required this.stepTarget,
    required this.distanceKm,
    required this.waterMl,
    required this.trendWeight,
    required this.weeklyRateKg,
  });

  final NutritionFacts intake;
  final NutritionTargets targets;
  final EnergyBreakdown energy;

  /// Best estimate of today's expenditure (adaptive-blended).
  final double tdee;

  /// "Formula" or "Adaptive (n days)".
  final String tdeeMethod;
  final int steps;
  final int stepTarget;
  final double distanceKm;
  final int waterMl;
  final double? trendWeight;
  final double? weeklyRateKg;

  /// Energy balance so far (intake − expenditure).
  double get net => intake.kcal - tdee;
}

/// Everything the coach knows today — the output of the insight engine.
class DailyBriefing {
  const DailyBriefing({
    required this.generatedAt,
    required this.greeting,
    required this.headline,
    required this.narrative,
    required this.recovery,
    required this.today,
    required this.plan,
    required this.insights,
    required this.sleep,
    required this.load,
    required this.weightTrend,
    required this.week,
    this.transformation,
  });

  final DateTime generatedAt;
  final String greeting;
  final String headline;

  /// The coach's spoken paragraphs.
  final List<String> narrative;
  final RecoveryScore recovery;
  final TodaySummary today;
  final NextDayPlan plan;
  final List<Insight> insights;
  final SleepSummary sleep;
  final TrainingLoadSummary load;
  final List<TrendPoint> weightTrend;

  /// Last 7 days of intake vs expenditure, oldest first.
  final List<DayEnergy> week;

  /// Progress of the active transformation (Transformation mode only).
  final TransformationStatus? transformation;
}
