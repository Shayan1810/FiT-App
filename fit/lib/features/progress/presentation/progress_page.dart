import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/depth_card.dart';
import '../../../core/widgets/entrance.dart';
import '../../workout/domain/entities/exercise.dart';
import '../domain/progress_calculator.dart';
import 'progress_cubit.dart';
import 'widgets/series_chart.dart';

/// Progress tab: every tracked and derived metric over 30 days – 1 year,
/// per-exercise strength curves and a weekly sets-per-muscle heat-map.
class ProgressPage extends StatelessWidget {
  const ProgressPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: BlocBuilder<ProgressCubit, ProgressState>(
        builder: (context, st) {
          final r = st.report;
          return RefreshIndicator(
            onRefresh: () => context.read<ProgressCubit>().load(),
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                SliverSafeArea(
                  bottom: false,
                  sliver: SliverToBoxAdapter(
                    child: PageHeader(
                      title: 'Progress',
                      subtitle: 'Every metric, over time',
                      trailing: st.loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: _RangeSelector(st.range)),
                SliverToBoxAdapter(child: _CategoryChips(st.category)),
                if (r == null)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else
                  SliverList.list(children: _content(r, st.category)),
                const SliverToBoxAdapter(child: SizedBox(height: 140)),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _content(ProgressReport r, ProgressCategory c) {
    final series = r.of(c);
    final withData = series.where((s) => s.count > 0).toList();
    final empty = series.where((s) => s.count == 0).toList();
    var i = 0;
    return [
      if (c == ProgressCategory.training) ...[
        Entrance(index: i++, child: _ExerciseCard(r.exercises)),
        Entrance(index: i++, child: _MuscleHeatmap(r)),
      ],
      for (final s in withData)
        Entrance(
          index: i++,
          child: _SeriesCard(series: s, dates: s.id.startsWith('weekly_') ? r.weekStarts : r.dates),
        ),
      if (empty.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Text(
            'No data yet in this range: ${empty.map((s) => s.title).join(', ')}.',
            style: AppText.caption,
          ),
        ),
      if (withData.isEmpty && c != ProgressCategory.training)
        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: EmptyState(
            icon: Icons.show_chart_rounded,
            title: 'Nothing to chart yet',
            message: 'Log a few days of ${c.label.toLowerCase()} data and your trends appear here.',
          ),
        ),
    ];
  }
}

/// 30 D / 90 D / 6 M / 1 Y segmented selector.
class _RangeSelector extends StatelessWidget {
  const _RangeSelector(this.range);
  final ProgressRange range;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Container(
        height: 42,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(21)),
        child: LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth / ProgressRange.values.length;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutBack,
                  left: w * range.index,
                  top: 0,
                  bottom: 0,
                  width: w,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(17),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (final r in ProgressRange.values)
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            context.read<ProgressCubit>().setRange(r);
                          },
                          child: Center(
                            child: Text(
                              r.label,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: r == range ? AppColors.onPrimary : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips(this.category);
  final ProgressCategory category;

  static IconData _icon(ProgressCategory c) => switch (c) {
    ProgressCategory.nutrition => Icons.restaurant_rounded,
    ProgressCategory.body => Icons.monitor_weight_rounded,
    ProgressCategory.activity => Icons.directions_walk_rounded,
    ProgressCategory.sleep => Icons.nightlight_round,
    ProgressCategory.training => Icons.fitness_center_rounded,
    ProgressCategory.recovery => Icons.battery_charging_full_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final c in ProgressCategory.values)
            ChoiceChip(
              avatar: Icon(
                _icon(c),
                size: 16,
                color: c == category ? AppColors.onPrimary : AppColors.primary,
              ),
              label: Text(c.label),
              selected: c == category,
              showCheckmark: false,
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                fontWeight: FontWeight.w600,
                color: c == category ? AppColors.onPrimary : AppColors.textPrimary,
              ),
              onSelected: (_) => context.read<ProgressCubit>().setCategory(c),
            ),
        ],
      ),
    );
  }
}

/// Colour of a metric (domain colours where they exist).
Color _colorFor(String id) => switch (id) {
  'kcal' || 'tdee' || 'active' || 'balance' => AppColors.burn,
  'protein' || 'protein_kg' || 'protein_share' => AppColors.protein,
  'carbs' => AppColors.carbs,
  'fat' => AppColors.fat,
  'fiber' => AppColors.fiber,
  'water' => AppColors.water,
  'steps' || 'km' => AppColors.steps,
  'rhr' => AppColors.danger,
  'sleep' || 'sleep_score' || 'bedtime' || 'wake' || 'regularity' || 'debt' => AppColors.sleep,
  _ => AppColors.primary,
};

