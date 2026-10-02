import '../../../../core/utils/date_utils.dart';
import '../../../profile/domain/entities/weight_entry.dart';

/// A weigh-in with its smoothed trend value.
class TrendPoint {
  const TrendPoint(this.date, this.raw, this.trend);
  final DateTime date;
  final double raw;
  final double trend;
}

/// Smooths noisy scale weights and estimates the real rate of change.
///
/// Day-to-day weight swings ±1–2 kg from water, glycogen and gut content.
/// An exponential moving average (EMA, α = 0.1 per day — Walker,
/// *The Hacker's Diet*) reveals the underlying tissue trend.
class WeightTrendCalculator {
  WeightTrendCalculator._();

  /// Energy density of body-weight change: ≈ 7700 kcal per kg
  /// (Wishnofsky 1958; a simplification — see Hall 2008, *Int J Obes*).
  static const double kcalPerKg = 7700;

  /// EMA trend for [entries] (any order). Days without a weigh-in keep the
  /// previous trend value; α is applied once per calendar day.
  static List<TrendPoint> ema(List<WeightEntry> entries, {double alpha = 0.1}) {
    if (entries.isEmpty) return const [];
    final sorted = [...entries]..sort((a, b) => a.date.compareTo(b.date));
    final byDay = {for (final e in sorted) e.dayKey: e};
    final first = DateKeys.startOfDay(sorted.first.date);
    final last = DateKeys.startOfDay(sorted.last.date);

    var trend = sorted.first.kg;
    final out = <TrendPoint>[];
    for (var d = first; !d.isAfter(last); d = d.add(const Duration(days: 1))) {
      final e = byDay[DateKeys.of(d)];
      if (e == null) continue;
      trend = trend + alpha * (e.kg - trend);
      out.add(TrendPoint(e.date, e.kg, trend));
    }
    return out;
  }

  /// Weekly rate of change (kg/week) from a least-squares line through the
  /// trend over the last [windowDays]. Null if < 3 points or < 7 days span.
  static double? weeklyRate(List<TrendPoint> points, {int windowDays = 21}) {
    if (points.length < 3) return null;
    final end = points.last.date;
    final window = points.where((p) => end.difference(p.date).inDays <= windowDays).toList();
    if (window.length < 3) return null;
    if (end.difference(window.first.date).inDays < 7) return null;

    final xs = window.map((p) => p.date.difference(window.first.date).inHours / 24.0).toList();
    final ys = window.map((p) => p.trend).toList();
    final n = xs.length;
    final mx = xs.reduce((a, b) => a + b) / n;
    final my = ys.reduce((a, b) => a + b) / n;
    var num = 0.0, den = 0.0;
    for (var i = 0; i < n; i++) {
      num += (xs[i] - mx) * (ys[i] - my);
      den += (xs[i] - mx) * (xs[i] - mx);
    }
    if (den == 0) return null;
    return num / den * 7; // kg/day → kg/week
  }

  /// Adaptive (measured) TDEE from energy balance:
  /// TDEE = mean intake − Δtrend × 7700 / days.
  ///
  /// [dailyIntakeKcal] holds only days that were fully logged. Returns null
  /// unless there are ≥ 10 logged days and the trend spans ≥ 10 days.
  static ({double tdee, double confidence})? adaptiveTdee({
    required List<double> dailyIntakeKcal,
    required List<TrendPoint> trend,
    int windowDays = 28,
  }) {
    if (dailyIntakeKcal.length < 10 || trend.length < 4) return null;
    final end = trend.last;
    final startCandidates = trend.where((p) => end.date.difference(p.date).inDays <= windowDays).toList();
    final start = startCandidates.first;
    final span = end.date.difference(start.date).inHours / 24.0;
    if (span < 10) return null;

    final meanIntake = dailyIntakeKcal.reduce((a, b) => a + b) / dailyIntakeKcal.length;
    final tdee = meanIntake - (end.trend - start.trend) * kcalPerKg / span;
    final confidence = (dailyIntakeKcal.length / 21).clamp(0.0, 1.0);
    return (tdee: tdee, confidence: confidence);
  }
}
