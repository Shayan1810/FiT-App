import 'dart:math';

import '../../../../core/utils/date_utils.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../../workout/domain/entities/exercise.dart';
import '../../../workout/domain/entities/workout_session.dart';
import '../calculators/activity_calculator.dart';
import '../calculators/energy_calculator.dart';
import '../calculators/nutrition_targets_calculator.dart';
import '../calculators/recovery_calculator.dart';
import '../calculators/sleep_calculator.dart';
import '../calculators/training_load_calculator.dart';
import '../calculators/weight_trend_calculator.dart';
import '../entities/daily_briefing.dart';
import '../entities/health_snapshot.dart';
import '../../../transformation/domain/calculators/strength_calculator.dart';
import '../../../transformation/domain/calculators/transformation_calculator.dart';
import '../../../transformation/domain/entities/transformation_plan.dart';
import '../../../transformation/domain/usecases/toggle_plan_item.dart';
import 'coach_voice.dart';

/// The brain of FiT: turns a [HealthSnapshot] into a [DailyBriefing].
///
/// 100 % deterministic and offline — no AI model is involved. Each rule is a
/// small private method returning an [Insight] (or null), so rules can be
/// added, removed or unit-tested individually.
///
/// Runs inside a background isolate (`compute`) from `InsightsBloc`.
class InsightEngine {
  InsightEngine._();

  /// Typical daily steps assumed when no step data exists yet.
  static const int defaultSteps = 5000;