String _fmt(double v, int decimals) {
  if (v.abs() >= 1000 && decimals == 0) return NumberFormat.decimalPattern().format(v.round());
  return v.toStringAsFixed(decimals);
}

/// One metric: headline numbers, change and chart. Tap ⓘ for the science.
class _SeriesCard extends StatefulWidget {
  const _SeriesCard({required this.series, required this.dates});
  final MetricSeries series;
  final List<DateTime> dates;

  @override
  State<_SeriesCard> createState() => _SeriesCardState();
}

class _SeriesCardState extends State<_SeriesCard> {
  bool _about = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.series;
    final color = _colorFor(s.id);
    final change = s.change;
    final good = change == null || s.higherIsBetter == null || change == 0
        ? null
        : (change > 0) == s.higherIsBetter!;
    final changeColor = good == null
        ? AppColors.textSecondary
        : (good ? AppColors.success : AppColors.danger);
    final displayLatest = s.secondary?.whereType<double>().lastOrNull ?? s.latest;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: DepthCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6)],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(s.title, style: AppText.subtitle)),
                InkResponse(
                  radius: 18,
                  onTap: () => setState(() => _about = !_about),
                  child: Icon(
                    _about ? Icons.info_rounded : Icons.info_outline_rounded,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              child: _about
                  ? Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(s.about, style: AppText.caption),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (displayLatest != null)
                  Text(
                    _fmt(displayLatest, s.decimals),
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(s.unit, style: AppText.caption),
                ),
                const Spacer(),
                if (change != null)
                  Pill(
                    '${change >= 0 ? '+' : ''}${_fmt(change, s.decimals)}',
                    color: changeColor,
                    icon: change >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 12,
              children: [
                if (s.average != null) _stat('avg', _fmt(s.average!, s.decimals)),
                if (s.minValue != null) _stat('min', _fmt(s.minValue!, s.decimals)),
                if (s.maxValue != null) _stat('max', _fmt(s.maxValue!, s.decimals)),
                _stat('days', '${s.count}'),
              ],
            ),
            const SizedBox(height: 8),
            SeriesChart(
              dates: widget.dates,
              values: s.values,
              secondary: s.secondary,
              bars: s.bars,
              target: s.target,
              decimals: s.decimals,
              unit: s.unit,
              color: color,
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String k, String v) => Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: '$k ',
          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
        TextSpan(
          text: v,
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
        ),
      ],
    ),
  );
}

/// Which per-exercise curve to draw.
enum _LiftMetric { e1rm, top, volume, reps, relative }

extension on _LiftMetric {
  String get label => switch (this) {
    _LiftMetric.e1rm => 'Est. 1RM',
    _LiftMetric.top => 'Top weight',
    _LiftMetric.volume => 'Volume',
    _LiftMetric.reps => 'Best reps',
    _LiftMetric.relative => '× body weight',
  };
  String get unit => switch (this) {
    _LiftMetric.e1rm || _LiftMetric.top || _LiftMetric.volume => 'kg',
    _LiftMetric.reps => 'reps',
    _LiftMetric.relative => '× BW',
  };
}

/// Strength curve of any exercise you have logged.
class _ExerciseCard extends StatefulWidget {
  const _ExerciseCard(this.exercises);
  final List<ExerciseProgress> exercises;

