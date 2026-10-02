import 'dart:math';

import '../../../core/utils/date_utils.dart';
import '../../insights/domain/calculators/energy_calculator.dart';
import '../../insights/domain/calculators/recovery_calculator.dart';
import '../../insights/domain/calculators/sleep_calculator.dart';
import '../../insights/domain/calculators/training_load_calculator.dart';
import '../../insights/domain/calculators/weight_trend_calculator.dart';
import '../../insights/domain/entities/health_snapshot.dart';
import '../../workout/domain/entities/exercise.dart';

/// Groups shown as filter chips on the Progress screen.
enum ProgressCategory { nutrition, body, activity, sleep, training, recovery }

extension ProgressCategoryX on ProgressCategory {
  /// Display label.
  String get label => switch (this) {
    ProgressCategory.nutrition => 'Nutrition',
    ProgressCategory.body => 'Body',
    ProgressCategory.activity => 'Activity',
    ProgressCategory.sleep => 'Sleep',
    ProgressCategory.training => 'Training',
    ProgressCategory.recovery => 'Recovery',
  };
}

/// One metric over time, aligned to [ProgressReport.dates] (null = no data).
class MetricSeries {
  const MetricSeries({
    required this.id,
    required this.category,
    required this.title,
    required this.unit,
    required this.values,
    required this.about,
    this.decimals = 0,
    this.bars = false,
    this.target,
    this.higherIsBetter,
    this.secondary,
  });

  final String id;
  final ProgressCategory category;
  final String title;
  final String unit;

  /// One value per day (or per week for weekly metrics).
  final List<double?> values;

  /// What the metric means / why it matters.
  final String about;
  final int decimals;

  /// Draw as bars instead of a line.
  final bool bars;

  /// Optional goal line.
  final double? target;

  /// Colours the change: true = up is good, false = down is good, null = neutral.
  final bool? higherIsBetter;

  /// Optional second line (e.g. weight trend over raw weigh-ins).
  final List<double?>? secondary;

  Iterable<double> get _present => values.whereType<double>();

  /// Number of days with data.
  int get count => _present.length;

  /// Latest value, if any.
  double? get latest => _present.isEmpty ? null : _present.last;

  /// Mean of present values.
  double? get average => count == 0 ? null : _present.reduce((a, b) => a + b) / count;

  /// Minimum / maximum of present values.
  double? get minValue => count == 0 ? null : _present.reduce(min);
  double? get maxValue => count == 0 ? null : _present.reduce(max);

  /// Change between the first and last present values.
  double? get change => count < 2 ? null : _present.last - _present.first;
}

/// Progress of one exercise (one point per session day).
class ExerciseProgress {
  const ExerciseProgress({
    required this.id,
    required this.name,
    required this.muscle,
    required this.dates,
    required this.e1rm,
    required this.topWeight,
    required this.volume,
    required this.bestReps,
    required this.relativeStrength,
  });

  final String id;
  final String name;
  final MuscleGroup muscle;
  final List<DateTime> dates;

  /// Best estimated one-rep max (Epley) per session.
  final List<double> e1rm;

  /// Heaviest weight lifted per session.
  final List<double> topWeight;

  /// Volume load (Σ reps × kg) per session.
  final List<double> volume;

  /// Most reps in a single set per session.
  final List<double> bestReps;

  /// e1RM ÷ body weight (strength relative to size).
  final List<double?> relativeStrength;

  int get sessions => dates.length;
}

/// Everything the Progress screen draws.
class ProgressReport {
  const ProgressReport({
    required this.dates,
    required this.series,
    required this.exercises,
    required this.weekStarts,
    required this.weeklySets,
  });

  /// Days covered, oldest first.
  final List<DateTime> dates;
  final List<MetricSeries> series;

  /// Exercises logged in the range, most-trained first.
  final List<ExerciseProgress> exercises;

  /// Monday of each week in the range (for weekly metrics).
  final List<DateTime> weekStarts;

  /// Working sets per muscle per week (heat-map).
  final Map<MuscleGroup, List<int>> weeklySets;

  /// Series of one category.
  List<MetricSeries> of(ProgressCategory c) => series.where((s) => s.category == c).toList();
}

/// Turns a long [HealthSnapshot] into time series for every metric FiT
/// tracks — including derived ones other apps don't show: protein per kg,
/// energy balance, EWMA ACWR, monotony, sleep regularity, rolling sleep
/// debt, daily readiness and recovery speed, per-exercise e1RM and
/// relative strength. Pure function; runs in a background isolate.
class ProgressCalculator {
  ProgressCalculator._();

