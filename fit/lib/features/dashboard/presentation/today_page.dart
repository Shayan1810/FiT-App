import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/ambient_motion.dart';
import '../../../core/widgets/bars_3d.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/depth_card.dart';
import '../../../core/widgets/entrance.dart';
import '../../../core/widgets/macro_bar.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/nebula_orb.dart';
import '../../../core/widgets/ring_3d.dart';
import '../../insights/domain/calculators/recovery_calculator.dart';
import '../../insights/domain/entities/daily_briefing.dart';
import '../../insights/presentation/bloc/insights_bloc.dart';
import '../../insights/presentation/widgets/insight_tile.dart';
import '../../nutrition/presentation/bloc/nutrition_bloc.dart';
import '../../profile/presentation/bloc/profile_bloc.dart';
import '../../profile/presentation/log_weight_sheet.dart';
import '../../profile/presentation/profile_page.dart';
import '../../settings/presentation/settings_page.dart';
import '../../shell/main_shell.dart';
import '../../transformation/domain/repositories/transformation_repository.dart';
import '../../transformation/presentation/transformation_cubit.dart';
import '../../transformation/presentation/transformation_page.dart';

/// Invites the user to start (or resume) a transformation; hidden while
/// Transformation mode is running.
class _TransformationCta extends StatelessWidget {
  const _TransformationCta();