  /// Entry point. Pure function: same snapshot → same briefing.
  static DailyBriefing generate(HealthSnapshot s) {
    final p = s.profile;
    final now = s.now;
    final today = s.today;
    final bmrResult = EnergyCalculator.bmr(p);
    final bmr = bmrResult.bmr;

    // ── Body weight trend ───────────────────────────────────────────────
    final trend = WeightTrendCalculator.ema(s.weights);
    final weeklyRate = WeightTrendCalculator.weeklyRate(trend);

    // ── Energy for the last 7 days ─────────────────────────────────────
    final last7 = s.days.sublist(max(0, s.days.length - 7));
    final energies = [for (final d in last7) _energyFor(p, d)];
    final week = [
      for (var i = 0; i < last7.length; i++)
        DayEnergy(
          last7[i].dayKey,
          last7[i].date,
          last7[i].intake.kcal,
          energies[i].total,
          last7[i].foodEntries > 0,
        ),
    ];
    final todayEnergy = energies.last;

    // Completed days only (today is still in progress).
    final pastIdx = [for (var i = 0; i < last7.length - 1; i++) i];
    final activeIdx = pastIdx.where((i) => last7[i].activity != null).toList();
    final neatAvg = activeIdx.isEmpty
        ? EnergyCalculator.walkingKcal(
            km: EnergyCalculator.stepsToKm(defaultSteps, heightCm: p.heightCm, sex: p.sex),
            weightKg: p.weightKg,
          )
        : activeIdx.map((i) => energies[i].neat).reduce((a, b) => a + b) / activeIdx.length;
    final exAvg = pastIdx.isEmpty
        ? 0.0
        : pastIdx.map((i) => energies[i].exercise).reduce((a, b) => a + b) / pastIdx.length;
    // TEF ≈ 10 % of TDEE at energy balance ⇒ TDEE = (BMR + activity) / 0.9.
    final formulaTdee = (bmr + neatAvg + exAvg) / 0.9;

    // ── Adaptive TDEE (energy balance from logged intake + weight trend) ──
    final loggedIntakes = [
      for (final d in s.days.sublist(0, s.days.length - 1))
        if (d.foodEntries > 0 && d.intake.kcal >= 0.5 * bmr) d.intake.kcal,
    ];
    final adaptive = WeightTrendCalculator.adaptiveTdee(dailyIntakeKcal: loggedIntakes, trend: trend);
    var tdee = formulaTdee;
    var tdeeMethod = 'Formula: BMR (${bmrResult.method}) + activity + TEF';
    if (adaptive != null) {
      final a = adaptive.tdee.clamp(formulaTdee * 0.75, formulaTdee * 1.35);
      tdee = adaptive.confidence * a + (1 - adaptive.confidence) * formulaTdee;
      tdeeMethod = 'Adaptive: ${loggedIntakes.length} logged days + weight trend';
    }

    // Today's expenditure: baseline minus average exercise plus today's.
    final tdeeToday = tdee - exAvg + todayEnergy.exercise;
    final todayTrainingMin = today.workouts.fold<int>(0, (a, w) => a + w.durationMin);
    final todayTargets = NutritionTargetsCalculator.compute(
      profile: p,
      tdee: tdeeToday,
      bmr: bmr,
      trainingMinutes: todayTrainingMin,
    );

    // ── Transformation (plan targets override the generic ones) ─────────
    final tf = s.transformation == null
        ? null
        : TransformationCalculator.compute(
            input: s.transformation!,
            profile: p,
            weights: s.weights,
            now: now,
          );
    final tPlan = tf?.plan;
    final tomorrowDate = DateKeys.startOfDay(now).add(const Duration(days: 1));
    final planToday = tPlan != null && tPlan.hasBody && tPlan.contains(now);
    final planTomorrow = tPlan != null && tPlan.hasBody && tPlan.contains(tomorrowDate);
    final effectiveTodayTargets = planToday
        ? _planTargets(tPlan, now, todayTargets, tdeeToday)
        : todayTargets;

    // ── Steps ─────────────────────────────────────────────────────────
    final pastSteps = [for (final i in activeIdx) last7[i].activity!.steps.toDouble()];
    final avg7Steps = pastSteps.isEmpty ? null : pastSteps.reduce((a, b) => a + b) / pastSteps.length;
    final stepTarget = tPlan?.stepsGoal != null && tPlan!.contains(now)
        ? tPlan.stepsGoal!
        : ActivityCalculator.stepTarget(avg7Steps: avg7Steps, age: p.age);
    final todaySteps = today.activity?.steps ?? 0;
    final todayKm =
        today.activity?.distanceKm ??
        EnergyCalculator.stepsToKm(todaySteps, heightCm: p.heightCm, sex: p.sex);

    // ── Sleep, load, recovery ────────────────────────────────────────
    final sleep = SleepCalculator.summarize(
      s.sleep,
      now,
      p.age,
      needOverride: tPlan != null && tPlan.contains(now) ? (tPlan.sleepHours * 60).round() : null,
    );
    final load = TrainingLoadCalculator.summarize(s.workouts, now);
    final rhrHistory = [
      for (final d in s.days.sublist(0, s.days.length - 1))
        if (d.activity?.restingHr != null) d.activity!.restingHr!,
    ];
    final rhrBaseline = rhrHistory.length >= 5
        ? rhrHistory.reduce((a, b) => a + b) / rhrHistory.length
        : null;
    // Nutrition & damage inputs for the recovery factor (last 3 completed,
    // logged days).
    final recentLogged = [
      for (final d in s.days.sublist(max(0, s.days.length - 4), s.days.length - 1))
        if (d.foodEntries > 0 && d.intake.kcal >= 0.4 * bmr) d,
    ];
    final energyRatio = recentLogged.isEmpty
        ? null
        : recentLogged.map((d) => d.intake.kcal).reduce((a, b) => a + b) / recentLogged.length / tdee;
    final proteinPerKg = recentLogged.isEmpty
        ? null
        : recentLogged.map((d) => d.intake.protein).reduce((a, b) => a + b) /
              recentLogged.length /
              p.weightKg;
    final load48h = load.dailyLoads[load.dailyLoads.length - 1] + load.dailyLoads[load.dailyLoads.length - 2];

    final recovery = RecoveryCalculator.compute(
      sleepRatio: sleep.lastNightMinutes == null ? null : sleep.lastNightMinutes! / sleep.needMinutes,
      energyRatio: energyRatio,
      proteinPerKg: proteinPerKg,
      age: p.age,
      load48h: load48h,
      chronicDaily: load.chronicWeeklyLoad / 7,
      baselineDays: load.baselineDays,
      sleepScore: sleep.score,
      debt7Minutes: sleep.debt7Minutes,
      zone: load.zone,
      acwr: load.acwr,
      rhrToday: today.activity?.restingHr,
      rhrBaseline: rhrBaseline,
      sleepDetail: sleep.lastNightMinutes == null
          ? null
          : '${DateKeys.hm(sleep.lastNightMinutes!)} vs ${DateKeys.hm(sleep.needMinutes)} need',
    );

    // ── Tomorrow's plan ─────────────────────────────────────────────
    final training = tPlan != null && tPlan.contains(tomorrowDate)
        ? _planTraining(tPlan, tomorrowDate, recovery, p, s.workouts)
        : _recommendTraining(recovery, load, now, p);
    final tdeeTomorrow = tdee - exAvg + training.plannedKcal;
    var bed = SleepCalculator.recommendBedtime(sleep, now);
    if (tPlan != null && tPlan.contains(tomorrowDate)) {
      final wakeDay = now.hour < 4 ? DateKeys.startOfDay(now) : tomorrowDate;
      final wake = wakeDay.add(Duration(minutes: tPlan.wakeMin));
      final bedDay = tPlan.bedtimeMin >= 12 * 60 ? wakeDay.subtract(const Duration(days: 1)) : wakeDay;
      bed = (bedtime: bedDay.add(Duration(minutes: tPlan.bedtimeMin)), wake: wake);
    }
    final genericTomorrow = NutritionTargetsCalculator.compute(
      profile: p,
      tdee: tdeeTomorrow,
      bmr: bmr,
      trainingMinutes: training.isRest ? 0 : training.durationMin,
    );
    final plan = NextDayPlan(
      date: tomorrowDate,
      targets: planTomorrow
          ? _planTargets(tPlan, tomorrowDate, genericTomorrow, tdeeTomorrow)
          : genericTomorrow,
      steps: tPlan?.stepsGoal != null && tPlan!.contains(tomorrowDate) ? tPlan.stepsGoal! : stepTarget,
      training: training,
      bedtime: bed.bedtime,
      wake: bed.wake,
    );

    final todaySummary = TodaySummary(
      intake: today.intake,
      targets: effectiveTodayTargets,
      energy: todayEnergy,
      tdee: tdeeToday,
      tdeeMethod: tdeeMethod,
      steps: todaySteps,
      stepTarget: stepTarget,
      distanceKm: todayKm,
      waterMl: today.waterMl,
      trendWeight: trend.isEmpty ? null : trend.last.trend,
      weeklyRateKg: weeklyRate,
    );

    // ── Rules ───────────────────────────────────────────────────────
    final ctx = _Ctx(s, todaySummary, sleep, load, recovery, avg7Steps, weeklyRate, tf);
    final insights = <Insight?>[
      _shortSleep(ctx),
      _sleepDebt(ctx),
      _irregularSleep(ctx),
      _wellRested(ctx),
      _noSleepData(ctx),
      _lowProtein(ctx),
      _proteinHit(ctx),
      _overTarget(ctx),
      _lowFiber(ctx),
      _nothingLogged(ctx),
      _loggingStreak(ctx),
      _losingTooFast(ctx),
      _trendOppositeGoal(ctx),
      _gainingTooFast(ctx),
      _noWeighIn(ctx),
      _loadSpike(ctx),
      _underFuelled(ctx),
      _slowRecovery(ctx),
      _buildingBaseline(ctx),
      _monotony(ctx),
      _lowMuscleVolume(ctx),
      _inactiveWeek(ctx),
      _whoMinutesMet(ctx),
      _personalRecords(ctx),
      _sedentary(ctx),
      _stepsHit(ctx),
      _lowWater(ctx),
      _planNotStarted(ctx),
      _planYesterday(ctx),
      _planOpenToday(ctx),
      _planOnTrack(ctx),
      _planSkinStreak(ctx),
      _planWeighIn(ctx),
      _planStreak(ctx),
      _planStrength(ctx),
    ].whereType<Insight>().toList()..sort((a, b) => b.priority.compareTo(a.priority));

    final voice = CoachVoice.compose(
      profile: p,
      now: now,
      recovery: recovery,
      today: todaySummary,
      sleep: sleep,
      load: load,
      plan: plan,
      insights: insights,
      transformation: tf,
    );

    return DailyBriefing(
      generatedAt: now,
      greeting: voice.greeting,
      headline: voice.headline,
      narrative: voice.paragraphs,
      recovery: recovery,
      today: todaySummary,
      plan: plan,
      insights: insights,
      sleep: sleep,
      load: load,
      weightTrend: trend,
      week: week,
      transformation: tf,
    );
  }

  /// Nutrition targets taken from a transformation plan for [d]. The weekly
  /// calorie step is added to (or removed from) carbohydrate.
  static NutritionTargets _planTargets(
    TransformationPlan plan,
    DateTime d,
    NutritionTargets generic,
    double tdee,
  ) {
    final kcal = plan.kcalOn(d);
    final extra = kcal - plan.macros.kcal;
    return NutritionTargets(
      kcal: kcal,
      protein: plan.macros.protein,
      carbs: max(0, plan.macros.carbs + extra / 4),
      fat: plan.macros.fat,
      fiber: plan.macros.fiber ?? generic.fiber,
      waterMl: plan.macros.waterMl ?? generic.waterMl,
      goalDeltaKcal: kcal - tdee,
    );
  }

