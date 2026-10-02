import 'dart:math';

import '../../../../core/utils/date_utils.dart';
import '../../../sleep/domain/entities/sleep_session.dart';

/// Sleep metrics for the recent week.
class SleepSummary {
  const SleepSummary({
    required this.needMinutes,
    required this.lastNightMinutes,
    required this.avg7Minutes,
    required this.debt7Minutes,
    required this.midpointSdMinutes,
    required this.score,
    required this.typicalWake,
    required this.nightsLogged,
    required this.minutesByDay,
  });

  /// Recommended nightly sleep for the user's age (minutes).
  final int needMinutes;

  /// Sleep attributed to today (woke today), null if none logged.
  final int? lastNightMinutes;

  /// Mean of logged nights in the last 7 days.
  final double? avg7Minutes;

  /// Σ max(0, need − slept) over logged nights of the last 7 days.
  final int debt7Minutes;

  /// Standard deviation of sleep midpoints (minutes) — lower = more regular.
  final double? midpointSdMinutes;

  /// 0–100 composite score of last night (null if no data).
  final int? score;

  /// Median wake-up time-of-day (minutes after midnight) over 7 days.
  final int? typicalWake;
  final int nightsLogged;

  /// Minutes slept per wake-day for the last 7 days (oldest first; 0 = none).
  final List<int> minutesByDay;
}

/// Sleep science.
///
/// * Hirshkowitz M et al. (2015) *Sleep Health* — National Sleep Foundation
///   duration recommendations (14–17 y: 8–10 h; 18–64 y: 7–9 h; 65+: 7–8 h).
/// * Watson NF et al. (2015) AASM/SRS consensus — adults ≥ 7 h.
/// * Phillips AJK et al. (2017) *Sci Rep* — irregular sleep timing is
///   associated with poorer outcomes independent of duration.
/// * Van Dongen HPA et al. (2003) *Sleep* — chronic restriction builds a
///   cumulative deficit ("sleep debt").
class SleepCalculator {
  SleepCalculator._();

  /// Typical sleep-onset latency added before the target wake time.
  static const int onsetLatencyMinutes = 15;

  /// Nightly sleep need in minutes for [age] (mid-point of NSF range).
  static int needMinutes(int age) {
    if (age < 14) return 600; // 9–11 h
    if (age < 18) return 540; // 8–10 h
    if (age < 65) return 480; // 7–9 h
    return 450; // 7–8 h
  }

  /// Maps a clock time so that times around midnight are continuous
  /// (18:00 → 360 … 06:00 → 1080), for averaging bed/midpoint times.
  static int _nightMinutes(DateTime t) => (t.hour * 60 + t.minute + 720) % 1440;

  /// Regularity sub-score 0–1: SD ≤ 30 min → 1, SD ≥ 120 min → 0.
  static double regularityScore(double? sdMinutes) {
    if (sdMinutes == null) return 0.7;
    return (1 - (sdMinutes - 30) / 90).clamp(0.0, 1.0);
  }

  /// Composite score 0–100 = 50 % duration vs need + 25 % regularity +
  /// 25 % subjective quality (quality defaults to 3.5/5 when unrated).
  static int score({required int minutes, required int need, double? sdMinutes, int? quality}) {
    final duration = (minutes / need).clamp(0.0, 1.0);
    // Oversleeping by > 2 h is mildly penalised (associated with poorer health).
    final over = minutes > need + 120 ? 0.9 : 1.0;
    final q = (quality ?? 3.5) / 5;
    return (100 * (0.5 * duration * over + 0.25 * regularityScore(sdMinutes) + 0.25 * q)).round();
  }

  /// Summarises [sessions] for the 7 wake-days ending [today].
  static SleepSummary summarize(List<SleepSession> sessions, DateTime today, int age) {
    final need = needMinutes(age);
    final days = DateKeys.lastNDays(today, 7);
    final keys = days.map(DateKeys.of).toList();
    final byDay = <String, List<SleepSession>>{};
    for (final s in sessions) {
      if (keys.contains(s.wakeDayKey)) (byDay[s.wakeDayKey] ??= []).add(s);
    }

    final minutesByDay = keys
        .map((k) => (byDay[k] ?? const []).fold<int>(0, (a, s) => a + s.minutes))
        .toList();
    final logged = minutesByDay.where((m) => m > 0).toList();
    final debt = logged.fold<int>(0, (a, m) => a + max(0, need - m));

    // Main (longest) sleep of each night drives timing metrics.
    final mains = byDay.values.map((l) => l.reduce((a, b) => a.minutes >= b.minutes ? a : b)).toList();
    double? sd;
    if (mains.length >= 3) {
      final mids = mains.map((s) => _nightMinutes(s.midpoint).toDouble()).toList();
      final mean = mids.reduce((a, b) => a + b) / mids.length;
      sd = sqrt(mids.map((m) => (m - mean) * (m - mean)).reduce((a, b) => a + b) / mids.length);
    }
    int? typicalWake;
    if (mains.isNotEmpty) {
      final wakes = mains.map((s) => s.end.hour * 60 + s.end.minute).toList()..sort();
      typicalWake = wakes[wakes.length ~/ 2];
    }

    final lastNight = minutesByDay.last > 0 ? minutesByDay.last : null;
    int? lastScore;
    if (lastNight != null) {
      final todays = byDay[keys.last]!;
      final main = todays.reduce((a, b) => a.minutes >= b.minutes ? a : b);
      lastScore = score(minutes: lastNight, need: need, sdMinutes: sd, quality: main.quality);
    }

    return SleepSummary(
      needMinutes: need,
      lastNightMinutes: lastNight,
      avg7Minutes: logged.isEmpty ? null : logged.reduce((a, b) => a + b) / logged.length,
      debt7Minutes: debt,
      midpointSdMinutes: sd,
      score: lastScore,
      typicalWake: typicalWake,
      nightsLogged: logged.length,
      minutesByDay: minutesByDay,
    );
  }

  /// Recommended bedtime for tonight so the user wakes at their typical
  /// time having slept their need (+30 min if carrying > 2 h of debt —
  /// extending sleep is preferred over sleeping in, to protect regularity).
  static ({DateTime bedtime, DateTime wake}) recommendBedtime(SleepSummary s, DateTime now) {
    final wakeMin = s.typicalWake ?? 7 * 60;
    // Before 04:00 the user hasn't slept yet, so "tonight" ends this morning.
    final wakeDay = now.hour < 4
        ? DateKeys.startOfDay(now)
        : DateKeys.startOfDay(now).add(const Duration(days: 1));
    final wake = wakeDay.add(Duration(minutes: wakeMin));
    final extra = s.debt7Minutes > 120 ? 30 : 0;
    final bed = wake.subtract(Duration(minutes: s.needMinutes + onsetLatencyMinutes + extra));
    return (bedtime: bed, wake: wake);
  }
}
