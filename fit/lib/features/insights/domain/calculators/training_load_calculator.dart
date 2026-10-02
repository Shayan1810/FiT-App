import 'dart:math';

import '../../../../core/utils/date_utils.dart';
import '../../../workout/domain/entities/exercise.dart';
import '../../../workout/domain/entities/workout_session.dart';

/// Acute:chronic workload ratio zone (Gabbett 2016, *Br J Sports Med*).
enum AcwrZone { detraining, sweetSpot, caution, danger, unknown }

/// Training-load summary for the last 28 days.
class TrainingLoadSummary {
  const TrainingLoadSummary({
    required this.acuteLoad,
    required this.chronicWeeklyLoad,
    required this.acwr,
    required this.zone,
    required this.monotony,
    required this.strain,
    required this.weeklySetsByMuscle,
    required this.lastTrainedByMuscle,
    required this.dailyLoads,
    this.baselineDays = 0,
    this.sessions28 = 0,
  });

  /// Σ session-RPE load over the last 7 days (AU).
  final double acuteLoad;

  /// Average weekly load over the last 28 days (AU).
  final double chronicWeeklyLoad;

  /// EWMA acute : chronic ratio; null until [hasBaseline].
  final double? acwr;
  final AcwrZone zone;

  /// Foster monotony = mean daily load / SD (last 7 days); > 2 is risky.
  final double? monotony;

  /// Foster strain = weekly load × monotony.
  final double? strain;

  /// Working sets per muscle group in the last 7 days.
  final Map<MuscleGroup, int> weeklySetsByMuscle;

  /// When each muscle group was last trained.
  final Map<MuscleGroup, DateTime> lastTrainedByMuscle;

  /// Load per day for the last 28 days, oldest first.
  final List<double> dailyLoads;

  /// Days since the first logged session (capped at 56).
  final int baselineDays;

  /// Sessions in the last 28 days.
  final int sessions28;

  /// True once there is enough history to judge load spikes.
  bool get hasBaseline =>
      baselineDays >= TrainingLoadCalculator.baselineDaysNeeded &&
      sessions28 >= TrainingLoadCalculator.baselineSessionsNeeded;
}

/// Training-load science.
///
/// * Foster C (1998, 2001) — session-RPE load = RPE × minutes; monotony &
///   strain.
/// * Gabbett TJ (2016) — ACWR 0.8–1.3 "sweet spot", > 1.5 elevated injury
///   risk.
/// * Schoenfeld BJ et al. (2017) *J Sports Sci* — ≥ 10 weekly sets per
///   muscle for hypertrophy.
/// * Epley B (1985) — one-rep-max estimate.
class TrainingLoadCalculator {
  TrainingLoadCalculator._();

  /// Minimum weekly hard sets per muscle for growth (Schoenfeld 2017).
  static const int minWeeklySets = 10;

  /// Estimated 1RM (Epley): w × (1 + reps / 30); exact for 1 rep.
  static double epley1Rm(double weightKg, int reps) => reps <= 1 ? weightKg : weightKg * (1 + reps / 30);

  /// Days of training history needed before ACWR is interpreted.
  static const int baselineDaysNeeded = 21;

  /// Sessions in the last 28 days needed before ACWR is interpreted.
  static const int baselineSessionsNeeded = 6;

  /// Weekly load (AU) below which a ratio spike is not a meaningful risk —
  /// roughly three easy 40-minute sessions.
  static const double minRiskWeeklyLoad = 1000;

  /// EWMA decay constants (Williams et al. 2017): λ = 2 / (N + 1).
  static const double acuteLambda = 2 / (7 + 1);
  static const double chronicLambda = 2 / (28 + 1);

  /// Zone for an ACWR value (Gabbett 2016). Spikes only count as risky when
  /// the absolute acute load is meaningful.
  static AcwrZone zoneFor(double? acwr, {double acuteLoad = double.infinity}) {
    if (acwr == null) return AcwrZone.unknown;
    if (acwr < 0.8) return AcwrZone.detraining;
    if (acwr <= 1.3 || acuteLoad < minRiskWeeklyLoad) return AcwrZone.sweetSpot;
    if (acwr <= 1.5) return AcwrZone.caution;
    return AcwrZone.danger;
  }