  /// Builds the report.
  static ProgressReport compute(HealthSnapshot s) {
    final p = s.profile;
    final dates = [for (final d in s.days) d.date];
    final n = dates.length;
    final idx = {for (var i = 0; i < n; i++) s.days[i].dayKey: i};
    List<double?> empty() => List<double?>.filled(n, null);

    // ── Nutrition ────────────────────────────────────────────────────
    final kcal = empty(), protein = empty(), carbs = empty(), fat = empty(), fiber = empty();
    final proteinKg = empty(), water = empty(), balance = empty(), proteinShare = empty();
    // ── Activity ─────────────────────────────────────────────────────
    final steps = empty(), km = empty(), active = empty(), rhr = empty(), burn = empty();
    // ── Training (daily) ─────────────────────────────────────────────
    final load = empty(), volume = empty(), duration = empty(), rpe = empty();

    // Weight lookup for per-kg metrics.
    final trend = WeightTrendCalculator.ema(s.weights);
    double weightOn(DateTime d) {
      double w = p.weightKg;
      for (final t in trend) {
        if (t.date.isAfter(DateKeys.endOfDay(d))) break;
        w = t.trend;
      }
      return w;
    }

    for (var i = 0; i < n; i++) {
      final d = s.days[i];
      final logged = d.foodEntries > 0;
      final w = weightOn(d.date);
      if (logged) {
        kcal[i] = d.intake.kcal;
        protein[i] = d.intake.protein;
        carbs[i] = d.intake.carbs;
        fat[i] = d.intake.fat;
        fiber[i] = d.intake.fiber;
        proteinKg[i] = d.intake.protein / w;
        proteinShare[i] = d.intake.proteinShare * 100;
      }
      if (d.waterMl > 0) water[i] = d.waterMl / 1000;
      final a = d.activity;
      if (a != null) {
        steps[i] = a.steps.toDouble();
        km[i] = a.distanceKm ?? EnergyCalculator.stepsToKm(a.steps, heightCm: p.heightCm, sex: p.sex);
        if (a.activeKcal != null) active[i] = a.activeKcal;
        if (a.restingHr != null) rhr[i] = a.restingHr;
      }
      final e = EnergyCalculator.daily(
        profile: p.copyWith(weightKg: w),
        steps: a?.steps ?? 0,
        distanceKm: a?.distanceKm,
        deviceActiveKcal: a?.activeKcal,
        workouts: d.workouts,
        intake: d.intake,
        fallbackIntakeKcal: 0,
      );
      final tdee = (e.bmr + e.neat + e.exercise) / 0.9;
      if (a != null || logged) burn[i] = tdee;
      if (logged) balance[i] = d.intake.kcal - tdee;
      if (d.workouts.isNotEmpty) {
        load[i] = d.workouts.fold<double>(0, (x, w) => x + w.load);
        volume[i] = d.workouts.fold<double>(0, (x, w) => x + w.volume);
        duration[i] = d.workouts.fold<int>(0, (x, w) => x + w.durationMin).toDouble();
        rpe[i] = d.workouts.map((w) => w.rpe).reduce((x, y) => x + y) / d.workouts.length;
      }
    }

    // ── Body ─────────────────────────────────────────────────────────
    final weightRaw = empty(), weightTrend = empty(), bmi = empty(), bodyFat = empty();
    for (final t in trend) {
      final i = idx[DateKeys.of(t.date)];
      if (i == null) continue;
      weightRaw[i] = t.raw;
      weightTrend[i] = t.trend;
      bmi[i] = t.trend / pow(p.heightCm / 100, 2);
    }
    for (final w in s.weights) {
      final i = idx[w.dayKey];
      if (i != null && w.bodyFatPct != null) bodyFat[i] = w.bodyFatPct;
    }

    // ── Sleep, readiness & recovery (recomputed for every past day) ─────
    final sleepH = empty(), sleepScore = empty(), bedtime = empty(), wake = empty();
    final regularity = empty(), debt = empty(), readiness = empty(), factor = empty(), acwr = empty();
    final monotony = empty();
    final rhrValues = <double>[];
    for (var i = 0; i < n; i++) {
      final d = s.days[i];
      final day = DateKeys.endOfDay(d.date);
      final ss = SleepCalculator.summarize(s.sleep, day, p.age);
      if (ss.lastNightMinutes != null) {
        sleepH[i] = ss.lastNightMinutes! / 60;
        if (ss.score != null) sleepScore[i] = ss.score!.toDouble();
        final main = s.sleep
            .where((x) => x.wakeDayKey == d.dayKey)
            .reduce((a, b) => a.minutes >= b.minutes ? a : b);
        // Clock times as hours; bedtimes after midnight continue past 24.
        final bh = main.start.hour + main.start.minute / 60;
        bedtime[i] = bh < 12 ? bh + 24 : bh;
        wake[i] = main.end.hour + main.end.minute / 60;
      }
      if (ss.midpointSdMinutes != null) regularity[i] = ss.midpointSdMinutes;
      if (ss.nightsLogged > 0) debt[i] = ss.debt7Minutes / 60;

      final ls = TrainingLoadCalculator.summarize(s.workouts, day);
      if (ls.acwr != null) acwr[i] = ls.acwr;
      if (ls.monotony != null && ls.acuteLoad > 0) monotony[i] = ls.monotony;

      // Nutrition inputs: 3 previous logged days.
      final prev = [
        for (var k = max(0, i - 3); k < i; k++)
          if (s.days[k].foodEntries > 0) s.days[k],
      ];
      final w = weightOn(d.date);
      double? energyRatio, ppk;
      if (prev.isNotEmpty) {
        final burnPrev = [for (var k = max(0, i - 3); k < i; k++) burn[k]].whereType<double>().toList();
        if (burnPrev.isNotEmpty) {
          energyRatio =
              prev.map((x) => x.intake.kcal).reduce((a, b) => a + b) /
              prev.length /
              (burnPrev.reduce((a, b) => a + b) / burnPrev.length);
        }
        ppk = prev.map((x) => x.intake.protein).reduce((a, b) => a + b) / prev.length / w;
      }
      final base = rhrValues.length >= 5 ? rhrValues.reduce((a, b) => a + b) / rhrValues.length : null;
      final hasAny = ss.nightsLogged > 0 || ls.sessions28 > 0 || prev.isNotEmpty;
      if (hasAny) {
        final r = RecoveryCalculator.compute(
          sleepScore: ss.score,
          debt7Minutes: ss.debt7Minutes,
          zone: ls.zone,
          acwr: ls.acwr,
          rhrToday: d.activity?.restingHr,
          rhrBaseline: base,
          sleepRatio: ss.lastNightMinutes == null ? null : ss.lastNightMinutes! / ss.needMinutes,
          energyRatio: energyRatio,
          proteinPerKg: ppk,
          age: p.age,
          load48h: ls.dailyLoads[27] + ls.dailyLoads[26],
          chronicDaily: ls.chronicWeeklyLoad / 7,
          baselineDays: ls.baselineDays,
        );
        readiness[i] = r.score.toDouble();
        factor[i] = r.factor;
      }
      if (d.activity?.restingHr != null) {
        rhrValues.add(d.activity!.restingHr!);
        if (rhrValues.length > 28) rhrValues.removeAt(0);
      }
    }

    // ── Weekly metrics ───────────────────────────────────────────────
    final first = DateKeys.startOfDay(dates.first);
    final monday = first.subtract(Duration(days: first.weekday - 1));
    final weeks = <DateTime>[];
    for (var w = monday; !w.isAfter(dates.last); w = w.add(const Duration(days: 7))) {
      weeks.add(w);
    }
    int weekOf(DateTime d) => DateKeys.startOfDay(d).difference(monday).inDays ~/ 7;
    final weeklyLoad = List<double?>.filled(weeks.length, 0);
    final weeklyWorkouts = List<double?>.filled(weeks.length, 0);
    final weeklySets = <MuscleGroup, List<int>>{
      for (final m in MuscleGroup.values)
        if (m != MuscleGroup.cardio) m: List<int>.filled(weeks.length, 0),
    };
    for (final w in s.workouts) {
      if (w.start.isBefore(first)) continue;
      final k = weekOf(w.start);
      if (k < 0 || k >= weeks.length) continue;
      weeklyLoad[k] = weeklyLoad[k]! + w.load;
      weeklyWorkouts[k] = weeklyWorkouts[k]! + 1;
      for (final set in w.sets) {
        weeklySets[set.muscle]?[k]++;
      }
    }

    // ── Exercises ────────────────────────────────────────────────────
    final byExercise = <String, List<(DateTime, double, double, double, double)>>{};
    final names = <String, (String, MuscleGroup)>{};
    for (final w
        in s.workouts.where((w) => !w.start.isBefore(first)).toList()
          ..sort((a, b) => a.start.compareTo(b.start))) {
      final per = <String, List<(int, double)>>{};
      for (final set in w.sets) {
        names[set.exerciseId] = (set.exerciseName, set.muscle);
        (per[set.exerciseId] ??= []).add((set.reps, set.weightKg));
      }
      per.forEach((id, sets) {
        final e1 = sets
            .where((x) => x.$1 > 0 && x.$1 <= 12)
            .map((x) => TrainingLoadCalculator.epley1Rm(x.$2, x.$1))
            .fold<double>(0, max);
        final top = sets.map((x) => x.$2).fold<double>(0, max);
        final vol = sets.fold<double>(0, (a, x) => a + x.$1 * x.$2);
        final reps = sets.map((x) => x.$1.toDouble()).fold<double>(0, max);
        (byExercise[id] ??= []).add((w.start, e1, top, vol, reps));
      });
    }
    final exercises = [
      for (final e in byExercise.entries)
        ExerciseProgress(
          id: e.key,
          name: names[e.key]!.$1,
          muscle: names[e.key]!.$2,
          dates: [for (final x in e.value) x.$1],
          e1rm: [for (final x in e.value) x.$2],
          topWeight: [for (final x in e.value) x.$3],
          volume: [for (final x in e.value) x.$4],
          bestReps: [for (final x in e.value) x.$5],
          relativeStrength: [for (final x in e.value) x.$2 > 0 ? x.$2 / weightOn(x.$1) : null],
        ),
    ]..sort((a, b) => b.sessions.compareTo(a.sessions));

    MetricSeries m(
      String id,
      ProgressCategory c,
      String title,
      String unit,
      List<double?> v,
      String about, {
      int decimals = 0,
      bool bars = false,
      double? target,
      bool? up,
      List<double?>? secondary,
    }) => MetricSeries(
      id: id,
      category: c,
      title: title,
      unit: unit,
      values: v,
      about: about,
      decimals: decimals,
      bars: bars,
      target: target,
      higherIsBetter: up,
      secondary: secondary,
    );

    const nu = ProgressCategory.nutrition, bo = ProgressCategory.body, ac = ProgressCategory.activity;
    const sl = ProgressCategory.sleep, tr = ProgressCategory.training, re = ProgressCategory.recovery;
    final series = <MetricSeries>[
      m('kcal', nu, 'Calories eaten', 'kcal', kcal, 'Total energy logged per day.', bars: true),
      m(
        'balance',
        nu,
        'Energy balance',
        'kcal',
        balance,
        'Intake minus estimated expenditure. Below zero = deficit (fat loss), above = surplus.',
        bars: true,
      ),
      m('protein', nu, 'Protein', 'g', protein, 'Grams of protein per day.', up: true),
      m(
        'protein_kg',
        nu,
        'Protein per kg body weight',
        'g/kg',
        proteinKg,
        '≥ 1.6 g/kg/day maximises muscle gain from training (Morton 2018).',
        decimals: 2,
        target: 1.6,
        up: true,
      ),
      m(
        'protein_share',
        nu,
        'Protein share of energy',
        '%',
        proteinShare,
        'Percentage of calories from protein.',
      ),
      m('carbs', nu, 'Carbohydrate', 'g', carbs, 'Grams of carbohydrate per day.'),
      m('fat', nu, 'Fat', 'g', fat, 'Grams of fat per day.'),
      m(
        'fiber',
        nu,
        'Fibre',
        'g',
        fiber,
        '25–30 g/day lowers mortality and heart disease (Reynolds 2019).',
        up: true,
      ),
      m('water', nu, 'Water', 'L', water, 'Litres of water logged.', decimals: 1, up: true),
      m(
        'weight',
        bo,
        'Weight & trend',
        'kg',
        weightRaw,
        'Dots: scale weigh-ins. Line: smoothed trend (EMA α 0.1) that removes water noise.',
        decimals: 1,
        secondary: weightTrend,
      ),
      m('bmi', bo, 'BMI (trend)', 'kg/m²', bmi, 'Body-mass index from the trend weight.', decimals: 1),
      m(
        'bodyfat',
        bo,
        'Body fat',
        '%',
        bodyFat,
        'Body-fat entries (Navy tape method or scale).',
        decimals: 1,
      ),
      m(
        'steps',
        ac,
        'Steps',
        'steps',
        steps,
        'Daily steps (phone / watch sync or manual).',
        bars: true,
        up: true,
      ),
      m('km', ac, 'Distance', 'km', km, 'Walking + running distance.', decimals: 1, up: true),
      m('active', ac, 'Active energy', 'kcal', active, 'Device-measured active calories.', up: true),
      m(
        'tdee',
        ac,
        'Total expenditure',
        'kcal',
        burn,
        'Estimated calories burned (BMR + movement + exercise + TEF).',
      ),
      m(
        'rhr',
        ac,
        'Resting heart rate',
        'bpm',
        rhr,
        'Falls as fitness improves; a rise of ≥ 5 bpm can signal fatigue or illness.',
        up: false,
      ),
      m(
        'sleep',
        sl,
        'Sleep duration',
        'h',
        sleepH,
        'Hours slept per night.',
        decimals: 1,
        bars: true,
        up: true,
      ),
      m(
        'sleep_score',
        sl,
        'Sleep score',
        '/100',
        sleepScore,
        'Duration vs need, regularity and quality.',
        up: true,
      ),
      m(
        'bedtime',
        sl,
        'Bedtime',
        'h',
        bedtime,
        'Clock time you fell asleep (24 = midnight, 25 = 1 am). Flatter is better.',
        decimals: 1,
      ),
      m('wake', sl, 'Wake time', 'h', wake, 'Clock time you woke up.', decimals: 1),
      m(
        'regularity',
        sl,
        'Sleep irregularity',
        'min',
        regularity,
        'Standard deviation of your sleep mid-point over 7 days. Under 30 min is ideal (Phillips 2017).',
        up: false,
      ),
      m(
        'debt',
        sl,
        'Sleep debt (7 days)',
        'h',
        debt,
        'Hours below your need over the past week.',
        decimals: 1,
        up: false,
      ),
      m('load', tr, 'Daily training load', 'AU', load, 'Session RPE × minutes (Foster).', bars: true),
      m(
        'acwr',
        tr,
        'Acute : chronic load (EWMA)',
        '',
        acwr,
        '0.8–1.3 is the sweet spot; > 1.5 raises injury risk (Gabbett 2016). Shown after a 3-week baseline.',
        decimals: 2,
        target: 1.3,
      ),
      m(
        'monotony',
        tr,
        'Training monotony',
        '',
        monotony,
        'Mean ÷ SD of daily load. > 2 means too little variation.',
        decimals: 1,
        up: false,
      ),
      m(
        'volume',
        tr,
        'Volume lifted',
        'kg',
        volume,
        'Σ reps × kg of all sets per day.',
        bars: true,
        up: true,
      ),
      m('duration', tr, 'Training time', 'min', duration, 'Minutes trained per day.', bars: true),
      m('rpe', tr, 'Session effort (RPE)', '/10', rpe, 'Average session RPE.', decimals: 1),
      m(
        'readiness',
        re,
        'Readiness',
        '/100',
        readiness,
        'Recomputed for every day from sleep, load, HR and nutrition.',
        up: true,
      ),
      m(
        'factor',
        re,
        'Recovery speed',
        '×',
        factor,
        '1.0 = typical. Lower = recovering slower because of sleep, under-eating, low protein, age or heavy load.',
        decimals: 2,
        up: true,
        target: 1.0,
      ),
    ];

    final weeklySeries = <MetricSeries>[
      MetricSeries(
        id: 'weekly_load',
        category: tr,
        title: 'Weekly training load',
        unit: 'AU / week',
        values: weeklyLoad,
        about: 'Total session load per week (Monday–Sunday).',
        bars: true,
      ),
      MetricSeries(
        id: 'weekly_workouts',
        category: tr,
        title: 'Workouts per week',
        unit: 'sessions',
        values: weeklyWorkouts,
        about: 'WHO recommends muscle-strengthening on 2+ days a week.',
        bars: true,
        target: 2,
        higherIsBetter: true,
      ),
    ];

    return ProgressReport(
      dates: dates,
      series: [...series, ...weeklySeries],
      exercises: exercises,
      weekStarts: weeks,
      weeklySets: weeklySets,
    );
  }
}
