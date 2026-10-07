import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/depth_card.dart';
import '../../../core/widgets/entrance.dart';
import '../../../core/widgets/macro_bar.dart';
import '../../../core/widgets/nebula_orb.dart';
import '../../../core/widgets/ring_3d.dart';
import '../../activity/presentation/edit_steps_sheet.dart';
import '../../dashboard/presentation/today_page.dart';
import '../../insights/domain/entities/daily_briefing.dart';
import '../../insights/presentation/bloc/insights_bloc.dart';
import '../../nutrition/domain/entities/food_log_entry.dart';
import '../../nutrition/presentation/widgets/add_food_sheet.dart';
import '../../shell/main_shell.dart';
import '../../sleep/presentation/sleep_page.dart';
import '../../workout/presentation/pages/workout_editor_page.dart';
import '../domain/calculators/strength_calculator.dart';
import '../domain/calculators/transformation_calculator.dart';
import '../domain/entities/transformation_plan.dart';
import 'plan_editor_page.dart';
import 'transformation_cubit.dart';
import 'workout_log_sheet.dart';

/// Home of Transformation mode: progress hero, Nebula's note, today's
/// targets, the morning weigh-in and the daily checklist.
class TransformationPage extends StatelessWidget {
  const TransformationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<TransformationCubit, TransformationState>(
      listenWhen: (a, b) => b.message != null && a.message != b.message,
      listener: (context, s) => showToast(context, s.message!),
      child: BlocBuilder<TransformationCubit, TransformationState>(
        builder: (context, ts) {
          final plan = ts.plan;
          if (plan == null) return const SizedBox.shrink();
          return BlocBuilder<InsightsBloc, InsightsState>(
            builder: (context, ins) {
              final b = ins.briefing;
              final st = b?.transformation;
              final day = ts.day ?? DateKeys.startOfDay(DateTime.now());
              final items = plan.itemsFor(day);
              final isToday = DateKeys.sameDay(day, DateTime.now());
              var i = 0;
              return Scaffold(
                backgroundColor: Colors.transparent,
                body: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverSafeArea(
                      bottom: false,
                      sliver: SliverToBoxAdapter(
                        child: PageHeader(
                          title: plan.name,
                          subtitle: _subtitle(plan, st),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Full dashboard',
                                icon: const Icon(Icons.dashboard_rounded),
                                onPressed: () => Navigator.of(
                                  context,
                                ).push(MaterialPageRoute(builder: (_) => const _DashboardPage())),
                              ),
                              IconButton(
                                tooltip: 'Edit plan',
                                icon: const Icon(Icons.tune_rounded),
                                onPressed: () => openPlanEditor(context, plan),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SliverList.list(
                      children: [
                        if (st != null) Entrance(index: i++, child: _Hero(st)),
                        if (b != null) Entrance(index: i++, child: _NebulaNote(b)),
                        if (plan.contains(DateTime.now()) || plan.dayNumber(DateTime.now()) > 0)
                          Entrance(
                            index: i++,
                            child: _PlanDayStrip(plan: plan, selected: day, status: st),
                          ),
                        if (!plan.contains(day))
                          Entrance(index: i++, child: _Preview(plan))
                        else ...[
                          if (plan.hasBody && b != null && isToday)
                            Entrance(index: i++, child: _Targets(b, plan)),
                          if (plan.hasBody)
                            Entrance(
                              index: i++,
                              child: _WeighIn(day: day),
                            ),
                          for (final group in _groups(items))
                            Entrance(
                              index: i++,
                              child: _ChecklistGroup(
                                title: group.$1,
                                icon: group.$2,
                                items: group.$3,
                                checks: ts.checks,
                              ),
                            ),
                          if (st != null && st.strength.isNotEmpty)
                            Entrance(index: i++, child: _StrengthCard(st)),
                          Entrance(
                            index: i++,
                            child: _OffPlan(day: day),
                          ),
                        ],
                        const SizedBox(height: 150),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  static String _subtitle(TransformationPlan plan, TransformationStatus? st) {
    final n = plan.dayNumber(DateTime.now());
    final goal = plan.hasBody && plan.bodyGoal != null ? plan.bodyGoal!.label : 'Skin';
    final skin = plan.hasBody && plan.hasSkin ? ' + Skin' : '';
    if (n < 1) return 'Starts ${DateFormat('d MMM').format(plan.start)} · $goal$skin';
    return 'Day ${n.clamp(1, plan.totalDays)} of ${plan.totalDays} · $goal$skin';
  }

  /// Splits the checklist into parts of the day.
  static List<(String, IconData, List<PlanItem>)> _groups(List<PlanItem> items) {
    final groups = <(String, IconData, List<PlanItem>)>[
      ('Morning', Icons.wb_twilight_rounded, []),
      ('Afternoon', Icons.wb_sunny_rounded, []),
      ('Evening', Icons.nights_stay_rounded, []),
      ('Night', Icons.bedtime_rounded, []),
    ];
    for (final it in items) {
      final t = it.kind == PlanItemKind.sleep ? 0 : it.sortTime;
      final g = t < 12 * 60 ? 0 : (t < 17 * 60 ? 1 : (t < 21 * 60 ? 2 : 3));
      groups[g].$3.add(it);
    }
    return [
      for (final g in groups)
        if (g.$3.isNotEmpty) g,
    ];
  }
}

/// Opens the plan editor (create when [plan] is null).
Future<void> openPlanEditor(BuildContext context, [TransformationPlan? plan]) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlanEditorPage(initial: plan)));

/// The General-mode dashboard, reachable from Transformation mode.
class _DashboardPage extends StatelessWidget {
  const _DashboardPage();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('Dashboard')),
    body: const TodayPage(),
  );
}

// ── Hero ───────────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  const _Hero(this.st);
  final TransformationStatus st;

  @override
  Widget build(BuildContext context) {
    final plan = st.plan;
    final on = AppColors.onPrimary;
    final soft = on.withValues(alpha: 0.78);
    final gaining = plan.bodyGoal == BodyGoal.weightGain || (st.countedDays > 0 && st.netKcal > 0);
    final big = !plan.hasBody
        ? '${st.skinStreak}'
        : (gaining ? st.massGainedKg : st.fatLostKg).toStringAsFixed(1);
    final bigLabel = !plan.hasBody
        ? 'day skincare streak'
        : (gaining ? 'kg mass gained (est.)' : 'kg fat lost (est.)');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: DepthCard(
        style: DepthStyle.primary,
        tilt: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SingleRing(
                  progress: st.timeProgress,
                  color: on,
                  size: 92,
                  stroke: 10,
                  center: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        st.started ? '${st.daysLeft}' : '${1 - st.dayNumber}',
                        style: TextStyle(color: on, fontSize: 22, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        st.started ? 'days left' : 'to start',
                        style: TextStyle(color: soft, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        big,
                        style: TextStyle(color: on, fontSize: 38, fontWeight: FontWeight.w800, height: 1),
                      ),
                      Text(
                        bigLabel,
                        style: TextStyle(color: soft, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plan.hasBody
                            ? (st.countedDays == 0
                                  ? 'Tick or log meals to start counting'
                                  : 'from energy balance · ${st.countedDays} logged days')
                            : '${((st.adherenceAll ?? 0) * 100).round()} % of routines done',
                        style: TextStyle(color: soft, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (plan.hasBody) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  _stat('Estimated', st.estimatedWeightKg, 'kg', on, soft),
                  _stat('Plan today', st.plannedWeightKg, 'kg', on, soft),
                  _stat('Goal', plan.goalWeightKg, 'kg', on, soft),
                  if (st.estimatedBodyFatPct != null)
                    _stat('Body fat', st.estimatedBodyFatPct, '%', on, soft),
                ],
              ),
              if (st.trendWeightKg != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Scale trend ${st.trendWeightKg!.toStringAsFixed(1)} kg. Day-to-day water swings, '
                  'so FiT counts fat from your calories instead.',
                  style: TextStyle(color: soft, fontSize: 11),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, double? v, String unit, Color on, Color soft) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          v == null ? '–' : '${v.toStringAsFixed(1)} $unit',
          style: TextStyle(color: on, fontWeight: FontWeight.w700, fontSize: 15),
        ),
        Text(label, style: TextStyle(color: soft, fontSize: 11)),
      ],
    ),
  );
}

// ── Nebula ─────────────────────────────────────────────────────────────

class _NebulaNote extends StatelessWidget {
  const _NebulaNote(this.b);
  final DailyBriefing b;

  @override
  Widget build(BuildContext context) {
    final plan = b.insights.where((i) => i.category == InsightCategory.plan).toList();
    final top = plan.isNotEmpty ? plan.first : (b.insights.isEmpty ? null : b.insights.first);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: DepthCard(
        onTap: () => MainShell.goTo(context, AppTab.coach),
        child: Row(
          children: [
            NebulaOrb(size: 54, energy: b.recovery.score / 100),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(top?.title ?? b.headline, style: AppText.subtitle),
                  const SizedBox(height: 2),
                  Text(
                    top?.message ?? b.narrative.first,
                    style: AppText.caption,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

// ── Day strip ──────────────────────────────────────────────────────────

class _PlanDayStrip extends StatelessWidget {
  const _PlanDayStrip({required this.plan, required this.selected, required this.status});
  final TransformationPlan plan;
  final DateTime selected;
  final TransformationStatus? status;

  @override
  Widget build(BuildContext context) {
    final today = DateKeys.startOfDay(DateTime.now());
    final last = plan.contains(today) ? today : DateKeys.startOfDay(plan.end);
    final days = [
      for (var k = 6; k >= 0; k--)
        if (plan.contains(last.subtract(Duration(days: k)))) last.subtract(Duration(days: k)),
    ];
    final byKey = {for (final d in status?.days ?? const <PlanDay>[]) d.dayKey: d};
    return SizedBox(
      height: 82,
      child: ListView(
        scrollDirection: Axis.horizontal,
        reverse: true, // newest (today) first on the right
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          for (final d in days.reversed)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _DayChip(
                date: d,
                dayNumber: plan.dayNumber(d),
                selected: DateKeys.sameDay(d, selected),
                adherence: byKey[DateKeys.of(d)]?.adherence,
              ),
            ),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.date, required this.dayNumber, required this.selected, this.adherence});
  final DateTime date;
  final int dayNumber;
  final bool selected;
  final double? adherence;

  @override
  Widget build(BuildContext context) {
    final a = adherence;
    final color = a == null
        ? AppColors.textMuted
        : (a >= 0.8 ? AppColors.success : (a >= 0.5 ? AppColors.warning : AppColors.danger));
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.read<TransformationCubit>().selectDay(date);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 52,
        decoration: BoxDecoration(
          gradient: selected ? AppColors.primaryGradient : null,
          color: selected ? null : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (selected ? AppColors.primary : Colors.black).withValues(alpha: selected ? 0.35 : 0.06),
              blurRadius: selected ? 12 : 6,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              DateFormat('E').format(date),
              style: TextStyle(fontSize: 11, color: selected ? AppColors.onPrimary : AppColors.textSecondary),
            ),
            Text(
              'D$dayNumber',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.onPrimary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Targets ────────────────────────────────────────────────────────────

class _Targets extends StatelessWidget {
  const _Targets(this.b, this.plan);
  final DailyBriefing b;
  final TransformationPlan plan;

  @override
  Widget build(BuildContext context) {
    final t = b.today;
    final cardio = b.transformation?.today == null ? 0 : _cardioMinutes(b);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: DepthCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text("Today's targets", style: AppText.subtitle)),
                Pill(
                  '${(t.intake.kcal - t.tdee).round()} kcal balance',
                  color: t.intake.kcal <= t.targets.kcal ? AppColors.success : AppColors.warning,
                ),
              ],
            ),
            const SizedBox(height: 14),
            MacroBar(
              label: 'Calories',
              value: t.intake.kcal,
              target: t.targets.kcal,
              color: AppColors.burn,
              unit: 'kcal',
            ),
            const SizedBox(height: 10),
            MacroBar(
              label: 'Protein',
              value: t.intake.protein,
              target: t.targets.protein,
              color: AppColors.protein,
            ),
            const SizedBox(height: 10),
            MacroBar(label: 'Carbs', value: t.intake.carbs, target: t.targets.carbs, color: AppColors.carbs),
            const SizedBox(height: 10),
            MacroBar(label: 'Fat', value: t.intake.fat, target: t.targets.fat, color: AppColors.fat),
            if (plan.stepsGoal != null) ...[
              const SizedBox(height: 10),
              MacroBar(
                label: 'Steps',
                value: t.steps.toDouble(),
                target: plan.stepsGoal!.toDouble(),
                color: AppColors.steps,
                unit: '',
              ),
            ],
            if (plan.cardioMinutesGoal != null) ...[
              const SizedBox(height: 10),
              MacroBar(
                label: 'Cardio',
                value: cardio.toDouble(),
                target: plan.cardioMinutesGoal!.toDouble(),
                color: AppColors.water,
                unit: 'min',
              ),
            ],
          ],
        ),
      ),
    );
  }

  static int _cardioMinutes(DailyBriefing b) {
    final day = b.transformation!.today!;
    // Minutes of cardio items ticked today.
    return day.items
        .where((i) => i.kind == PlanItemKind.cardio && day.doneIds.contains(i.id))
        .fold<int>(0, (a, i) => a + (i.durationMin ?? 0));
  }
}

// ── Weigh-in ───────────────────────────────────────────────────────────

class _WeighIn extends StatefulWidget {
  const _WeighIn({required this.day});
  final DateTime day;

  @override
  State<_WeighIn> createState() => _WeighInState();
}

class _WeighInState extends State<_WeighIn> {
  final _kg = TextEditingController();

  @override
  void dispose() {
    _kg.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TransformationCubit>();
    final w = cubit.weightOn(widget.day);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: DepthCard(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            const IconBadge(icon: Icons.monitor_weight_rounded, color: AppColors.info, onDark: false),
            const SizedBox(width: 12),
            Expanded(
              child: w != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${w.kg.toStringAsFixed(1)} kg', style: AppText.subtitle),
                        Text('Morning weigh-in saved', style: AppText.caption),
                      ],
                    )
                  : TextField(
                      controller: _kg,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Morning weight',
                        suffixText: 'kg',
                        isDense: true,
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            w != null
                ? IconButton(
                    tooltip: 'Change',
                    icon: const Icon(Icons.edit_rounded),
                    onPressed: () => _edit(context, w.kg),
                  )
                : FilledButton(
                    onPressed: () {
                      final kg = double.tryParse(_kg.text.replaceAll(',', '.'));
                      if (kg == null || kg < 25 || kg > 350) {
                        showToast(context, 'Enter a weight between 25 and 350 kg.');
                        return;
                      }
                      FocusScope.of(context).unfocus();
                      cubit.logWeight(kg);
                      _kg.clear();
                    },
                    child: const Text('Save'),
                  ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, double current) async {
    final c = TextEditingController(text: current.toStringAsFixed(1));
    final kg = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Morning weight'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(suffixText: 'kg'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, double.tryParse(c.text.replaceAll(',', '.'))),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (kg != null && kg >= 25 && kg <= 350 && context.mounted) {
      await context.read<TransformationCubit>().logWeight(kg);
    }
  }
}

// ── Checklist ──────────────────────────────────────────────────────────

/// Icon and colour of a plan item kind.
(IconData, Color) planItemStyle(PlanItem i) => switch (i.kind) {
  PlanItemKind.meal => (Icons.restaurant_rounded, AppColors.burn),
  PlanItemKind.workout => (Icons.fitness_center_rounded, AppColors.primary),
  PlanItemKind.cardio => (Icons.directions_walk_rounded, AppColors.steps),
  PlanItemKind.supplement => (Icons.medication_rounded, AppColors.info),
  PlanItemKind.skincare => (Icons.face_retouching_natural_rounded, AppColors.fat),
  PlanItemKind.habit => (Icons.spa_rounded, AppColors.water),
  PlanItemKind.sleep => (Icons.bedtime_rounded, AppColors.sleep),
};

/// One-line summary under a plan item.
String planItemSummary(PlanItem i) {
  final parts = <String>[
    if (i.time != null && i.kind != PlanItemKind.sleep) TransformationPlan.clockOf(i.time!),
    switch (i.kind) {
      PlanItemKind.meal when i.facts != null =>
        '${i.facts!.kcal.round()} kcal · P ${i.facts!.protein.round()} · C ${i.facts!.carbs.round()} · F ${i.facts!.fat.round()}',
      PlanItemKind.workout =>
        i.exercises.isEmpty
            ? '${i.durationMin ?? 60} min'
            : '${i.exercises.length} exercises · ${i.durationMin ?? '~'} min',
      PlanItemKind.cardio =>
        '${i.durationMin ?? 30} min${i.distanceKm != null ? ' · ${i.distanceKm!.toStringAsFixed(1)} km' : ''}',
      _ => i.detail,
    },
  ];
  return parts.where((p) => p.isNotEmpty).join(' · ');
}

class _ChecklistGroup extends StatelessWidget {
  const _ChecklistGroup({required this.title, required this.icon, required this.items, required this.checks});
  final String title;
  final IconData icon;
  final List<PlanItem> items;
  final Set<String> checks;

  @override
  Widget build(BuildContext context) {
    final done = items.where((i) => checks.contains(i.id)).length;
    final open = [
      for (final i in items)
        if (!checks.contains(i.id)) i,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: DepthCard(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 4, 4),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(title, style: AppText.subtitle)),
                  Text('$done/${items.length}', style: AppText.caption),
                  if (open.length > 1)
                    TextButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        context.read<TransformationCubit>().completeAll(open);
                      },
                      child: const Text('Tick all'),
                    ),
                ],
              ),
            ),
            for (final it in items) _PlanTile(item: it, done: checks.contains(it.id)),
          ],
        ),
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({required this.item, required this.done});
  final PlanItem item;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = planItemStyle(item);
    final summary = planItemSummary(item);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showDetails(context, item),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: done ? AppColors.textMuted : AppColors.textPrimary,
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (summary.isNotEmpty)
                    Text(summary, style: AppText.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            _CheckButton(
              done: done,
              color: color,
              label: item.title,
              onChanged: (v) {
                v ? HapticFeedback.mediumImpact() : HapticFeedback.selectionClick();
                context.read<TransformationCubit>().toggle(item, v);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Raised 3D tick button that pops when checked.
class _CheckButton extends StatelessWidget {
  const _CheckButton({required this.done, required this.color, required this.onChanged, required this.label});
  final bool done;
  final Color color;
  final String label;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: done,
      button: true,
      label: '$label done',
      child: GestureDetector(
        onTap: () => onChanged(!done),
        child: AnimatedScale(
          scale: done ? 1.0 : 0.92,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutBack,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: done
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color.lerp(AppColors.success, Colors.white, 0.25)!, AppColors.success],
                    )
                  : null,
              color: done ? null : AppColors.surfaceAlt,
              border: Border.all(color: done ? Colors.transparent : AppColors.divider, width: 2),
              boxShadow: done
                  ? [
                      BoxShadow(
                        color: AppColors.success.withValues(alpha: 0.45),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Icon(Icons.check_rounded, size: 20, color: done ? Colors.white : Colors.transparent),
          ),
        ),
      ),
    );
  }
}

Future<void> _showDetails(BuildContext context, PlanItem item) {
  final cubit = context.read<TransformationCubit>();
  return showAppSheet(
    context,
    BlocProvider.value(
      value: cubit,
      child: BlocBuilder<TransformationCubit, TransformationState>(
        builder: (context, st) {
          final done = st.checks.contains(item.id);
          final (icon, color) = planItemStyle(item);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconBadge(icon: icon, color: color, onDark: false),
                      const SizedBox(width: 12),
                      Expanded(child: Text(item.title, style: AppText.title)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${item.kind.label} · ${item.daysLabel}'
                    '${item.time != null ? ' · ${TransformationPlan.clockOf(item.time!)}' : ''}',
                    style: AppText.caption,
                  ),
                  if (item.detail.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(item.detail, style: AppText.body),
                  ],
                  if (item.facts != null) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Pill('${item.facts!.kcal.round()} kcal', color: AppColors.burn),
                        Pill('P ${item.facts!.protein.round()} g', color: AppColors.protein),
                        Pill('C ${item.facts!.carbs.round()} g', color: AppColors.carbs),
                        Pill('F ${item.facts!.fat.round()} g', color: AppColors.fat),
                      ],
                    ),
                  ],
                  if (item.exercises.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text("Today's targets (progressive overload)", style: AppText.subtitle),
                    const SizedBox(height: 4),
                    for (final sug in cubit.suggestionsFor(item))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(sug.exercise.name, style: AppText.body)),
                                Text(
                                  '${sug.sets} × ${sug.reps}${sug.kg > 0 ? ' @ ${_kgStr(sug.kg)} kg' : ''}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: sug.isIncrease ? AppColors.success : AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            Text(sug.reason, style: AppText.caption),
                          ],
                        ),
                      ),
                  ],
                  if (item.kind.autoLogs) ...[
                    const SizedBox(height: 12),
                    Text(
                      done
                          ? 'Logged automatically. Untick to remove it again.'
                          : item.kind == PlanItemKind.workout && item.exercises.isNotEmpty
                          ? 'Ticking repeats your last session of this workout. Use "Log sets" to record new weights and reps.'
                          : 'Ticking logs this automatically. Did something different? Log it your way below.',
                      style: AppText.caption,
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      if (item.kind == PlanItemKind.workout && item.exercises.isNotEmpty) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              showWorkoutLogSheet(context, item);
                            },
                            icon: const Icon(Icons.edit_note_rounded),
                            label: const Text('Log sets'),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ] else if (item.kind.autoLogs) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _logDifferently(context, item);
                            },
                            icon: const Icon(Icons.edit_note_rounded),
                            label: const Text('Log differently'),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            cubit.toggle(item, !done);
                            Navigator.pop(context);
                          },
                          icon: Icon(done ? Icons.undo_rounded : Icons.check_rounded),
                          label: Text(done ? 'Mark not done' : 'Mark done'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}

void _logDifferently(BuildContext context, PlanItem item) {
  switch (item.kind) {
    case PlanItemKind.meal:
      showAddFoodSheet(context, item.slot ?? MealSlotX.forTime(DateTime.now()));
    case PlanItemKind.workout:
    case PlanItemKind.cardio:
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WorkoutEditorPage()));
    case PlanItemKind.sleep:
      showLogSleepSheet(context);
    default:
      break;
  }
}