  /// Summarises all [sessions] relative to [today] (inclusive).
  ///
  /// ACWR uses exponentially weighted moving averages over the last 56
  /// days, which handle irregular training better than rolling sums
  /// (Williams 2017; Murray 2017). It is only reported once the athlete has
  /// [baselineDaysNeeded] days of history and [baselineSessionsNeeded]
  /// sessions in 28 days — a single workout can never look like an
  /// "injury-risk spike" (the flaw of naïve ACWR with no chronic base).
  static TrainingLoadSummary summarize(List<WorkoutSession> sessions, DateTime today) {
    final days56 = DateKeys.lastNDays(today, 56);
    final idx = {for (var i = 0; i < days56.length; i++) DateKeys.of(days56[i]): i};
    final daily56 = List<double>.filled(56, 0);
    final sets = <MuscleGroup, int>{};
    final last = <MuscleGroup, DateTime>{};
    final weekStart = days56[49];
    final windowStart = days56[28];
    DateTime? first;
    var sessions28 = 0;

    for (final s in sessions) {
      if (first == null || s.start.isBefore(first)) first = s.start;
      final i = idx[DateKeys.of(s.start)];
      if (i == null) continue;
      daily56[i] += s.load;
      if (!s.start.isBefore(windowStart)) sessions28++;
      for (final set in s.sets) {
        final prev = last[set.muscle];
        if (prev == null || s.start.isAfter(prev)) last[set.muscle] = s.start;
        if (!s.start.isBefore(weekStart)) {
          sets[set.muscle] = (sets[set.muscle] ?? 0) + 1;
        }
      }
      if (s.sets.isEmpty && s.type != WorkoutType.strength) {
        final prev = last[MuscleGroup.cardio];
        if (prev == null || s.start.isAfter(prev)) last[MuscleGroup.cardio] = s.start;
      }
    }

    final daily = daily56.sublist(28);
    final acuteList = daily.sublist(21);
    final acute = acuteList.reduce((a, b) => a + b);
    final chronic = daily.reduce((a, b) => a + b) / 4;

    // EWMA acute and chronic load (per day).
    var ea = 0.0, ec = 0.0;
    for (final l in daily56) {
      ea = l * acuteLambda + (1 - acuteLambda) * ea;
      ec = l * chronicLambda + (1 - chronicLambda) * ec;
    }
    final baselineDays = first == null
        ? 0
        : DateKeys.startOfDay(today).difference(DateKeys.startOfDay(first)).inDays;
    final hasBaseline = baselineDays >= baselineDaysNeeded && sessions28 >= baselineSessionsNeeded && ec > 0;
    final acwr = hasBaseline ? ea / ec : null;

    double? monotony;
    double? strain;
    final mean = acute / 7;
    if (mean > 0) {
      final variance = acuteList.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) / 7;
      final sd = sqrt(variance);
      monotony = sd == 0 ? null : mean / sd;
      strain = monotony == null ? null : acute * monotony;
    }

    return TrainingLoadSummary(
      acuteLoad: acute,
      chronicWeeklyLoad: chronic,
      acwr: acwr,
      zone: zoneFor(acwr, acuteLoad: acute),
      monotony: monotony,
      strain: strain,
      weeklySetsByMuscle: sets,
      lastTrainedByMuscle: last,
      dailyLoads: daily,
      baselineDays: min(baselineDays, 56),
      sessions28: sessions28,
    );
  }

  /// How recovered each muscle group is (0–1), given the recovery-speed
  /// [factor] (1 = normal; < 1 = slower because of poor sleep, low energy
  /// or protein, age or heavy recent load).
  static Map<MuscleGroup, double> muscleRecovery(TrainingLoadSummary s, DateTime now, {double factor = 1}) {
    final out = <MuscleGroup, double>{};
    for (final m in MuscleGroup.values) {
      if (m == MuscleGroup.cardio) continue;
      final lastTime = s.lastTrainedByMuscle[m];
      if (lastTime == null) {
        out[m] = 1;
        continue;
      }
      final needed = m.recoveryHours / factor.clamp(0.4, 1.2);
      out[m] = (now.difference(lastTime).inMinutes / 60 / needed).clamp(0.0, 1.0);
    }
    return out;
  }

  /// Muscle groups that are recovered (past their recovery window) and
  /// most under-trained this week — the best focus for the next session.
  static List<MuscleGroup> suggestFocus(TrainingLoadSummary s, DateTime now, {double factor = 1}) {
    const candidates = [
      MuscleGroup.legs,
      MuscleGroup.back,
      MuscleGroup.chest,
      MuscleGroup.shoulders,
      MuscleGroup.arms,
      MuscleGroup.glutes,
      MuscleGroup.core,
    ];
    final ready = candidates.where((m) {
      final lastTime = s.lastTrainedByMuscle[m];
      return lastTime == null || now.difference(lastTime).inHours >= m.recoveryHours / factor.clamp(0.4, 1.2);
    }).toList()..sort((a, b) => (s.weeklySetsByMuscle[a] ?? 0).compareTo(s.weeklySetsByMuscle[b] ?? 0));
    return ready.take(2).toList();
  }
}
