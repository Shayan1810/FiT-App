import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/depth_card.dart';
import '../../../core/widgets/entrance.dart';
import '../../../core/widgets/gauge_3d.dart';
import '../../../core/widgets/nebula_orb.dart';
import '../../insights/domain/calculators/recovery_calculator.dart';
import '../../insights/domain/engine/coach_voice.dart';
import '../../insights/domain/entities/daily_briefing.dart';
import '../../insights/presentation/bloc/insights_bloc.dart';
import '../../insights/presentation/widgets/insight_tile.dart';
import '../../workout/domain/entities/exercise.dart';

/// Coach tab — Nebula speaks: briefing, readiness, tomorrow's plan, insights.
class CoachPage extends StatelessWidget {
  const CoachPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InsightsBloc, InsightsState>(
      builder: (context, s) {
        final b = s.briefing;
        if (b == null) return const Center(child: NebulaOrb(size: 120));
        return RefreshIndicator(
          onRefresh: () async => context.read<InsightsBloc>().add(const InsightsRefreshRequested()),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              SliverSafeArea(bottom: false, sliver: SliverToBoxAdapter(child: _Hero(b))),
              SliverList.list(
                children: [
                  for (final (i, p) in b.narrative.indexed) _Bubble(text: p, index: i),
                  const SectionHeader("Tomorrow's plan"),
                  _PlanCarousel(b.plan),
                  Entrance(index: 2, child: _Readiness(b.recovery)),
                  if (b.insights.isNotEmpty) const SectionHeader('Insights'),
                  for (final (i, insight) in b.insights.indexed)
                    Entrance(
                      index: 3 + i,
                      child: InsightTile(insight: insight),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Text(
                      'Expenditure: ${b.today.tdeeMethod}. ${CoachVoice.coachName} uses published formulas only — '
                      'tap any insight for the science. Not medical advice.',
                      style: AppText.caption,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 120),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero(this.b);
  final DailyBriefing b;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        children: [
          NebulaOrb(size: 170, energy: b.recovery.score / 100),
          Text(b.greeting, style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(b.headline, style: AppText.title.copyWith(fontSize: 22), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// A chat bubble from Nebula that "types in" after the previous one.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.index});
  final String text;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Entrance(
      index: index,
      step: 260,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 40, 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (index == 0) const NebulaOrb(size: 34) else const SizedBox(width: 34),
            const SizedBox(width: 8),
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: index == 0 ? AppColors.primary : AppColors.surface,
                  gradient: index == 0 ? AppColors.primaryGradient : null,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                    bottomLeft: Radius.circular(6),
                  ),
                  boxShadow: index == 0
                      ? AppShadows.colored(AppColors.primary, depth: 0.4)
                      : AppShadows.soft(depth: 0.4),
                ),
                child: Text(
                  text,
                  style: TextStyle(
                    height: 1.45,
                    fontSize: 14,
                    color: index == 0 ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cover-flow style 3D carousel of tomorrow's plan cards.
class _PlanCarousel extends StatefulWidget {
  const _PlanCarousel(this.p);
  final NextDayPlan p;

  @override
  State<_PlanCarousel> createState() => _PlanCarouselState();
}

class _PlanCarouselState extends State<_PlanCarousel> {
  final _ctrl = PageController(viewportFraction: 0.78);
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => setState(() => _page = _ctrl.page ?? 0));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final t = p.targets;
    final cards = <Widget>[
      _PlanCard(
        icon: Icons.restaurant_rounded,
        title: 'Fuel',
        big: '${fmtInt(t.kcal)} kcal',
        lines: [
          'Protein ${t.protein.round()} g',
          'Carbs ${t.carbs.round()} g · Fat ${t.fat.round()} g',
          'Fibre ${t.fiber.round()} g · Water ${(t.waterMl / 1000).toStringAsFixed(1)} L',
          if (t.goalDeltaKcal != 0)
            '${t.goalDeltaKcal < 0 ? 'Deficit' : 'Surplus'} ${fmtInt(t.goalDeltaKcal.abs())} kcal for your goal',
        ],
        style: DepthStyle.primary,
      ),
      _PlanCard(
        icon: p.training.isRest ? Icons.spa_rounded : Icons.fitness_center_rounded,
        title: 'Train',
        big: p.training.headline,
        lines: [
          p.training.detail,
          if (!p.training.isRest) 'RPE ${p.training.rpeRange} · ~${p.training.durationMin} min',
          if (p.training.focus.isNotEmpty)
            'Recovered & under-trained: ${p.training.focus.map((m) => m.label).join(', ')}',
        ],
        style: DepthStyle.dark,
      ),
      _PlanCard(
        icon: Icons.directions_walk_rounded,
        title: 'Move',
        big: '${fmtInt(p.steps)} steps',
        lines: const [
          'Progressive goal: last week\'s average + 1 000.',
          'Benefits plateau around 8–10k/day (Paluch 2022).',
        ],
        style: DepthStyle.accent,
        accent: AppColors.steps,
      ),
      _PlanCard(
        icon: Icons.bedtime_rounded,
        title: 'Sleep',
        big: 'Bed ${DateKeys.clock(p.bedtime)}',
        lines: [
          'Wake ${DateKeys.clock(p.wake)} — keep it consistent.',
          'No caffeine after 14:00; dim screens 1 h before bed.',
        ],
        style: DepthStyle.accent,
        accent: AppColors.sleep,
      ),
    ];
    return SizedBox(
      height: 250,
      child: PageView.builder(
        controller: _ctrl,
        itemCount: cards.length,
        itemBuilder: (context, i) {
          final d = (i - _page).clamp(-1.5, 1.5);
          return Transform(
            alignment: d > 0 ? Alignment.centerLeft : Alignment.centerRight,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(-d * 0.45)
              ..scaleByDouble(1 - d.abs() * 0.08, 1 - d.abs() * 0.08, 1, 1),
            child: Opacity(
              opacity: (1 - d.abs() * 0.35).clamp(0.3, 1.0),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                child: cards[i],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  _PlanCard({
    required this.icon,
    required this.title,
    required this.big,
    required this.lines,
    required this.style,
    Color? accent,
  }) : accent = accent ?? AppColors.primary;

  final IconData icon;
  final String title;
  final String big;
  final List<String> lines;
  final DepthStyle style;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DepthCard(
      style: style,
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(icon: icon),
              const SizedBox(width: 10),
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white70,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            big,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                for (final l in lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(l, style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.35)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Readiness extends StatelessWidget {
  const _Readiness(this.r);
  final RecoveryScore r;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: DepthCard(
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: Text('Readiness', style: AppText.title)),
                Pill(
                  r.readiness.label,
                  color: switch (r.readiness) {
                    Readiness.primed => AppColors.success,
                    Readiness.ready => AppColors.primary,
                    Readiness.moderate => AppColors.warning,
                    Readiness.recover => AppColors.danger,
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Gauge3D(value: r.score.toDouble(), caption: 'out of 100'),
            const SizedBox(height: 12),
            for (final c in r.components)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 96,
                      child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: c.value,
                              minHeight: 8,
                              backgroundColor: AppColors.primarySoft,
                              color: Color.lerp(
                                AppColors.danger,
                                AppColors.success,
                                math.pow(c.value, 1.5).toDouble(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${c.detail} · weight ${(c.weight * 100).round()} %',
                            style: AppText.caption.copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
