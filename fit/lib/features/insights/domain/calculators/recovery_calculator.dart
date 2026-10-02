import 'training_load_calculator.dart';

/// Readiness bands.
enum Readiness { primed, ready, moderate, recover }

/// Display helpers for [Readiness].
extension ReadinessX on Readiness {
  String get label => switch (this) {
    Readiness.primed => 'Primed',
    Readiness.ready => 'Ready',
    Readiness.moderate => 'Moderate',
    Readiness.recover => 'Recover',
  };
}

/// One input to the recovery score.
class RecoveryComponent {
  const RecoveryComponent(this.name, this.value, this.weight, this.detail);

  /// e.g. "Sleep".
  final String name;

  /// Sub-score 0–1.
  final double value;

  /// Relative weight before renormalisation.
  final double weight;

  /// Human explanation, e.g. "6h 40m vs 8h need".
  final String detail;
}

/// Recovery / readiness result.
class RecoveryScore {
  const RecoveryScore(
    this.score,
    this.readiness,
    this.components, {
    this.factor = 1,
    this.factorParts = const [],
  });
  final int score;
  final Readiness readiness;
  final List<RecoveryComponent> components;

  /// Recovery-speed multiplier (1.0 = typical; 0.7 = recovering ~30 %
  /// slower). Scales how long each muscle group needs between sessions.
  final double factor;

  /// What slowed (or sped up) recovery, as (name, multiplier, why).
  final List<(String, double, String)> factorParts;
}

/// Combines sleep, sleep debt, training load and resting heart rate into
/// a 0–100 readiness score.
///
/// Weights: see [compute]. Missing inputs are dropped and the rest renormalised, so the score
/// works with or without a wearable.
///
/// * Resting-HR elevation of ≥ 5 bpm above a personal baseline is a common
///   marker of incomplete recovery / illness (Buchheit 2014, *Front Physiol*).
/// * ACWR zones from Gabbett (2016).
class RecoveryCalculator {
  RecoveryCalculator._();

  /// Sub-score for an ACWR zone.
  static double loadComponent(AcwrZone zone) => switch (zone) {
    AcwrZone.sweetSpot => 1.0,
    AcwrZone.detraining => 0.9,
    AcwrZone.caution => 0.6,
    AcwrZone.danger => 0.3,
    AcwrZone.unknown => 0.8,
  };

  /// Sub-score for resting-HR deviation (bpm above baseline).
  static double rhrComponent(double deviation) {
    if (deviation >= 5) return 0.3;
    if (deviation >= 3) return 0.6;
    if (deviation <= -2) return 1.0;
    return 0.9;
  }

  /// Readiness band for a score.
  static Readiness bandFor(int score) {
    if (score >= 80) return Readiness.primed;
    if (score >= 65) return Readiness.ready;
    if (score >= 45) return Readiness.moderate;
    return Readiness.recover;
  }

  /// Energy-availability sub-score from intake ÷ expenditure (3-day mean).
  /// A ~20 % deficit already lowers muscle protein synthesis (Areta 2014).
  static double energyComponent(double ratio) {
    if (ratio >= 0.9) return 1.0;
    if (ratio >= 0.8) return 0.8;
    if (ratio >= 0.7) return 0.6;
    return 0.4;
  }

  /// Protein sub-score: g/kg/day relative to 1.6 g/kg (Morton 2018).
  static double proteinComponent(double gPerKg) => (gPerKg / 1.6).clamp(0.3, 1.0);

  /// Damage sub-score: load of the last 48 h vs. two "typical" days.
  static double damageComponent(double load48h, double chronicDaily) {
    if (load48h <= 0) return 1.0;
    final typical = chronicDaily > 0 ? chronicDaily * 2 : 400.0;
    final r = load48h / typical;
    if (r <= 1.0) return 0.95;
    if (r <= 1.5) return 0.8;
    if (r <= 2.5) return 0.6;
    return 0.45;
  }