/// Read-only preview of day 1 shown before the plan starts.
class _Preview extends StatelessWidget {
  const _Preview(this.plan);
  final TransformationPlan plan;

  @override
  Widget build(BuildContext context) {
    final items = plan.itemsFor(plan.start);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: DepthCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Day 1 · ${DateFormat('EEEE d MMMM').format(plan.start)}', style: AppText.subtitle),
            const SizedBox(height: 4),
            Text(
              'Your checklist starts then. Weigh yourself on waking, then tick each item as you do it.',
              style: AppText.caption,
            ),
            const SizedBox(height: 10),
            for (final it in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Icon(planItemStyle(it).$1, size: 18, color: planItemStyle(it).$2),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 46,
                      child: Text(TransformationPlan.clockOf(it.sortTime), style: AppText.caption),
                    ),
                    Expanded(child: Text(it.title, style: AppText.body)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _kgStr(double v) => v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

/// Strength change per exercise since day 1 of the plan.
class _StrengthCard extends StatelessWidget {
  const _StrengthCard(this.st);
  final TransformationStatus st;

  @override
  Widget build(BuildContext context) {
    final list = st.strength.take(6).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: DepthCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up_rounded, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(child: Text('Strength since day 1', style: AppText.subtitle)),
              ],
            ),
            const SizedBox(height: 4),
            Text('Estimated 1-rep max (Epley) of your first vs latest session.', style: AppText.caption),
            const SizedBox(height: 8),
            for (final x in list)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(x.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                            x.first.e1rm > 0
                                ? 'e1RM ${x.first.e1rm.toStringAsFixed(0)} to ${x.latest.e1rm.toStringAsFixed(0)} kg · '
                                      'top ${_kgStr(x.latest.topKg)} kg · ${x.sessions} sessions'
                                : 'best ${x.latest.sets.map((s) => s.$1).fold(0, (a, b) => a > b ? a : b)} reps · ${x.sessions} sessions',
                            style: AppText.caption,
                          ),
                        ],
                      ),
                    ),
                    _change(x),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _change(StrengthChange x) {
    final pct = x.e1rmChangePct;
    if (x.sessions < 2) return Pill('new', color: AppColors.textSecondary);
    if (pct == null) {
      final r = x.repsChange;
      return Pill('${r >= 0 ? '+' : ''}$r reps', color: r >= 0 ? AppColors.success : AppColors.danger);
    }
    return Pill(
      '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)} %',
      color: pct >= 0 ? AppColors.success : AppColors.danger,
      icon: pct >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
    );
  }
}

/// Quick logging for anything outside the plan.
class _OffPlan extends StatelessWidget {
  const _OffPlan({required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    Widget chip(IconData icon, String label, VoidCallback onTap) => ActionChip(
      avatar: Icon(icon, size: 18, color: AppColors.primary),
      label: Text(label),
      onPressed: onTap,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Did something outside the plan?', style: AppText.subtitle),
          const SizedBox(height: 4),
          Text('Log it and it counts like everything else.', style: AppText.caption),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              chip(
                Icons.restaurant_rounded,
                'Food',
                () => showAddFoodSheet(context, MealSlotX.forTime(DateTime.now())),
              ),
              chip(
                Icons.fitness_center_rounded,
                'Workout',
                () =>
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WorkoutEditorPage())),
              ),
              chip(Icons.directions_walk_rounded, 'Steps', () => showEditStepsSheet(context, day: day)),
              chip(Icons.bedtime_rounded, 'Sleep', () => showLogSleepSheet(context)),
            ],
          ),
        ],
      ),
    );
  }
}