  @override
  State<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<_ExerciseCard> {
  String? _id;
  _LiftMetric _metric = _LiftMetric.e1rm;

  @override
  Widget build(BuildContext context) {
    final list = widget.exercises;
    if (list.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 16),
        child: EmptyState(
          icon: Icons.fitness_center_rounded,
          title: 'No lifts in this range',
          message: 'Log workouts and every exercise gets its own strength curve.',
        ),
      );
    }
    final e = list.firstWhere((x) => x.id == _id, orElse: () => list.first);
    final values = switch (_metric) {
      _LiftMetric.e1rm => e.e1rm.map<double?>((v) => v > 0 ? v : null).toList(),
      _LiftMetric.top => e.topWeight.map<double?>((v) => v).toList(),
      _LiftMetric.volume => e.volume.map<double?>((v) => v).toList(),
      _LiftMetric.reps => e.bestReps.map<double?>((v) => v).toList(),
      _LiftMetric.relative => e.relativeStrength,
    };
    final present = values.whereType<double>().toList();
    final best = present.isEmpty ? null : present.reduce((a, b) => a > b ? a : b);
    final first = present.isEmpty ? null : present.first;
    final decimals = _metric == _LiftMetric.relative ? 2 : (_metric == _LiftMetric.reps ? 0 : 1);
    final gainPct = (first != null && first > 0 && present.length > 1)
        ? (present.last / first - 1) * 100
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: DepthCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up_rounded, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(child: Text('Strength by exercise', style: AppText.subtitle)),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: e.id,
              isExpanded: true,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: [
                for (final x in list)
                  DropdownMenuItem(
                    value: x.id,
                    child: Text('${x.name}  ·  ${x.sessions} sessions', overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => _id = v),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in _LiftMetric.values)
                  GestureDetector(
                    onTap: () => setState(() => _metric = m),
                    child: Pill(m.label, filled: m == _metric),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (best != null)
                  Text(
                    _fmt(best, decimals),
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('${_metric.unit} best', style: AppText.caption),
                ),
                const Spacer(),
                if (gainPct != null)
                  Pill(
                    '${gainPct >= 0 ? '+' : ''}${gainPct.toStringAsFixed(1)} %',
                    color: gainPct >= 0 ? AppColors.success : AppColors.danger,
                    icon: gainPct >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SeriesChart(
              dates: e.dates,
              values: values,
              bars: _metric == _LiftMetric.volume,
              decimals: decimals,
              unit: _metric.unit,
            ),
            const SizedBox(height: 4),
            Text(
              'One point per session. Est. 1RM uses Epley (sets of ≤ 12 reps).',
              style: AppText.caption.copyWith(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

/// Weekly hard sets per muscle. 10–20 sets/week is the evidence-based
/// hypertrophy range (Schoenfeld 2017).
class _MuscleHeatmap extends StatelessWidget {
  const _MuscleHeatmap(this.r);
  final ProgressReport r;

  static Color _cell(int sets) {
    if (sets == 0) return AppColors.surfaceAlt;
    if (sets < 10) return Color.lerp(AppColors.primarySoft, AppColors.primary, sets / 10)!;
    if (sets <= 20) return AppColors.success;
    return AppColors.warning;
  }

  @override
  Widget build(BuildContext context) {
    final muscles = r.weeklySets.entries.where((e) => e.value.any((v) => v > 0)).toList();
    if (muscles.isEmpty) return const SizedBox.shrink();
    final weeks = r.weekStarts.length;
    const cell = 22.0, gap = 4.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: DepthCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.grid_view_rounded, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(child: Text('Sets per muscle per week', style: AppText.subtitle)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final m in muscles)
                      SizedBox(
                        height: cell + gap,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(m.key.label, style: AppText.caption),
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final m in muscles)
                          Padding(
                            padding: const EdgeInsets.only(bottom: gap),
                            child: Row(
                              children: [
                                for (var w = 0; w < weeks; w++)
                                  Tooltip(
                                    message:
                                        '${m.key.label}, week of ${DateFormat('d MMM').format(r.weekStarts[w])}: ${m.value[w]} sets',
                                    child: Container(
                                      width: cell,
                                      height: cell,
                                      margin: const EdgeInsets.only(right: gap),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: _cell(m.value[w]),
                                        borderRadius: BorderRadius.circular(6),
                                        boxShadow: m.value[w] == 0
                                            ? null
                                            : [
                                                BoxShadow(
                                                  color: _cell(m.value[w]).withValues(alpha: 0.4),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                      ),
                                      child: m.value[w] == 0
                                          ? null
                                          : Text(
                                              '${m.value[w]}',
                                              style: const TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        SizedBox(
                          height: 16,
                          child: Row(
                            children: [
                              for (var w = 0; w < weeks; w++)
                                SizedBox(
                                  width: cell + gap,
                                  child: w % 4 == 0
                                      ? Text(
                                          DateFormat('d/M').format(r.weekStarts[w]),
                                          style: TextStyle(fontSize: 9, color: AppColors.textMuted),
                                          overflow: TextOverflow.visible,
                                          softWrap: false,
                                        )
                                      : null,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _legend(Color.lerp(AppColors.primarySoft, AppColors.primary, 0.5)!, '< 10'),
                _legend(AppColors.success, '10–20 optimal'),
                _legend(AppColors.warning, '> 20 high'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legend(Color c, String t) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
      ),
      const SizedBox(width: 4),
      Text(t, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
    ],
  );
}