  /// Tomorrow's session from the plan, adjusted for readiness: the plan is
  /// kept, but on low-readiness days Nebula trims intensity.
  static TrainingRecommendation _planTraining(
    TransformationPlan plan,
    DateTime day,
    RecoveryScore r,
    UserProfile p,
    List<WorkoutSession> history,
  ) {
    final ws = plan.workoutsOn(day);
    if (ws.isEmpty) {
      return TrainingRecommendation(
        headline: 'Planned rest day',
        detail:
            'Rest day in your plan. Keep your planned walks and steps; muscle '
            'adapts during recovery, not during the workout.',
        rpeRange: '1–3',
        durationMin: 0,
        focus: const [],
        isRest: true,
        plannedKcal: 0,
      );
    }
    final minutes = ws.fold<int>(0, (a, w) => a + TogglePlanItem.sessionFor(w, day).durationMin);
    final kcal = ws.fold<double>(
      0,
      (a, w) => a + EnergyCalculator.workoutKcal(TogglePlanItem.sessionFor(w, day), weightKg: p.weightKg),
    );
    final focus = {
      for (final w in ws)
        for (final e in w.exercises) e.muscle,
    }.toList();
    final rpes = [for (final w in ws) w.rpe ?? 7];
    final rpe = rpes.reduce(max);
    String fmt(double kg) => kg % 1 == 0 ? kg.toStringAsFixed(0) : kg.toStringAsFixed(1);
    var detail = ws
        .map((w) {
          if (w.exercises.isEmpty) return w.title;
          final targets = w.exercises.map((e) {
            final sug = StrengthCalculator.suggest(e, StrengthCalculator.history(history, e.exerciseId));
            final load = sug.kg > 0 ? ' @ ${fmt(sug.kg)} kg' : '';
            final up = sug.isIncrease ? ' (+${fmt(sug.kg - sug.last!.topKg)})' : '';
            return '${e.name} ${sug.sets}×${sug.reps}$load$up';
          });
          return '${w.title}: ${targets.join(', ')}';
        })
        .join('. ');
    if (r.readiness == Readiness.recover) {
      detail +=
          '. Readiness is low: keep the session but drop one set per exercise and stop '
          '3 reps short of failure.';
    } else if (r.readiness == Readiness.moderate) {
      detail += '. Readiness is moderate: keep 2–3 reps in reserve today.';
    }
    return TrainingRecommendation(
      headline: ws.map((w) => w.title).join(' + '),
      detail: '$detail.',
      rpeRange: r.readiness == Readiness.recover ? '${max(1, rpe - 2)}' : '$rpe',
      durationMin: minutes,
      focus: focus,
      isRest: false,
      plannedKcal: kcal,
    );
  }

  /// Energy breakdown for one day of the snapshot.
  static EnergyBreakdown _energyFor(UserProfile p, DaySnapshot d) => EnergyCalculator.daily(
    profile: p,
    steps: d.activity?.steps ?? 0,
    distanceKm: d.activity?.distanceKm,
    deviceActiveKcal: d.activity?.activeKcal,
    workouts: d.workouts,
    intake: d.intake,
  );