  /// Recovery-speed factor and its parts. Each part multiplies the others:
  ///
  /// * **Sleep** — ≥ need → 1.0; each hour short slows repair (one night of
  ///   deprivation cuts muscle protein synthesis by 18 %; Lamon 2021).
  /// * **Energy** — eating < 80 % of expenditure → 0.85–0.9 (Areta 2014).
  /// * **Protein** — below 1.6 g/kg → down to 0.8 (Morton 2018).
  /// * **Age** — −4 % per decade over 30 (Fell & Williams 2008).
  /// * **Training damage** — heavy last 48 h → 0.85–0.9.
  static ({double factor, List<(String, double, String)> parts}) recoveryFactor({
    double? sleepRatio,
    double? energyRatio,
    double? proteinPerKg,
    int? age,
    double load48h = 0,
    double chronicDaily = 0,
  }) {
    final parts = <(String, double, String)>[];
    if (sleepRatio != null) {
      final f = (0.7 + 0.3 * sleepRatio).clamp(0.7, 1.05);
      parts.add(('Sleep', f, '${(sleepRatio * 100).round()} % of your sleep need'));
    }
    if (energyRatio != null) {
      final f = energyRatio >= 0.9 ? 1.0 : (energyRatio >= 0.8 ? 0.93 : (energyRatio >= 0.7 ? 0.88 : 0.82));
      parts.add(('Energy', f, 'eating ${(energyRatio * 100).round()} % of what you burn'));
    }
    if (proteinPerKg != null) {
      final f = (0.8 + 0.2 * (proteinPerKg / 1.6)).clamp(0.8, 1.0);
      parts.add(('Protein', f, '${proteinPerKg.toStringAsFixed(1)} g/kg/day'));
    }
    if (age != null && age > 30) {
      final f = (1 - 0.04 * (age - 30) / 10).clamp(0.8, 1.0);
      parts.add(('Age', f, '$age years'));
    }
    if (load48h > 0) {
      final d = damageComponent(load48h, chronicDaily);
      final f = d >= 0.95 ? 1.0 : (d >= 0.8 ? 0.93 : 0.86);
      parts.add(('Training damage', f, '${load48h.round()} AU in the last 48 h'));
    }
    final factor = parts.fold<double>(1, (a, p) => a * p.$2).clamp(0.4, 1.1);
    return (factor: factor, parts: parts);
  }

  /// Computes the readiness score.
  ///
  /// Weights (re-normalised over available inputs): sleep 30 %, training
  /// load 20 %, resting HR 15 %, sleep debt 10 %, energy availability 10 %,
  /// protein 8 %, recent training damage 7 %.
  static RecoveryScore compute({
    int? sleepScore,
    required int debt7Minutes,
    required AcwrZone zone,
    double? acwr,
    double? rhrToday,
    double? rhrBaseline,
    String? sleepDetail,
    double? sleepRatio,
    double? energyRatio,
    double? proteinPerKg,
    int? age,
    double load48h = 0,
    double chronicDaily = 0,
    int baselineDays = 0,
  }) {
    final parts = <RecoveryComponent>[];
    if (sleepScore != null) {
      parts.add(RecoveryComponent('Sleep', sleepScore / 100, 0.30, sleepDetail ?? 'Sleep score $sleepScore'));
    }
    parts.add(
      RecoveryComponent(
        'Sleep debt',
        (1 - debt7Minutes / 600).clamp(0.0, 1.0),
        0.10,
        '${(debt7Minutes / 60).toStringAsFixed(1)} h owed this week',
      ),
    );
    parts.add(
      RecoveryComponent(
        'Training load',
        loadComponent(zone),
        0.20,
        acwr == null
            ? 'Building your baseline (${baselineDays.clamp(0, 21)}/21 days)'
            : 'ACWR ${acwr.toStringAsFixed(2)}',
      ),
    );
    if (rhrToday != null && rhrBaseline != null) {
      final dev = rhrToday - rhrBaseline;
      parts.add(
        RecoveryComponent(
          'Resting HR',
          rhrComponent(dev),
          0.15,
          '${dev >= 0 ? '+' : ''}${dev.toStringAsFixed(0)} bpm vs baseline',
        ),
      );
    }
    if (energyRatio != null) {
      parts.add(
        RecoveryComponent(
          'Energy intake',
          energyComponent(energyRatio),
          0.10,
          '${(energyRatio * 100).round()} % of expenditure (3 days)',
        ),
      );
    }
    if (proteinPerKg != null) {
      parts.add(
        RecoveryComponent(
          'Protein',
          proteinComponent(proteinPerKg),
          0.08,
          '${proteinPerKg.toStringAsFixed(1)} g/kg/day (3 days)',
        ),
      );
    }
    if (load48h > 0) {
      parts.add(
        RecoveryComponent(
          'Recent damage',
          damageComponent(load48h, chronicDaily),
          0.07,
          '${load48h.round()} AU in the last 48 h',
        ),
      );
    }
    final wSum = parts.fold<double>(0, (a, p) => a + p.weight);
    final value = parts.fold<double>(0, (a, p) => a + p.value * p.weight) / wSum;
    final score = (value * 100).round().clamp(0, 100);
    final rf = recoveryFactor(
      sleepRatio: sleepRatio,
      energyRatio: energyRatio,
      proteinPerKg: proteinPerKg,
      age: age,
      load48h: load48h,
      chronicDaily: chronicDaily,
    );
    return RecoveryScore(score, bandFor(score), parts, factor: rf.factor, factorParts: rf.parts);
  }
}
