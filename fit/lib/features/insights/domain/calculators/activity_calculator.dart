/// Step-count science.
///
/// * Paluch AE et al. (2022) *Lancet Public Health* 7:e219 — meta-analysis
///   of 47 471 adults: mortality risk falls progressively with steps and
///   plateaus at ~8 000–10 000/day for adults < 60 and ~6 000–8 000/day
///   for adults ≥ 60.
/// * Progressive overload for habits: +1 000 steps/day increments are a
///   commonly used, achievable step (≈ 10 min of walking).
class ActivityCalculator {
  ActivityCalculator._();

  /// Steps above which extra benefit plateaus for [age].
  static int plateauSteps(int age) => age >= 60 ? 8000 : 10000;

  /// Tomorrow's step goal: recent average + 1 000, rounded to 500,
  /// never below 5 000 and never above the age plateau.
  static int stepTarget({required double? avg7Steps, required int age}) {
    final cap = plateauSteps(age);
    if (avg7Steps == null) return age >= 60 ? 6000 : 8000;
    if (avg7Steps >= cap) return cap;
    final raw = ((avg7Steps + 1000) / 500).round() * 500;
    return raw.clamp(5000, cap);
  }

  /// Classification used in coach messages (Tudor-Locke 2008 step index).
  static String stepCategory(int steps) {
    if (steps < 5000) return 'sedentary';
    if (steps < 7500) return 'low active';
    if (steps < 10000) return 'somewhat active';
    if (steps < 12500) return 'active';
    return 'highly active';
  }
}