  @override
  Widget build(BuildContext context) {
    final st = context.watch<TransformationCubit>().state;
    final now = DateTime.now();
    if (st.isActive(now)) return const SizedBox.shrink();
    final resumable = st.plan != null && !st.plan!.isFinished(now);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: DepthCard(
        style: DepthStyle.dark,
        onTap: () => resumable
            ? context.read<TransformationCubit>().setMode(AppMode.transformation)
            : openPlanEditor(context),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            IconBadge(icon: Icons.flag_rounded, color: AppColors.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    resumable ? 'Resume ${st.plan!.name}' : 'Start a transformation',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    resumable
                        ? 'Switch to Transformation mode and see today\'s checklist.'
                        : 'Plan your diet, training, cardio, sleep and skincare once. Then just tick each day.',
                    style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}

/// Today — the dashboard. Everything at a glance, every card tappable.
class TodayPage extends StatelessWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InsightsBloc, InsightsState>(
      builder: (context, s) {
        final b = s.briefing;
        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => context.read<InsightsBloc>().add(const InsightsRefreshRequested()),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              const SliverSafeArea(bottom: false, sliver: SliverToBoxAdapter(child: _Header())),
              if (b == null)
                const SliverFillRemaining(child: Center(child: NebulaOrb(size: 110)))
              else
                SliverList.list(
                  children: [
                    Entrance(index: 0, child: _CoachHero(b)),
                    const _TransformationCta(),
                    Entrance(index: 1, child: _MetricGrid(b)),
                    Entrance(index: 2, child: _FlipSwitcher(b)),
                    Entrance(index: 3, child: _ActivityRow(b)),
                    Entrance(index: 4, child: _WeekCard(b)),
                    if (b.insights.isNotEmpty) ...[
                      SectionHeader(
                        'Nebula noticed',
                        action: 'See all',
                        onAction: () => MainShell.goTo(context, AppTab.coach),
                      ),
                      for (final (i, insight) in b.insights.take(2).indexed)
                        Entrance(
                          index: 5 + i,
                          child: InsightTile(insight: insight),
                        ),
                    ],
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

/// "Hi, Alex" + pulsing status dot + avatar (original header, refined).
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final profile = context.select((ProfileBloc b) => b.state.profile);
    final photo = profile?.photoPath;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hi, ${profile?.firstName ?? 'there'}', style: AppText.display),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const _PulseDot(),
                    const SizedBox(width: 8),
                    Text(
                      'FiT · ${DateFormat('EEEE, d MMM').format(DateTime.now())}',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsPage())),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfilePage())),
            child: Hero(
              tag: 'avatar',
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: AppShadows.colored(AppColors.primary, depth: 0.4),
                ),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primarySoft,
                  backgroundImage: photo != null && File(photo).existsSync() ? FileImage(File(photo)) : null,
                  child: photo == null
                      ? Text(
                          (profile?.firstName.isNotEmpty ?? false)
                              ? profile!.firstName[0].toUpperCase()
                              : 'U',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The green "online" dot from the original app that floats and glows.
class _PulseDot extends StatelessWidget {
  const _PulseDot();

  @override
  Widget build(BuildContext context) {
    final a = AmbientMotion.of(context);
    return AnimatedBuilder(
      animation: a,
      builder: (context, _) {
        final v = math.sin(a.value * 2 * math.pi * 3);
        return Transform.translate(
          offset: Offset(0, v * 1.5),
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.success.withValues(alpha: 0.5 + 0.2 * v),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Purple hero card: Nebula's one-line take + readiness.
class _CoachHero extends StatelessWidget {
  const _CoachHero(this.b);
  final DailyBriefing b;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: DepthCard(
        style: DepthStyle.primary,
        tilt: true,
        onTap: () => MainShell.goTo(context, AppTab.coach),
        padding: const EdgeInsets.fromLTRB(14, 16, 18, 16),
        child: Row(
          children: [
            NebulaOrb(size: 86, energy: b.recovery.score / 100),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.greeting, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(
                    b.headline,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Pill('Readiness ${b.recovery.score}', color: Colors.white, icon: Icons.bolt_rounded),
                      const SizedBox(width: 6),
                      Pill(b.recovery.readiness.label, color: Colors.white),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}

/// Calories IN / OUT / Net / Weight — the original 2×2 grid, live.
class _MetricGrid extends StatelessWidget {
  const _MetricGrid(this.b);
  final DailyBriefing b;

  @override
  Widget build(BuildContext context) {
    final t = b.today;
    final profileWeight = context.select((ProfileBloc p) => p.state.profile?.weightKg);
    final weight = t.trendWeight ?? profileWeight ?? 0;
    final rate = t.weeklyRateKg;
    final net = t.net;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  icon: Icons.restaurant_rounded,
                  value: t.intake.kcal,
                  label: 'Calories IN',
                  caption: 'of ${fmtInt(t.targets.kcal)} target',
                  onTap: () => MainShell.goTo(context, AppTab.food),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MetricCard(
                  icon: Icons.local_fire_department_rounded,
                  value: t.tdee,
                  label: 'Calories OUT',
                  caption: 'BMR ${fmtInt(t.energy.bmr)} + move',
                  style: DepthStyle.accent,
                  accent: AppColors.primaryDeep,
                  phase: 0.2,
                  onTap: () => MainShell.goTo(context, AppTab.train),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  icon: net <= 0 ? Icons.trending_down_rounded : Icons.trending_up_rounded,
                  value: net,
                  label: 'Net balance',
                  caption: net <= 0 ? 'deficit so far' : 'surplus so far',
                  style: DepthStyle.light,
                  accent: net <= 0 ? AppColors.success : AppColors.burn,
                  phase: 0.1,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MetricCard(
                  icon: Icons.monitor_weight_rounded,
                  value: weight,
                  decimals: 1,
                  unit: 'kg',
                  label: 'Weight trend',
                  caption: rate == null
                      ? 'tap the pen to log'
                      : '${rate >= 0 ? '+' : ''}${rate.toStringAsFixed(2)} kg/week',
                  style: DepthStyle.dark,
                  phase: 0.3,
                  trailing: GestureDetector(
                    onTap: () => showLogWeightSheet(context),
                    child: const Icon(Icons.edit_rounded, color: Colors.white70, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Macros ⇄ Energy breakdown card with a 3D flip and the original circular
/// button bar.
class _FlipSwitcher extends StatefulWidget {
  const _FlipSwitcher(this.b);
  final DailyBriefing b;

  @override
  State<_FlipSwitcher> createState() => _FlipSwitcherState();
}

class _FlipSwitcherState extends State<_FlipSwitcher> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final t = widget.b.today;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 650),
            transitionBuilder: (child, anim) {
              final rotate = Tween(
                begin: math.pi / 2,
                end: 0.0,
              ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutBack));
              return AnimatedBuilder(
                animation: rotate,
                child: child,
                builder: (context, child) => Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0015)
                    ..rotateY(child!.key == ValueKey(_i) ? rotate.value : -rotate.value),
                  child: Opacity(opacity: anim.value.clamp(0.0, 1.0), child: child),
                ),
              );
            },
            layoutBuilder: (current, previous) =>
                Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
            child: _i == 0
                ? _MacroCard(key: const ValueKey(0), t: t)
                : _EnergyCard(key: const ValueKey(1), t: t),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.slate900,
            borderRadius: BorderRadius.circular(30),
            boxShadow: AppShadows.dark(depth: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RoundButton(
                icon: Icons.pie_chart_rounded,
                selected: _i == 0,
                onTap: () => setState(() => _i = 0),
              ),
              const SizedBox(width: 8),
              _RoundButton(
                icon: Icons.local_fire_department_rounded,
                selected: _i == 1,
                onTap: () => setState(() => _i = 1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.selected, required this.onTap});
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? AppColors.primary : AppColors.slate700,
          boxShadow: selected ? AppShadows.glow() : const [],
        ),
        child: AnimatedScale(
          scale: selected ? 1.1 : 1,
          duration: const Duration(milliseconds: 200),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _MacroCard extends StatelessWidget {
  const _MacroCard({super.key, required this.t});
  final TodaySummary t;

  @override
  Widget build(BuildContext context) {
    return DepthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Macronutrients', style: AppText.title),
          const SizedBox(height: 14),
          MacroBar(
            label: 'Protein',
            value: t.intake.protein,
            target: t.targets.protein,
            color: AppColors.protein,
          ),
          const SizedBox(height: 12),
          MacroBar(
            label: 'Carbohydrate',
            value: t.intake.carbs,
            target: t.targets.carbs,
            color: AppColors.carbs,
          ),
          const SizedBox(height: 12),
          MacroBar(label: 'Fat', value: t.intake.fat, target: t.targets.fat, color: AppColors.fat),
          const SizedBox(height: 12),
          MacroBar(label: 'Fibre', value: t.intake.fiber, target: t.targets.fiber, color: AppColors.fiber),
        ],
      ),
    );
  }
}

class _EnergyCard extends StatelessWidget {
  const _EnergyCard({super.key, required this.t});
  final TodaySummary t;

  @override
  Widget build(BuildContext context) {
    final e = t.energy;
    final parts = [
      ('BMR', e.bmr, AppColors.primary, e.bmrMethod),
      ('Steps & movement', e.neat, AppColors.steps, 'NEAT'),
      ('Workouts', e.exercise, AppColors.burn, 'EAT'),
      ('Digesting food', e.tef, AppColors.carbs, 'TEF'),
    ];
    final total = e.total <= 0 ? 1 : e.total;
    return DepthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Energy burned', style: AppText.title)),
              Text(
                '${fmtInt(e.total)} kcal',
                style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Stacked 3D bar.
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 22,
              child: Row(
                children: [
                  for (final p in parts)
                    if (p.$2 > 0)
                      Expanded(
                        flex: (p.$2 / total * 1000).round().clamp(1, 1000),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color.lerp(p.$3, Colors.white, 0.35)!,
                                p.$3,
                                Color.lerp(p.$3, Colors.black, 0.2)!,
                              ],
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          for (final p in parts)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: p.$3, borderRadius: BorderRadius.circular(3)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(p.$1, style: const TextStyle(fontWeight: FontWeight.w500)),
                  ),
                  Text(p.$4, style: AppText.caption),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 64,
                    child: Text(
                      '${fmtInt(p.$2)} kcal',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Text(t.tdeeMethod, style: AppText.caption),
        ],
      ),
    );
  }
}

/// Steps · Sleep · Water rings.
class _ActivityRow extends StatelessWidget {
  const _ActivityRow(this.b);
  final DailyBriefing b;

  @override
  Widget build(BuildContext context) {
    final t = b.today;
    final s = b.sleep;
    final water = context.select(
      (NutritionBloc n) => DateKeys.sameDay(n.state.day, DateTime.now()) ? n.state.waterMl : t.waterMl,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: _RingTile(
              title: 'Steps',
              progress: t.stepTarget == 0 ? 0 : t.steps / t.stepTarget,
              color: AppColors.steps,
              value: t.steps >= 1000 ? '${(t.steps / 1000).toStringAsFixed(1)}k' : '${t.steps}',
              caption: 'of ${(t.stepTarget / 1000).toStringAsFixed(1)}k',
              onTap: () => MainShell.goTo(context, AppTab.train),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _RingTile(
              title: 'Sleep',
              progress: (s.lastNightMinutes ?? 0) / s.needMinutes,
              color: AppColors.sleep,
              value: s.lastNightMinutes == null ? '—' : DateKeys.hm(s.lastNightMinutes!).replaceAll(' ', ''),
              caption: 'need ${s.needMinutes ~/ 60}h',
              onTap: () => MainShell.goTo(context, AppTab.sleep),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _RingTile(
              title: 'Water',
              progress: water / t.targets.waterMl,
              color: AppColors.water,
              value: '${(water / 1000).toStringAsFixed(1)}L',
              caption: 'tap +250 ml',
              onTap: () => context.read<NutritionBloc>().add(NutritionWaterAdded(250, day: DateTime.now())),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingTile extends StatelessWidget {
  const _RingTile({
    required this.title,
    required this.progress,
    required this.color,
    required this.value,
    required this.caption,
    required this.onTap,
  });

  final String title;
  final double progress;
  final Color color;
  final String value;
  final String caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DepthCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
      child: Column(
        children: [
          SingleRing(
            progress: progress.isFinite ? progress : 0,
            color: color,
            size: 76,
            stroke: 9,
            center: Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(caption, style: AppText.caption.copyWith(fontSize: 10.5)),
        ],
      ),
    );
  }
}

/// 7-day intake vs expenditure, isometric bars.
class _WeekCard extends StatelessWidget {
  const _WeekCard(this.b);
  final DailyBriefing b;

  @override
  Widget build(BuildContext context) {
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      child: DepthCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This week', style: AppText.title),
            const SizedBox(height: 4),
            Row(
              children: [
                _Legend(color: AppColors.primary, label: 'Eaten'),
                SizedBox(width: 14),
                _Legend(color: AppColors.slate600, label: 'Burned'),
              ],
            ),
            const SizedBox(height: 12),
            Bars3D(
              data: [
                for (final d in b.week)
                  BarDatum(
                    label: letters[d.date.weekday - 1],
                    value: d.intake,
                    value2: d.expenditure,
                    highlight: DateKeys.sameDay(d.date, DateTime.now()),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
      ),
      const SizedBox(width: 6),
      Text(label, style: AppText.caption),
    ],
  );
}