  /// Chooses tomorrow's session from readiness and load (see handbook §5).
  static TrainingRecommendation _recommendTraining(
    RecoveryScore r,
    TrainingLoadSummary load,
    DateTime now,
    UserProfile p,
  ) {
    var band = r.readiness;
    // Load spikes override how fresh you feel.
    if (load.zone == AcwrZone.danger && (band == Readiness.primed || band == Readiness.ready)) {
      band = Readiness.moderate;
    } else if (load.zone == AcwrZone.caution && band == Readiness.primed) {
      band = Readiness.ready;
    }
    final focus = TrainingLoadCalculator.suggestFocus(
      load,
      now.add(const Duration(days: 1)),
      factor: r.factor,
    );
    final focusLabel = focus.isEmpty ? 'Full body' : focus.map((m) => m.label).join(' & ');

    late String headline, detail, rpe;
    late int minutes;
    late double met;
    var rest = false;
    switch (band) {
      case Readiness.primed:
        headline = 'Hard session · $focusLabel';
        detail =
            'You are well recovered. Go heavy on compound lifts or do '
            'intervals; push the last sets to RPE 8–9 (1–2 reps in reserve).';
        rpe = '8–9';
        minutes = 70;
        met = 6.0;
      case Readiness.ready:
        headline = 'Normal training · $focusLabel';
        detail = 'Train as planned at RPE 7–8, leaving 2–3 reps in reserve.';
        rpe = '7–8';
        minutes = 60;
        met = 5.0;
      case Readiness.moderate:
        headline = 'Light day · technique or Zone 2';
        detail =
            'Keep it easy: technique work at RPE 5–6, or 30–45 min of '
            'Zone-2 cardio (you can still speak in full sentences).';
        rpe = '5–6';
        minutes = 40;
        met = 4.0;
      case Readiness.recover:
        headline = 'Rest & recover';
        detail =
            'Take a rest day: a 20–30 min easy walk plus mobility. '
            'Muscle adapts during recovery, not during the workout.';
        rpe = '1–3';
        minutes = 25;
        met = 3.0;
        rest = true;
    }
    if (load.zone == AcwrZone.detraining && (band == Readiness.primed || band == Readiness.ready)) {
      detail +=
          ' Your recent load has dropped (ACWR < 0.8) — add a set per '
          'exercise to rebuild gradually (≤ 10 % more per week).';
    }
    return TrainingRecommendation(
      headline: headline,
      detail: detail,
      rpeRange: rpe,
      durationMin: minutes,
      focus: rest ? const [] : focus,
      isRest: rest,
      plannedKcal: max(0, met - 1) * p.weightKg * minutes / 60,
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // Rules. Each returns an Insight or null. Priorities: alert ≥ 90,
  // warning 60–89, info 40–59, positive 20–39.
  // ════════════════════════════════════════════════════════════════════

  static Insight? _shortSleep(_Ctx c) {
    final last = c.sleep.lastNightMinutes;
    if (last == null || last >= c.sleep.needMinutes - 60) return null;
    return Insight(
      id: 'sleep_short',
      category: InsightCategory.sleep,
      tone: InsightTone.warning,
      title: 'Short night: ${DateKeys.hm(last)}',
      message:
          'You slept ${DateKeys.hm(c.sleep.needMinutes - last)} less than '
          'you need. Expect more hunger today — front-load protein and keep '
          'caffeine before 14:00.',
      why:
          'One night of restricted sleep raises ghrelin and lowers leptin, '
          'increasing appetite, and during a diet short sleep shifts weight '
          'loss from fat towards lean mass.',
      reference: 'Spiegel K et al. (2004) Ann Intern Med; Nedeltcheva AV et al. (2010) Ann Intern Med',
      priority: 82,
    );
  }

  static Insight? _sleepDebt(_Ctx c) {
    if (c.sleep.debt7Minutes < 300) return null;
    return Insight(
      id: 'sleep_debt',
      category: InsightCategory.sleep,
      tone: InsightTone.alert,
      title: 'Sleep debt: ${DateKeys.hm(c.sleep.debt7Minutes)} this week',
      message:
          'Repay it gradually: go to bed 30 minutes earlier for the next '
          'few nights rather than sleeping in.',
      why:
          'Chronic restriction to 6 h/night produces cognitive deficits '
          'equivalent to total sleep deprivation, and people underestimate '
          'their own impairment.',
      reference: 'Van Dongen HPA et al. (2003) Sleep 26(2)',
      priority: 92,
    );
  }

  static Insight? _irregularSleep(_Ctx c) {
    final sd = c.sleep.midpointSdMinutes;
    if (sd == null || sd < 60) return null;
    return Insight(
      id: 'sleep_irregular',
      category: InsightCategory.sleep,
      tone: InsightTone.warning,
      title: 'Irregular sleep timing',
      message:
          'Your sleep midpoint varies by ±${sd.round()} min. Anchor your '
          'wake-up time (weekends too) — it is the strongest lever.',
      why:
          'Irregular sleep–wake timing desynchronises the circadian clock and '
          'is linked to worse mood, metabolism and performance, independent '
          'of total sleep duration.',
      reference: 'Phillips AJK et al. (2017) Sci Rep 7:3216',
      priority: 66,
    );
  }

  static Insight? _wellRested(_Ctx c) {
    final last = c.sleep.lastNightMinutes;
    if (last == null || last < c.sleep.needMinutes) return null;
    return Insight(
      id: 'sleep_good',
      category: InsightCategory.sleep,
      tone: InsightTone.positive,
      title: 'Well rested',
      message:
          'You met your sleep need (${DateKeys.hm(last)}). Good day for a '
          'quality training session.',
      why:
          'Adequate sleep supports glycogen restoration, growth-hormone '
          'release and motor learning.',
      reference: 'Watson NF et al. (2015) Sleep 38(6)',
      priority: 30,
    );
  }

  static Insight? _noSleepData(_Ctx c) {
    if (c.sleep.nightsLogged > 0) return null;
    return const Insight(
      id: 'sleep_none',
      category: InsightCategory.sleep,
      tone: InsightTone.info,
      title: 'No sleep data yet',
      message:
          'Log last night on the Sleep tab or sync your health app so I '
          'can score your recovery.',
      why: 'Sleep is the largest single input to the readiness score (40 %).',
      reference: 'Hirshkowitz M et al. (2015) Sleep Health 1(1)',
      priority: 45,
    );
  }

  /// Days of the last 7 (excluding today) that were logged.
  static List<DaySnapshot> _loggedPast(_Ctx c, [int n = 7]) {
    final past = c.s.days.sublist(0, c.s.days.length - 1);
    return past.sublist(max(0, past.length - n)).where((d) => d.foodEntries > 0).toList();
  }

  static Insight? _lowProtein(_Ctx c) {
    final logged = _loggedPast(c, 5);
    if (logged.length < 3) return null;
    final avg = logged.map((d) => d.intake.protein).reduce((a, b) => a + b) / logged.length;
    final target = c.today.targets.protein;
    if (avg >= 0.8 * target) return null;
    return Insight(
      id: 'protein_low',
      category: InsightCategory.nutrition,
      tone: InsightTone.warning,
      title: 'Protein is low (${avg.round()} g/day)',
      message:
          'Aim for ${target.round()} g. Spread it over 3–4 meals of '
          '25–40 g (eggs, paneer, dal + curd, chicken, whey).',
      why:
          'Protein intakes up to ~1.6 g/kg/day maximise muscle gains from '
          'training; in a deficit higher intakes protect lean mass.',
      reference: 'Morton RW et al. (2018) Br J Sports Med 52:376',
      priority: 74,
    );
  }

  static Insight? _proteinHit(_Ctx c) {
    if (c.today.intake.protein < c.today.targets.protein) return null;
    return Insight(
      id: 'protein_hit',
      category: InsightCategory.nutrition,
      tone: InsightTone.positive,
      title: 'Protein target reached',
      message:
          '${c.today.intake.protein.round()} g today — exactly what your '
          'muscles need to repair.',
      why: 'Meeting daily protein needs maximises muscle protein synthesis.',
      reference: 'Morton RW et al. (2018) Br J Sports Med 52:376',
      priority: 28,
    );
  }

  static Insight? _overTarget(_Ctx c) {
    if (c.s.now.hour < 18) return null;
    final over = c.today.intake.kcal - c.today.targets.kcal;
    if (over < c.today.targets.kcal * 0.15) return null;
    return Insight(
      id: 'kcal_over',
      category: InsightCategory.nutrition,
      tone: InsightTone.info,
      title: '${over.round()} kcal over today',
      message:
          'No need to compensate tomorrow — one day barely moves the '
          'trend. Just return to plan and add an extra 2 000 steps.',
      why:
          'Fat change follows the weekly energy balance; restrictive '
          '"make-up" days tend to trigger further over-eating.',
      reference: 'Hall KD et al. (2011) Lancet 378:826',
      priority: 48,
    );
  }

  static Insight? _lowFiber(_Ctx c) {
    final logged = _loggedPast(c);
    if (logged.length < 3) return null;
    final avg = logged.map((d) => d.intake.fiber).reduce((a, b) => a + b) / logged.length;
    if (avg >= 0.7 * c.today.targets.fiber) return null;
    return Insight(
      id: 'fiber_low',
      category: InsightCategory.nutrition,
      tone: InsightTone.info,
      title: 'Fibre is low (${avg.round()} g/day)',
      message:
          'Add a fruit, a bowl of dal/rajma, or swap white rice for '
          'brown rice or millets. Target ≈ ${c.today.targets.fiber.round()} g.',
      why:
          'Eating 25–29 g of fibre a day is associated with 15–30 % lower '
          'all-cause mortality and cardiovascular disease.',
      reference: 'Reynolds A et al. (2019) Lancet 393:434',
      priority: 44,
    );
  }

  static Insight? _nothingLogged(_Ctx c) {
    if (c.s.today.foodEntries > 0 || c.s.now.hour < 14) return null;
    return const Insight(
      id: 'log_nothing',
      category: InsightCategory.nutrition,
      tone: InsightTone.info,
      title: 'Nothing logged today',
      message:
          'Type what you ate in plain words ("2 roti, dal, curd") — I '
          'will work out the numbers.',
      why:
          'Self-monitoring of intake is one of the most consistent '
          'predictors of successful weight management.',
      reference: 'Burke LE et al. (2011) J Am Diet Assoc 111:92',
      priority: 50,
    );
  }

  static Insight? _loggingStreak(_Ctx c) {
    var streak = 0;
    for (var i = c.s.days.length - 2; i >= 0; i--) {
      if (c.s.days[i].foodEntries == 0) break;
      streak++;
    }
    if (c.s.today.foodEntries > 0) streak++;
    if (streak < 7) return null;
    return Insight(
      id: 'log_streak',
      category: InsightCategory.nutrition,
      tone: InsightTone.positive,
      title: '$streak-day logging streak',
      message:
          'Consistency beats perfection — this is exactly how lasting '
          'change is built.',
      why:
          'Frequent, consistent self-monitoring predicts greater weight '
          'loss in behavioural trials.',
      reference: 'Burke LE et al. (2011) J Am Diet Assoc 111:92',
      priority: 26,
    );
  }

  static Insight? _losingTooFast(_Ctx c) {
    final r = c.weeklyRate;
    final w = c.s.profile.weightKg;
    if (r == null || c.s.profile.goal != GoalType.lose || r > -0.01 * w) return null;
    return Insight(
      id: 'weight_fast_loss',
      category: InsightCategory.body,
      tone: InsightTone.warning,
      title: 'Losing ${r.abs().toStringAsFixed(2)} kg/week',
      message:
          'That is over 1 % of body weight per week. Add ~200 kcal/day '
          '(mostly carbs around training) to protect muscle and performance.',
      why:
          'Slower loss (≈ 0.5–1 % BW/week) preserves lean mass and strength '
          'better than faster loss in trained people.',
      reference: 'Garthe I et al. (2011) IJSNEM 21:97; Helms ER et al. (2014) JISSN 11:20',
      priority: 78,
    );
  }

  static Insight? _trendOppositeGoal(_Ctx c) {
    final r = c.weeklyRate;
    if (r == null) return null;
    final goal = c.s.profile.goal;
    final wrong = (goal == GoalType.lose && r > 0.1) || (goal == GoalType.gain && r < -0.1);
    if (!wrong) return null;
    final verb = goal == GoalType.lose ? 'up' : 'down';
    return Insight(
      id: 'weight_wrong_way',
      category: InsightCategory.body,
      tone: InsightTone.warning,
      title: 'Trend is going $verb',
      message:
          'Your smoothed weight moved ${r > 0 ? '+' : ''}${r.toStringAsFixed(2)} kg/week, '
          'against your goal. Check logging accuracy (oils, drinks, snacks) '
          'and stick to ${c.today.targets.kcal.round()} kcal.',
      why:
          'The trend line filters water noise; a 2–3 week trend in the '
          'wrong direction means average intake exceeds/undershoots needs.',
      reference: 'Hall KD et al. (2011) Lancet 378:826',
      priority: 70,
    );
  }

  static Insight? _gainingTooFast(_Ctx c) {
    final r = c.weeklyRate;
    final w = c.s.profile.weightKg;
    if (r == null || c.s.profile.goal != GoalType.gain || r < 0.005 * w * 1.5) return null;
    return Insight(
      id: 'weight_fast_gain',
      category: InsightCategory.body,
      tone: InsightTone.info,
      title: 'Gaining ${r.toStringAsFixed(2)} kg/week',
      message: 'Faster than ~0.5 % BW/week mostly adds fat. Trim ~150 kcal/day.',
      why:
          'Lean-mass accrual is slow; larger surpluses increase fat gain '
          'without extra muscle in trained lifters.',
      reference: 'Iraki J et al. (2019) Sports 7:154',
      priority: 55,
    );
  }

  static Insight? _noWeighIn(_Ctx c) {
    if (c.s.weights.isEmpty) {
      return const Insight(
        id: 'weight_none',
        category: InsightCategory.body,
        tone: InsightTone.info,
        title: 'Start weighing in',
        message:
            'Weigh yourself on waking, after the bathroom, 3+ times a '
            'week. I smooth out the daily noise for you.',
        why:
            'With ≥ 10 days of food logs and weigh-ins I can measure your '
            'real expenditure instead of estimating it.',
        reference: 'Walker J, The Hacker\'s Diet (EMA trend method)',
        priority: 42,
      );
    }
    final last = c.s.weights.map((w) => w.date).reduce((a, b) => a.isAfter(b) ? a : b);
    if (c.s.now.difference(last).inDays < 7) return null;
    return Insight(
      id: 'weight_stale',
      category: InsightCategory.body,
      tone: InsightTone.info,
      title: 'No weigh-in for ${c.s.now.difference(last).inDays} days',
      message: 'A quick morning weigh-in keeps your trend and calorie targets accurate.',
      why: 'Adaptive expenditure needs regular weight data.',
      reference: 'Hall KD et al. (2011) Lancet 378:826',
      priority: 41,
    );
  }

  static Insight? _loadSpike(_Ctx c) {
    if (c.load.zone != AcwrZone.danger && c.load.zone != AcwrZone.caution) return null;
    final danger = c.load.zone == AcwrZone.danger;
    return Insight(
      id: 'load_spike',
      category: InsightCategory.training,
      tone: danger ? InsightTone.alert : InsightTone.warning,
      title: 'Training load spike (ACWR ${c.load.acwr!.toStringAsFixed(2)})',
      message: danger
          ? 'This week is > 1.5× your usual. Reduce volume tomorrow and keep '
                'weekly increases ≤ 10 %.'
          : 'You are above your usual load — keep tomorrow controlled.',
      why:
          'When acute load exceeds ~1.5× chronic load, injury risk rises '
          'sharply; 0.8–1.3 is the "sweet spot".',
      reference: 'Gabbett TJ (2016) Br J Sports Med 50:273',
      priority: danger ? 95 : 72,
    );
  }

  static Insight? _underFuelled(_Ctx c) {
    final energy = c.recovery.components.where((x) => x.name == 'Energy intake').firstOrNull;
    final protein = c.recovery.components.where((x) => x.name == 'Protein').firstOrNull;
    final lowEnergy = energy != null && energy.value <= 0.6;
    final lowProtein = protein != null && protein.value < 0.75;
    if (!lowEnergy && !lowProtein) return null;
    return Insight(
      id: 'recovery_fuel',
      category: InsightCategory.nutrition,
      tone: InsightTone.warning,
      title: lowEnergy ? 'Under-fuelled for recovery' : 'Too little protein to repair',
      message: lowEnergy
          ? 'You ate ${energy.detail}. Your muscles rebuild slower in a big deficit — '
                'add 200–300 kcal on training days, mostly carbs + protein after the session.'
          : 'Only ${protein!.detail}. Aim for ≥ 1.6 g/kg so the damage from training can be repaired.',
      why:
          'A ~20 % energy deficit reduced muscle protein synthesis by ~27 %, and protein intake '
          'limits how much damaged muscle can be rebuilt after training.',
      reference:
          'Areta JL et al. (2014) Am J Physiol Endocrinol Metab 306:E989; Morton RW et al. (2018) Br J Sports Med',
      priority: 76,
    );
  }

  static Insight? _slowRecovery(_Ctx c) {
    final f = c.recovery.factor;
    if (f >= 0.85 || c.s.workouts.isEmpty) return null;
    final worst = [...c.recovery.factorParts]..sort((a, b) => a.$2.compareTo(b.$2));
    final causes = worst
        .where((p) => p.$2 < 0.97)
        .take(2)
        .map((p) => '${p.$1.toLowerCase()} (${p.$3})')
        .join(' and ');
    return Insight(
      id: 'recovery_slow',
      category: InsightCategory.training,
      tone: InsightTone.warning,
      title: 'Recovering ${((1 - f) * 100).round()} % slower than usual',
      message:
          'Mostly because of $causes. I have stretched the rest time of each muscle group '
          'accordingly — fix the cause to bounce back faster.',
      why:
          'Muscle repair depends on sleep (one night without sleep cut protein synthesis 18 %), '
          'energy and protein intake, age and how much damage the last sessions caused.',
      reference:
          'Lamon S et al. (2021) Physiol Rep 9:e14660; Fell J & Williams D (2008) J Aging Phys Act 16:97',
      priority: 68,
    );
  }

  static Insight? _buildingBaseline(_Ctx c) {
    if (c.load.hasBaseline || c.s.workouts.isEmpty) return null;
    final days = c.load.baselineDays.clamp(0, TrainingLoadCalculator.baselineDaysNeeded);
    return Insight(
      id: 'load_baseline',
      category: InsightCategory.training,
      tone: InsightTone.info,
      title: 'Building your training baseline ($days/${TrainingLoadCalculator.baselineDaysNeeded} days)',
      message:
          'Keep logging. Injury-risk warnings switch on after 3 weeks and '
          '${TrainingLoadCalculator.baselineSessionsNeeded} sessions, so one workout never looks like a "spike".',
      why:
          'The acute:chronic workload ratio compares this week with your usual — without a chronic '
          'base any session looks like a huge increase, which is meaningless.',
      reference: 'Williams S et al. (2017) Br J Sports Med 51:209 (EWMA ACWR)',
      priority: 35,
    );
  }

  static Insight? _monotony(_Ctx c) {
    final m = c.load.monotony;
    if (m == null || m <= 2.0 || c.load.acuteLoad < 600) return null;
    return Insight(
      id: 'load_monotony',
      category: InsightCategory.training,
      tone: InsightTone.warning,
      title: 'Monotonous training (${m.toStringAsFixed(1)})',
      message: 'Your days are all similarly hard. Alternate hard and easy days.',
      why:
          'High monotony (> 2) combined with high load (strain) precedes '
          'illness and overtraining in athletes.',
      reference: 'Foster C (1998) Med Sci Sports Exerc 30:1164',
      priority: 62,
    );
  }

  static Insight? _lowMuscleVolume(_Ctx c) {
    final strength = c.s.workouts.where((w) => w.sets.isNotEmpty).length;
    if (strength < 2) return null;
    const majors = [MuscleGroup.chest, MuscleGroup.back, MuscleGroup.legs, MuscleGroup.shoulders];
    final low = majors
        .where((m) => (c.load.weeklySetsByMuscle[m] ?? 0) < TrainingLoadCalculator.minWeeklySets)
        .toList();
    if (low.isEmpty) return null;
    return Insight(
      id: 'volume_low',
      category: InsightCategory.training,
      tone: InsightTone.info,
      title: 'Low weekly sets: ${low.map((m) => m.label).join(', ')}',
      message: 'Aim for at least 10 hard sets per muscle per week, split over 2+ sessions.',
      why:
          'A dose-response exists between weekly sets and hypertrophy; '
          '≥ 10 sets/week produces more growth than < 5.',
      reference: 'Schoenfeld BJ et al. (2017) J Sports Sci 35:1073',
      priority: 46,
    );
  }

  static Insight? _inactiveWeek(_Ctx c) {
    final since = c.s.now.subtract(const Duration(days: 7));
    if (c.s.workouts.any((w) => w.start.isAfter(since))) return null;
    return const Insight(
      id: 'train_none',
      category: InsightCategory.training,
      tone: InsightTone.info,
      title: 'No workouts this week',
      message: 'Even two 30-minute full-body sessions a week make a real difference.',
      why:
          'WHO recommends 150–300 min of moderate activity plus muscle-'
          'strengthening on 2+ days per week for all adults.',
      reference: 'Bull FC et al. (2020) Br J Sports Med 54:1451 (WHO guidelines)',
      priority: 52,
    );
  }

  static Insight? _whoMinutesMet(_Ctx c) {
    final since = c.s.now.subtract(const Duration(days: 7));
    final week = c.s.workouts.where((w) => w.start.isAfter(since));
    final minutes = week.fold<int>(0, (a, w) => a + w.durationMin);
    final strengthDays = week.where((w) => w.type == WorkoutType.strength).length;
    if (minutes < 150 || strengthDays < 2) return null;
    return Insight(
      id: 'who_met',
      category: InsightCategory.training,
      tone: InsightTone.positive,
      title: '$minutes active minutes this week',
      message: 'You meet the WHO activity guidelines, including strength work. Great job!',
      why:
          'Meeting both aerobic and strength guidelines is associated with '
          'substantially lower all-cause mortality.',
      reference: 'Bull FC et al. (2020) Br J Sports Med 54:1451',
      priority: 32,
    );
  }

  static Insight? _personalRecords(_Ctx c) {
    final weekStart = c.s.now.subtract(const Duration(days: 7));
    final best = <String, double>{};
    final names = <String, String>{};
    final recent = <String, double>{};
    for (final w in c.s.workouts) {
      for (final set in w.sets) {
        if (set.weightKg <= 0 || set.reps <= 0 || set.reps > 12) continue;
        final e = TrainingLoadCalculator.epley1Rm(set.weightKg, set.reps);
        names[set.exerciseId] = set.exerciseName;
        final map = w.start.isAfter(weekStart) ? recent : best;
        map[set.exerciseId] = max(map[set.exerciseId] ?? 0, e);
      }
    }
    final prs = recent.entries
        .where((e) => best.containsKey(e.key) && e.value > best[e.key]! * 1.005)
        .map((e) => names[e.key]!)
        .toList();
    if (prs.isEmpty) return null;
    return Insight(
      id: 'pr',
      category: InsightCategory.training,
      tone: InsightTone.positive,
      title: 'New PR: ${prs.take(2).join(', ')}',
      message:
          'Your estimated one-rep max went up this week. Progressive '
          'overload is working.',
      why:
          'Estimated 1RM (Epley: w × (1 + reps/30)) tracks strength across '
          'different rep ranges.',
      reference: 'Epley B (1985) Poundage Chart, Boyd Epley Workout',
      priority: 36,
    );
  }

  static Insight? _sedentary(_Ctx c) {
    final a = c.avg7Steps;
    if (a == null || a >= 5000) return null;
    return Insight(
      id: 'steps_low',
      category: InsightCategory.activity,
      tone: InsightTone.warning,
      title: 'Averaging ${a.round()} steps/day',
      message:
          'Add a 10-minute walk after two meals — that alone is '
          '≈ 2 000 steps and blunts post-meal glucose spikes.',
      why:
          'Each additional 1 000 daily steps is associated with lower '
          'mortality, with benefits up to ~8 000–10 000 steps.',
      reference: 'Paluch AE et al. (2022) Lancet Public Health 7:e219',
      priority: 64,
    );
  }

  static Insight? _stepsHit(_Ctx c) {
    if (c.today.steps < c.today.stepTarget) return null;
    return Insight(
      id: 'steps_hit',
      category: InsightCategory.activity,
      tone: InsightTone.positive,
      title: 'Step goal smashed',
      message:
          '${c.today.steps} steps (${c.today.distanceKm.toStringAsFixed(1)} km). '
          'Your NEAT is doing the heavy lifting.',
      why:
          'Non-exercise activity is the most variable part of daily energy '
          'expenditure between people.',
      reference: 'Levine JA (2002) Best Pract Res Clin Endocrinol Metab 16:679',
      priority: 27,
    );
  }

  static Insight? _lowWater(_Ctx c) {
    if (c.s.now.hour < 15) return null;
    if (c.today.waterMl >= c.today.targets.waterMl * 0.5) return null;
    return Insight(
      id: 'water_low',
      category: InsightCategory.hydration,
      tone: InsightTone.info,
      title: 'Only ${c.today.waterMl} ml of water',
      message:
          'Target ≈ ${c.today.targets.waterMl} ml. Keep a bottle in sight '
          'and drink with every meal.',
      why:
          'Even 2 % dehydration impairs endurance performance and '
          'concentration.',
      reference: 'EFSA (2010) EFSA Journal 8:1459; Sawka MN et al. (2007) ACSM Position Stand',
      priority: 40,
    );
  }

  // ── Transformation plan ───────────────────────────────────────────────

  static String _list(Iterable<String> xs) {
    final l = xs.toList();
    if (l.length <= 3) return l.join(', ');
    return '${l.take(3).join(', ')} and ${l.length - 3} more';
  }

  static Insight? _planNotStarted(_Ctx c) {
    final t = c.tf;
    if (t == null || t.started) return null;
    final days = 1 - t.dayNumber;
    return Insight(
      id: 'plan_soon',
      category: InsightCategory.plan,
      tone: InsightTone.info,
      title: days == 1 ? '${t.plan.name} starts tomorrow' : '${t.plan.name} starts in $days days',
      message:
          'Get ready: weigh yourself tomorrow morning on waking and stock the food in your plan. '
          'From day 1, just tick each item as you do it.',
      why: 'A fixed start and a prepared environment are two of the strongest predictors of habit success.',
      reference: 'Gollwitzer PM, Sheeran P (2006) Adv Exp Soc Psychol 38:69 (implementation intentions)',
      priority: 70,
    );
  }

  static Insight? _planYesterday(_Ctx c) {
    final y = c.tf?.yesterday;
    if (y == null || y.planned == 0) return null;
    final missed = [
      for (final i in y.items)
        if (!y.doneIds.contains(i.id)) i.title,
    ];
    if (y.adherence >= 0.9) {
      return Insight(
        id: 'plan_yesterday_done',
        category: InsightCategory.plan,
        tone: InsightTone.positive,
        title: 'Yesterday: ${y.done}/${y.planned} of the plan done',
        message: missed.isEmpty ? 'A perfect day. Repeat it today.' : 'Only missed: ${_list(missed)}.',
        why: 'Results in a transformation come from consistency across weeks, not from single perfect days.',
        reference: 'Lally P et al. (2010) Eur J Soc Psychol 40:998 (habit formation)',
        priority: 34,
      );
    }
    return Insight(
      id: 'plan_yesterday_missed',
      category: InsightCategory.plan,
      tone: y.adherence < 0.6 ? InsightTone.warning : InsightTone.info,
      title: 'Yesterday: ${y.done}/${y.planned} of the plan done',
      message:
          'Missed: ${_list(missed)}. If you did something else instead, log it '
          'so I can count it (Food / Train / Sleep).',
      why:
          'Missing one day barely matters; missing two in a row is how habits break. Get today back on plan.',
      reference: 'Lally P et al. (2010) Eur J Soc Psychol 40:998',
      priority: y.adherence < 0.6 ? 74 : 55,
    );
  }

  static Insight? _planOpenToday(_Ctx c) {
    final t = c.tf?.today;
    if (t == null || c.s.now.hour < 19) return null;
    final nowMin = c.s.now.hour * 60 + c.s.now.minute;
    final open = [
      for (final i in t.items)
        if (!t.doneIds.contains(i.id) && i.kind != PlanItemKind.sleep && i.sortTime <= nowMin) i.title,
    ];
    if (open.isEmpty) return null;
    return Insight(
      id: 'plan_open_today',
      category: InsightCategory.plan,
      tone: InsightTone.info,
      title: '${open.length} planned item${open.length == 1 ? '' : 's'} still open today',
      message: 'Still to tick: ${_list(open)}.',
      why: 'Ticking takes a second and keeps your energy balance and streak accurate.',
      reference: 'Burke LE et al. (2011) J Am Diet Assoc 111:92 (self-monitoring)',
      priority: 58,
    );
  }

  static Insight? _planOnTrack(_Ctx c) {
    final t = c.tf;
    if (t == null || !t.plan.hasBody || t.countedDays < 5 || t.estimatedWeightKg == null) return null;
    final planned = t.plannedWeightKg;
    final goal = t.plan.goalWeightKg;
    if (planned == null || goal == null || t.avgDailyBalance == null) return null;
    final losing = goal < (t.plan.startWeightKg ?? goal);
    final gap = t.estimatedWeightKg! - planned; // + = heavier than plan
    final behind = losing ? gap > 0.5 : gap < -0.5;
    final remaining = max(1, t.daysLeft);
    final neededPerDay =
        (goal - t.estimatedWeightKg!) *
        (losing ? TransformationStatus.kcalPerKgFat : TransformationStatus.kcalPerKgGain) /
        remaining;
    final avg = t.avgDailyBalance!.round();
    if (!behind) {
      return Insight(
        id: 'plan_on_track',
        category: InsightCategory.plan,
        tone: InsightTone.positive,
        title: losing
            ? 'On track: ~${t.fatLostKg.toStringAsFixed(1)} kg of fat lost'
            : 'On track: ~${t.massGainedKg.toStringAsFixed(1)} kg gained',
        message:
            'Average balance $avg kcal/day over ${t.countedDays} logged days puts you at '
            '~${t.estimatedWeightKg!.toStringAsFixed(1)} kg vs ${planned.toStringAsFixed(1)} kg planned.',
        why:
            'I count fat from the energy balance (7 700 kcal per kg), not the scale, because water '
            'and glycogen move the scale 1–2 kg from day to day.',
        reference: 'Hall KD (2008) Int J Obes 32:573',
        priority: 36,
      );
    }
    return Insight(
      id: 'plan_behind',
      category: InsightCategory.plan,
      tone: InsightTone.warning,
      title: 'Behind plan by ${gap.abs().toStringAsFixed(1)} kg',
      message:
          'To reach ${goal.toStringAsFixed(1)} kg in $remaining days you need a daily '
          '${neededPerDay < 0 ? 'deficit' : 'surplus'} of ~${neededPerDay.abs().round()} kcal '
          '(now ${avg.abs()} kcal ${avg < 0 ? 'deficit' : 'surplus'}). Log everything and hit every '
          'planned walk before cutting food further.',
      why: 'Energy balance decides the result; unlogged snacks and skipped activity are the usual gap.',
      reference: 'Hall KD (2008) Int J Obes 32:573; Lichtman SW et al. (1992) NEJM 327:1893',
      priority: 72,
    );
  }

  static Insight? _planSkinStreak(_Ctx c) {
    final t = c.tf;
    if (t == null || !t.plan.hasSkin) return null;
    final y = t.yesterday;
    if (y != null && y.skincare.isNotEmpty && !y.skincareComplete) {
      final missed = [
        for (final i in y.skincare)
          if (!y.doneIds.contains(i.id)) i.title,
      ];
      return Insight(
        id: 'plan_skin_missed',
        category: InsightCategory.plan,
        tone: InsightTone.info,
        title: 'Skincare missed yesterday',
        message: 'You skipped: ${_list(missed)}. Daily sunscreen and actives only work when used every day.',
        why:
            'Daily broad-spectrum sunscreen measurably slows skin ageing; skipping days removes the benefit.',
        reference: 'Hughes MCB et al. (2013) Ann Intern Med 158:781',
        priority: 45,
      );
    }
    if (t.skinStreak < 3) return null;
    return Insight(
      id: 'plan_skin_streak',
      category: InsightCategory.plan,
      tone: InsightTone.positive,
      title: 'Skincare streak: ${t.skinStreak} days',
      message: 'Every routine done. Visible change usually shows after 6–12 weeks of consistency.',
      why: 'Skin renews roughly every 4–6 weeks; actives such as niacinamide need about 8+ weeks.',
      reference: 'Bissett DL et al. (2005) Dermatol Surg 31:860',
      priority: 30,
    );
  }

  static Insight? _planWeighIn(_Ctx c) {
    final t = c.tf;
    if (t == null || !t.started || !t.plan.hasBody) return null;
    final since = DateKeys.startOfDay(t.plan.start);
    final recent = c.s.weights.where((w) => !w.date.isBefore(since));
    if (recent.isNotEmpty &&
        c.s.now.difference(recent.map((w) => w.date).reduce((a, b) => a.isAfter(b) ? a : b)).inDays < 3) {
      return null;
    }
    return const Insight(
      id: 'plan_weigh_in',
      category: InsightCategory.plan,
      tone: InsightTone.info,
      title: 'Add a morning weigh-in',
      message:
          'Weigh after waking and the bathroom, before eating. I use it to check the energy-balance '
          'estimate, not to judge a single day.',
      why: 'A smoothed scale trend confirms that the calorie numbers match reality over weeks.',
      reference: 'Walker J, The Hacker\'s Diet (EMA trend method)',
      priority: 44,
    );
  }

  static Insight? _planStreak(_Ctx c) {
    final t = c.tf;
    if (t == null || t.streak < 3) return null;
    return Insight(
      id: 'plan_streak',
      category: InsightCategory.plan,
      tone: InsightTone.positive,
      title: '${t.streak}-day plan streak',
      message: 'At least 80 % of the plan done ${t.streak} days in a row. Keep the chain going.',
      why:
          'Repeating behaviours in a stable context makes them automatic; on average it takes about 66 days.',
      reference: 'Lally P et al. (2010) Eur J Soc Psychol 40:998',
      priority: 32,
    );
  }

  static Insight? _planStrength(_Ctx c) {
    final t = c.tf;
    if (t == null || !t.started) return null;
    final comparable = [
      for (final x in t.strength)
        if (x.sessions >= 2 && x.e1rmChangePct != null) x,
    ];
    if (comparable.isEmpty) return null;
    final dropping = [
      for (final x in comparable)
        if (x.e1rmChangePct! <= -5) x,
    ];
    if (dropping.isNotEmpty && t.plan.hasBody) {
      final d = dropping.last;
      return Insight(
        id: 'plan_strength_down',
        category: InsightCategory.training,
        tone: InsightTone.warning,
        title: '${d.name} strength down ${d.e1rmChangePct!.abs().toStringAsFixed(0)} %',
        message:
            'Estimated 1RM ${d.first.e1rm.toStringAsFixed(0)} to ${d.latest.e1rm.toStringAsFixed(0)} kg since day 1. '
            'Keep protein high, sleep enough and avoid a deficit beyond ~1 % of body weight per week.',
        why: 'Losing strength during a cut is an early sign of losing muscle rather than fat.',
        reference: 'Helms ER et al. (2014) JISSN 11:20',
        priority: 66,
      );
    }
    final best = comparable.first;
    if (best.e1rmChangePct! < 2) return null;
    return Insight(
      id: 'plan_strength_up',
      category: InsightCategory.training,
      tone: InsightTone.positive,
      title: '${best.name} +${best.e1rmChangePct!.toStringAsFixed(0)} % stronger',
      message:
          'Estimated 1RM ${best.first.e1rm.toStringAsFixed(0)} to ${best.latest.e1rm.toStringAsFixed(0)} kg '
          'over ${best.sessions} sessions of this plan. Keep adding load when you hit all your reps.',
      why:
          'Progressive overload — adding load once the target reps are reached — drives strength and muscle gain.',
      reference: 'ACSM (2009) Med Sci Sports Exerc 41:687',
      priority: 33,
    );
  }
}

/// Bundles values shared by the rules.
class _Ctx {
  _Ctx(this.s, this.today, this.sleep, this.load, this.recovery, this.avg7Steps, this.weeklyRate, this.tf);
  final TransformationStatus? tf;
  final HealthSnapshot s;
  final TodaySummary today;
  final SleepSummary sleep;
  final TrainingLoadSummary load;
  final RecoveryScore recovery;
  final double? avg7Steps;
  final double? weeklyRate;
}
