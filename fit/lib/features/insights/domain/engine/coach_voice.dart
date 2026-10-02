import 'package:intl/intl.dart';

import '../../../../core/utils/date_utils.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../calculators/recovery_calculator.dart';
import '../calculators/sleep_calculator.dart';
import '../calculators/training_load_calculator.dart';
import '../entities/daily_briefing.dart';

/// Turns numbers into the words of **Nebula**, FiT's coach persona.
///
/// Pure template-based natural-language generation (no AI model): the
/// output is predictable, instant, offline and every sentence is traceable
/// to a calculation.
class CoachVoice {
  CoachVoice._();

  static final NumberFormat _n = NumberFormat.decimalPattern();

  /// Name of the coach persona.
  static const String coachName = 'Nebula';

  /// Builds greeting, headline and narrative paragraphs.
  static ({String greeting, String headline, List<String> paragraphs}) compose({
    required UserProfile profile,
    required DateTime now,
    required RecoveryScore recovery,
    required TodaySummary today,
    required SleepSummary sleep,
    required TrainingLoadSummary load,
    required NextDayPlan plan,
    required List<Insight> insights,
  }) {
    final greeting = '${_timeGreeting(now)}, ${profile.firstName}.';
    final headline = _headline(recovery.readiness);
    final paragraphs = <String>[
      _recoveryParagraph(recovery, sleep, load),
      _todayParagraph(today, now),
      _tomorrowParagraph(plan),
      if (insights.isNotEmpty) _focusParagraph(insights.first),
    ];
    return (greeting: greeting, headline: headline, paragraphs: paragraphs);
  }

  /// "Good morning" / "Good afternoon" / "Good evening" / "Still up".
  static String _timeGreeting(DateTime now) {
    final h = now.hour;
    if (h < 4) return 'Still up';
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static String _headline(Readiness r) => switch (r) {
    Readiness.primed => "You're primed — let's make today count.",
    Readiness.ready => "You're ready to train well today.",
    Readiness.moderate => 'Take it a little easier today.',
    Readiness.recover => 'Your body is asking for recovery.',
  };

  static String _recoveryParagraph(RecoveryScore r, SleepSummary sleep, TrainingLoadSummary load) {
    final b = StringBuffer('Readiness is ${r.score}/100 (${r.readiness.label}). ');
    if (r.factor < 0.9) {
      b.write('You are recovering about ${((1 - r.factor) * 100).round()} % slower than usual. ');
    }
    if (sleep.lastNightMinutes != null) {
      b.write(
        'You slept ${DateKeys.hm(sleep.lastNightMinutes!)} against a '
        '${DateKeys.hm(sleep.needMinutes)} need',
      );
      b.write(
        sleep.debt7Minutes > 60 ? ', with ${DateKeys.hm(sleep.debt7Minutes)} of debt this week. ' : '. ',
      );
    } else {
      b.write("I don't have last night's sleep yet. ");
    }
    switch (load.zone) {
      case AcwrZone.sweetSpot:
        b.write(
          'Training load is in the sweet spot '
          '(ACWR ${load.acwr!.toStringAsFixed(2)}).',
        );
      case AcwrZone.caution:
      case AcwrZone.danger:
        b.write(
          'Training load jumped (ACWR ${load.acwr!.toStringAsFixed(2)}), '
          'so I am holding intensity back.',
        );
      case AcwrZone.detraining:
        b.write('Your training load has dipped below your usual.');
      case AcwrZone.unknown:
        b.write(
          load.sessions28 == 0
              ? 'Log a few workouts and I will track your training load.'
              : 'I am still learning your usual training load (${load.baselineDays.clamp(0, 21)}/21 days).',
        );
    }
    return b.toString();
  }

  static String _todayParagraph(TodaySummary t, DateTime now) {
    final eaten = t.intake.kcal.round();
    final target = t.targets.kcal.round();
    final b = StringBuffer();
    if (eaten == 0) {
      b.write(
        'Nothing logged yet today; your target is ${_n.format(target)} kcal '
        'with ${t.targets.protein.round()} g protein. ',
      );
    } else {
      final left = target - eaten;
      b.write(
        'So far ${_n.format(eaten)} of ${_n.format(target)} kcal '
        'and ${t.intake.protein.round()} of ${t.targets.protein.round()} g protein',
      );
      b.write(left >= 0 ? ' — ${_n.format(left)} kcal to go. ' : ' — ${_n.format(-left)} kcal over. ');
    }
    b.write(
      'You have walked ${_n.format(t.steps)} steps '
      '(${t.distanceKm.toStringAsFixed(1)} km) and burned an estimated '
      '${_n.format(t.tdee.round())} kcal in total.',
    );
    return b.toString();
  }

  static String _tomorrowParagraph(NextDayPlan p) {
    final t = p.targets;
    final train = p.training.isRest
        ? 'a rest day with an easy walk'
        : '${p.training.headline.toLowerCase()} for ~${p.training.durationMin} min '
              'at RPE ${p.training.rpeRange}';
    return 'For tomorrow I suggest ${_n.format(t.kcal.round())} kcal '
        '(P ${t.protein.round()} g · C ${t.carbs.round()} g · F ${t.fat.round()} g), '
        '$train, ${_n.format(p.steps)} steps and ${(t.waterMl / 1000).toStringAsFixed(1)} L of water. '
        'Lights out by ${DateKeys.clock(p.bedtime)} to wake refreshed at ${DateKeys.clock(p.wake)}.';
  }

  static String _focusParagraph(Insight i) {
    final lead = switch (i.tone) {
      InsightTone.alert => 'Most important',
      InsightTone.warning => 'One thing to fix',
      InsightTone.info => 'A small tip',
      InsightTone.positive => 'Something to celebrate',
    };
    return '$lead: ${i.title}. ${i.message}';
  }
}
