import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/depth_card.dart';
import '../../insights/presentation/bloc/insights_bloc.dart';
import '../../nutrition/domain/entities/nutrition_facts.dart';
import '../../profile/presentation/bloc/profile_bloc.dart';
import '../domain/calculators/transformation_calculator.dart';
import '../domain/entities/transformation_plan.dart';
import 'plan_item_editor.dart';
import 'transformation_cubit.dart';

/// Step-by-step setup (and later editing) of a transformation:
/// goals → body → targets → diet → training → cardio → supplements &
/// habits → skin → review. Everything recurring is entered once here.
class PlanEditorPage extends StatefulWidget {
  const PlanEditorPage({super.key, this.initial});
  final TransformationPlan? initial;

  @override
  State<PlanEditorPage> createState() => _PlanEditorPageState();
}

enum _Step { goals, body, targets, diet, training, cardio, extras, skin, review }

extension on _Step {
  String get title => switch (this) {
    _Step.goals => 'Your transformation',
    _Step.body => 'Body goal',
    _Step.targets => 'Daily targets',
    _Step.diet => 'Diet plan',
    _Step.training => 'Training plan',
    _Step.cardio => 'Cardio sessions',
    _Step.extras => 'Supplements & habits',
    _Step.skin => 'Skincare routine',
    _Step.review => 'Review',
  };
}

class _PlanEditorPageState extends State<PlanEditorPage> {
  late TransformationPlan _plan = widget.initial ?? _blank();
  int _index = 0;

  static TransformationPlan _blank() {
    final start = DateKeys.startOfDay(DateTime.now()).add(const Duration(days: 1));
    return TransformationPlan(
      id: 'plan_${IdGenerator.next()}',
      name: 'Phase 1',
      start: start,
      end: start.add(const Duration(days: 69)),
      areas: const {GoalArea.body},
      bodyGoal: BodyGoal.fatLoss,
      macros: const MacroGoals(kcal: 2000, protein: 140, carbs: 200, fat: 60),
    );
  }

  List<_Step> get _steps => [
    _Step.goals,
    if (_plan.hasBody) ...[_Step.body, _Step.targets, _Step.diet, _Step.training, _Step.cardio],
    _Step.extras,
    if (_plan.hasSkin) _Step.skin,
    _Step.review,
  ];

  void _set(TransformationPlan p) => setState(() => _plan = p);

  String? _stepError(_Step s) {
    final p = _plan;
    switch (s) {
      case _Step.goals:
        if (p.name.trim().isEmpty) return 'Give it a name.';
        if (p.areas.isEmpty) return 'Choose Body, Skin or both.';
        if (!p.end.isAfter(p.start)) return 'The end date must be after the start date.';
      case _Step.body:
        final e = p.validate().where((x) => x.contains('weight') || x.contains('body') || x.contains('goal'));
        if (e.isNotEmpty) return e.first;
      case _Step.targets:
        if (p.macros.kcal < 800) return 'Set a daily calorie goal (at least 800 kcal).';
      default:
        break;
    }
    return null;
  }

  void _next() {
    final steps = _steps;
    final err = _stepError(steps[_index]);
    if (err != null) {
      showToast(context, err);
      return;
    }
    if (_index < steps.length - 1) setState(() => _index++);
  }

  Future<void> _save() async {
    final errors = _plan.validate();
    if (errors.isNotEmpty) {
      showToast(context, errors.first);
      return;
    }
    await context.read<TransformationCubit>().savePlan(_plan);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps;
    if (_index >= steps.length) _index = steps.length - 1;
    final step = steps[_index];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null ? 'New transformation' : 'Edit plan'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: LinearProgressIndicator(value: (_index + 1) / steps.length),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: ListView(
          key: ValueKey(step),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          children: [
            Text(step.title, style: AppText.display),
            const SizedBox(height: 4),
            Text('Step ${_index + 1} of ${steps.length}', style: AppText.caption),
            const SizedBox(height: 18),
            ...switch (step) {
              _Step.goals => _goals(),
              _Step.body => _body(),
              _Step.targets => _targets(),
              _Step.diet => _list(
                PlanItemKind.meal,
                'Add each meal once with its foods and macros. Ticking a meal logs it to your food diary.',
                footer: _dietTotals(),
              ),
              _Step.training => _list(
                PlanItemKind.workout,
                'Add each workout with its days. Days without a workout are your rest days.',
                footer: _restDays(),
              ),
              _Step.cardio => _list(
                PlanItemKind.cardio,
                'Walks, runs, sports… with their days and minutes. Ticking logs the session.',
              ),
              _Step.extras => _list(
                null,
                'Supplements, medicine and other daily habits (e.g. haircare on Mon · Wed · Fri). '
                'Each becomes a tick on its days.',
              ),
              _Step.skin => _skin(),
              _Step.review => _review(),
            },
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Row(
            children: [
              if (_index > 0)
                Expanded(
                  child: OutlinedButton(onPressed: () => setState(() => _index--), child: const Text('Back')),
                ),
              if (_index > 0) const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: step == _Step.review ? _save : _next,
                  icon: Icon(step == _Step.review ? Icons.flag_rounded : Icons.arrow_forward_rounded),
                  label: Text(
                    step == _Step.review
                        ? (widget.initial == null ? 'Start transformation' : 'Save plan')
                        : 'Next',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Steps ───────────────────────────────────────────────────────────

  List<Widget> _goals() => [
    TextFormField(
      initialValue: _plan.name,
      decoration: const InputDecoration(labelText: 'Name (e.g. Phase 1 — Recomposition)'),
      onChanged: (v) => _plan = _plan.copyWith(name: v),
    ),
    const SizedBox(height: 18),
    Text('What do you want to transform?', style: AppText.subtitle),
    const SizedBox(height: 10),
    Wrap(
      spacing: 10,
      children: [
        for (final a in GoalArea.values)
          FilterChip(
            avatar: Icon(
              a == GoalArea.body ? Icons.fitness_center_rounded : Icons.face_retouching_natural_rounded,
            ),
            label: Text(a == GoalArea.body ? 'Body' : 'Skin'),
            selected: _plan.areas.contains(a),
            onSelected: (on) =>
                _set(_plan.copyWith(areas: on ? {..._plan.areas, a} : ({..._plan.areas}..remove(a)))),
          ),
      ],
    ),
    const SizedBox(height: 18),
    Row(
      children: [
        Expanded(child: _date('Start date', _plan.start, (d) => _set(_plan.copyWith(start: d)))),
        const SizedBox(width: 12),
        Expanded(child: _date('End date', _plan.end, (d) => _set(_plan.copyWith(end: d)))),
      ],
    ),
    const SizedBox(height: 8),
    Text(
      '${_plan.totalDays} days · ${(_plan.totalDays / 7).toStringAsFixed(1)} weeks. '
      'While it runs, FiT opens on your daily plan until you switch back to General mode in Settings.',
      style: AppText.caption,
    ),
  ];

  Widget _date(String label, DateTime value, ValueChanged<DateTime> on) => InkWell(
    borderRadius: BorderRadius.circular(14),
    onTap: () async {
      final d = await showDatePicker(
        context: context,
        initialDate: value,
        firstDate: DateTime.now().subtract(const Duration(days: 365)),
        lastDate: DateTime.now().add(const Duration(days: 3 * 365)),
      );
      if (d != null) on(DateKeys.startOfDay(d));
    },
    child: InputDecorator(
      decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.event_rounded)),
      child: Text(DateFormat('d MMM yyyy').format(value)),
    ),
  );

  Widget _numField(
    String label,
    double? value,
    String suffix,
    ValueChanged<double?> on, {
    String? helper,
  }) => TextFormField(
    key: ValueKey('$label-${_plan.bodyGoal}'),
    initialValue: value == null ? '' : (value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1)),
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label, suffixText: suffix, helperText: helper, helperMaxLines: 2),
    onChanged: (v) => on(double.tryParse(v.replaceAll(',', '.'))),
  );

  List<Widget> _body() {
    final g = _plan.bodyGoal ?? BodyGoal.fatLoss;
    final p = _plan;
    final change = p.startWeightKg != null && p.goalWeightKg != null
        ? p.goalWeightKg! - p.startWeightKg!
        : null;
    final weeks = p.totalDays / 7;
    return [
      SegmentedButton<BodyGoal>(
        segments: [for (final b in BodyGoal.values) ButtonSegment(value: b, label: Text(b.shortLabel))],
        selected: {g},
        onSelectionChanged: (v) => _set(p.copyWith(bodyGoal: v.first)),
      ),
      const SizedBox(height: 8),
      Text(switch (g) {
        BodyGoal.fatLoss => 'Lose fat while keeping muscle. Needs weight, body fat and a goal weight.',
        BodyGoal.weightGain => 'Gain weight (ideally muscle). Needs weight and a goal weight.',
        BodyGoal.recomposition => 'Lose fat and build muscle at the same time. Needs all of the above.',
      }, style: AppText.caption),
      const SizedBox(height: 16),
      _numField(
        'Starting body weight',
        p.startWeightKg,
        'kg',
        (v) => _plan = _plan.copyWith(startWeightKg: v),
      ),
      if (g.needsBodyFat) ...[
        const SizedBox(height: 12),
        _numField(
          'Starting body fat',
          p.startBodyFatPct,
          '%',
          (v) => _plan = _plan.copyWith(startBodyFatPct: v),
          helper: 'From a smart scale, a DEXA scan or the tape estimate in Profile.',
        ),
      ],
      const SizedBox(height: 12),
      _numField('Goal weight', p.goalWeightKg, 'kg', (v) => _plan = _plan.copyWith(goalWeightKg: v)),
      if (g.needsBodyFat) ...[
        const SizedBox(height: 12),
        _numField(
          'Goal body fat (optional)',
          p.goalBodyFatPct,
          '%',
          (v) =>
              _plan = v == null ? _plan.copyWith(clearGoalBodyFat: true) : _plan.copyWith(goalBodyFatPct: v),
        ),
      ],
      const SizedBox(height: 16),
      if (change != null)
        DepthCard(
          padding: const EdgeInsets.all(16),
          child: Text(
            '${change > 0 ? '+' : ''}${change.toStringAsFixed(1)} kg in ${weeks.toStringAsFixed(1)} weeks = '
            '${(change / weeks).toStringAsFixed(2)} kg/week '
            '(${(change.abs() / weeks / p.startWeightKg! * 100).toStringAsFixed(1)} % of body weight). '
            'That needs a daily ${change < 0 ? 'deficit' : 'surplus'} of about ${(change.abs() * (change < 0 ? TransformationStatus.kcalPerKgFat : TransformationStatus.kcalPerKgGain) / p.totalDays).round()} kcal.'
            '${change < 0 && change.abs() / weeks / p.startWeightKg! > 0.01 ? ' Faster than 1 %/week risks muscle loss; keep protein high (Helms 2014).' : ''}',
            style: AppText.body,
          ),
        ),
      const SizedBox(height: 8),
      TextButton(onPressed: () => setState(() {}), child: const Text('Update estimate')),
    ];
  }

  List<Widget> _targets() {
    final m = _plan.macros;
    final tdee = context.read<InsightsBloc>().state.briefing?.today.tdee;
    void setM({double? kcal, double? protein, double? carbs, double? fat, double? fiber, int? waterMl}) {
      _plan = _plan.copyWith(
        macros: MacroGoals(
          kcal: kcal ?? _plan.macros.kcal,
          protein: protein ?? _plan.macros.protein,
          carbs: carbs ?? _plan.macros.carbs,
          fat: fat ?? _plan.macros.fat,
          fiber: fiber ?? _plan.macros.fiber,
          waterMl: waterMl ?? _plan.macros.waterMl,
        ),
      );
    }

    final atwater = m.protein * 4 + m.carbs * 4 + m.fat * 9;
    return [
      Text('Nutrition', style: AppText.subtitle),
      const SizedBox(height: 8),
      if (tdee != null)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('Suggest from my expenditure'),
            onPressed: () => _set(_suggest(tdee)),
          ),
        ),
      Row(
        children: [
          Expanded(child: _numField('Calories', m.kcal, 'kcal', (v) => setM(kcal: v))),
          const SizedBox(width: 10),
          Expanded(child: _numField('Protein', m.protein, 'g', (v) => setM(protein: v))),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(child: _numField('Carbs', m.carbs, 'g', (v) => setM(carbs: v))),
          const SizedBox(width: 10),
          Expanded(child: _numField('Fat', m.fat, 'g', (v) => setM(fat: v))),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(child: _numField('Fibre (optional)', m.fiber, 'g', (v) => setM(fiber: v))),
          const SizedBox(width: 10),
          Expanded(
            child: _numField(
              'Water (optional)',
              m.waterMl == null ? null : m.waterMl! / 1000,
              'L',
              (v) => setM(waterMl: v == null ? null : (v * 1000).round()),
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      Text('Macros add up to ${atwater.round()} kcal (4 / 4 / 9 kcal per g).', style: AppText.caption),
      const SizedBox(height: 10),
      _numField(
        'Weekly calorie change (optional)',
        _plan.weeklyKcalStep == 0 ? null : _plan.weeklyKcalStep,
        'kcal/week',
        (v) => _plan = _plan.copyWith(weeklyKcalStep: v ?? 0),
        helper: 'e.g. +50 to raise calories every week (added to carbs). Leave empty to keep them fixed.',
      ),
      const SizedBox(height: 22),
      Text('Activity', style: AppText.subtitle),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: _numField(
              'Steps goal',
              _plan.stepsGoal?.toDouble(),
              'steps',
              (v) => _plan = _plan.copyWith(stepsGoal: v?.round()),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _numField(
              'Cardio goal',
              _plan.cardioMinutesGoal?.toDouble(),
              'min/day',
              (v) => _plan = _plan.copyWith(cardioMinutesGoal: v?.round()),
            ),
          ),
        ],
      ),
      const SizedBox(height: 22),
      Text('Sleep', style: AppText.subtitle),
      const SizedBox(height: 8),
      _numField('Sleep goal', _plan.sleepHours, 'h', (v) => _plan = _plan.copyWith(sleepHours: v ?? 8)),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: TimeField(
              label: 'Lights out',
              value: _plan.bedtimeMin,
              optional: false,
              onChanged: (v) => _set(_plan.copyWith(bedtimeMin: v ?? _plan.bedtimeMin)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TimeField(
              label: 'Wake up',
              value: _plan.wakeMin,
              optional: false,
              onChanged: (v) => _set(_plan.copyWith(wakeMin: v ?? _plan.wakeMin)),
            ),
          ),
        ],
      ),
    ];
  }

  /// Targets from current expenditure and the body goal.
  TransformationPlan _suggest(double tdee) {
    final p = _plan;
    final w = p.startWeightKg ?? context.read<ProfileBloc>().state.profile?.weightKg ?? 75;
    final change = p.startWeightKg != null && p.goalWeightKg != null
        ? p.goalWeightKg! - p.startWeightKg!
        : 0.0;
    final perDay =
        change *
        (change < 0 ? TransformationStatus.kcalPerKgFat : TransformationStatus.kcalPerKgGain) /
        p.totalDays;
    final maxDeficit = min(tdee * 0.3, w * 0.01 * TransformationStatus.kcalPerKgFat / 7 * 1.3);
    final kcal = (tdee + perDay.clamp(-maxDeficit, 500)).clamp(1200.0, 5000.0);
    final lean = p.startBodyFatPct == null ? w * 0.8 : w * (1 - p.startBodyFatPct! / 100);
    final protein = (p.bodyGoal == BodyGoal.weightGain ? 1.8 * w : 2.4 * lean).clamp(80.0, 260.0);
    final fat = max(0.6 * w, kcal * 0.25 / 9);
    final carbs = max(50.0, (kcal - protein * 4 - fat * 9) / 4);
    return p.copyWith(
      macros: MacroGoals(
        kcal: (kcal / 10).round() * 10,
        protein: protein.roundToDouble(),
        carbs: carbs.roundToDouble(),
        fat: fat.roundToDouble(),
        fiber: (14 * kcal / 1000).roundToDouble(),
        waterMl: ((35 * w) / 250).round() * 250,
      ),
    );
  }

  List<Widget> _list(PlanItemKind? kind, String help, {Widget? footer}) {
    final kinds = kind == null ? const [PlanItemKind.supplement, PlanItemKind.habit] : [kind];
    final items = [
      for (final i in _plan.items)
        if (kinds.contains(i.kind)) i,
    ]..sort((a, b) => a.sortTime.compareTo(b.sortTime));
    return [
      Text(help, style: AppText.caption),
      const SizedBox(height: 12),
      for (final it in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: DepthCard(
            padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
            onTap: () => _edit(it.kind, it),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(it.title, style: AppText.subtitle),
                      Text(
                        [
                          it.daysLabel,
                          if (it.time != null) TransformationPlan.clockOf(it.time!),
                          if (it.facts != null)
                            '${it.facts!.kcal.round()} kcal · P ${it.facts!.protein.round()} g',
                          if (it.exercises.isNotEmpty) '${it.exercises.length} exercises',
                          if (it.durationMin != null) '${it.durationMin} min',
                          if (it.detail.isNotEmpty && it.facts == null) it.detail,
                        ].join(' · '),
                        style: AppText.caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Duplicate',
                  icon: const Icon(Icons.copy_rounded, size: 20),
                  onPressed: () => _set(
                    _plan.copyWith(
                      items: [
                        ..._plan.items,
                        PlanItem(
                          id: '${it.kind.name}_${IdGenerator.next()}',
                          kind: it.kind,
                          title: '${it.title} (copy)',
                          detail: it.detail,
                          weekdays: it.weekdays,
                          time: it.time,
                          slot: it.slot,
                          facts: it.facts,
                          workoutType: it.workoutType,
                          durationMin: it.durationMin,
                          rpe: it.rpe,
                          distanceKm: it.distanceKm,
                          exercises: it.exercises,
                          routineSlot: it.routineSlot,
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  onPressed: () =>
                      _set(_plan.copyWith(items: [..._plan.items]..removeWhere((x) => x.id == it.id))),
                ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 4),
      Wrap(
        spacing: 8,
        children: [
          for (final k in kinds)
            OutlinedButton.icon(
              onPressed: () => _edit(k),
              icon: const Icon(Icons.add_rounded),
              label: Text(
                'Add ${k == PlanItemKind.supplement ? 'supplement / medicine' : k.label.toLowerCase()}',
              ),
            ),
        ],
      ),
      ?footer,
    ];
  }

  Future<void> _edit(PlanItemKind kind, [PlanItem? item]) async {
    final edited = await showPlanItemEditor(context, kind, initial: item);
    if (edited == null) return;
    final items = [..._plan.items];
    final i = items.indexWhere((x) => x.id == edited.id);
    i >= 0 ? items[i] = edited : items.add(edited);
    _set(_plan.copyWith(items: items));
  }

  Widget _dietTotals() {
    final days = [for (var d = 0; d < 7; d++) _plan.start.add(Duration(days: d))];
    final totals = days.map(_plan.plannedIntake).toList();
    final first = totals.isEmpty ? NutritionFacts.zero : totals.first;
    final m = _plan.macros;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: DepthCard(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Planned day 1: ${first.kcal.round()} / ${m.kcal.round()} kcal · '
          'P ${first.protein.round()} / ${m.protein.round()} g · '
          'C ${first.carbs.round()} / ${m.carbs.round()} g · '
          'F ${first.fat.round()} / ${m.fat.round()} g',
          style: AppText.body,
        ),
      ),
    );
  }

  Widget _restDays() {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final rest = [
      for (var d = 1; d <= 7; d++)
        if (!_plan.items.any(
          (i) => i.kind == PlanItemKind.workout && (i.weekdays.isEmpty || i.weekdays.contains(d)),
        ))
          names[d - 1],
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text(
        rest.isEmpty ? 'No rest days planned.' : 'Rest days: ${rest.join(' · ')}',
        style: AppText.subtitle.copyWith(color: AppColors.primary),
      ),
    );
  }

  List<Widget> _skin() {
    PlanItem? find(RoutineSlot s) {
      for (final i in _plan.items) {
        if (i.kind == PlanItemKind.skincare && i.routineSlot == s) return i;
      }
      return null;
    }

    void update(RoutineSlot s, {String? steps, int? time, bool clearTime = false}) {
      final items = [..._plan.items];
      final existing = find(s);
      final next =
          (existing ??
                  PlanItem(
                    id: 'skin_${s.name}',
                    kind: PlanItemKind.skincare,
                    title: '${s.label} skincare',
                    routineSlot: s,
                  ))
              .copyWith(detail: steps, time: time, clearTime: clearTime);
      items.removeWhere((i) => i.id == next.id);
      if (next.detail.trim().isNotEmpty) items.add(next);
      _plan = _plan.copyWith(items: items);
    }

    return [
      Text(
        'Enter each routine once. Every day you just tick Morning, Afternoon and Evening. '
        'Leave a slot empty if you don\'t have one.',
        style: AppText.caption,
      ),
      for (final s in RoutineSlot.values) ...[
        const SizedBox(height: 18),
        Text(s.label, style: AppText.subtitle),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: find(s)?.detail ?? '',
          minLines: 1,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Steps',
            hintText: switch (s) {
              RoutineSlot.morning => 'Cleanser, niacinamide serum, moisturiser, sunscreen',
              RoutineSlot.afternoon => 'Sunscreen (reapply)',
              RoutineSlot.evening => 'Cleanser, salicylic acid serum, moisturiser',
            },
          ),
          onChanged: (v) => update(s, steps: v),
        ),
        const SizedBox(height: 8),
        TimeField(
          label: 'Time (optional)',
          value: find(s)?.time,
          onChanged: (v) => setState(() => update(s, time: v, clearTime: v == null)),
        ),
      ],
    ];
  }

  List<Widget> _review() {
    final p = _plan;
    int count(PlanItemKind k) => p.items.where((i) => i.kind == k).length;
    final errors = p.validate();
    return [
      DepthCard(
        style: DepthStyle.primary,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              p.name,
              style: TextStyle(color: AppColors.onPrimary, fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '${DateFormat('d MMM yyyy').format(p.start)} – ${DateFormat('d MMM yyyy').format(p.end)} · ${p.totalDays} days',
              style: TextStyle(color: AppColors.onPrimary.withValues(alpha: 0.8)),
            ),
            if (p.hasBody && p.startWeightKg != null && p.goalWeightKg != null) ...[
              const SizedBox(height: 10),
              Text(
                '${p.bodyGoal?.label}: ${p.startWeightKg!.toStringAsFixed(1)} to ${p.goalWeightKg!.toStringAsFixed(1)} kg'
                '${p.startBodyFatPct != null ? ' · ${p.startBodyFatPct!.toStringAsFixed(1)} % body fat' : ''}',
                style: TextStyle(color: AppColors.onPrimary, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 14),
      if (p.hasBody)
        _row(
          Icons.local_fire_department_rounded,
          'Targets',
          '${p.macros.kcal.round()} kcal · P ${p.macros.protein.round()} · C ${p.macros.carbs.round()} · F ${p.macros.fat.round()} g'
              '${p.weeklyKcalStep != 0 ? ' · ${p.weeklyKcalStep > 0 ? '+' : ''}${p.weeklyKcalStep.round()} kcal/week' : ''}',
        ),
      _row(
        Icons.bedtime_rounded,
        'Sleep',
        '${p.sleepHours} h · ${TransformationPlan.clockOf(p.bedtimeMin)} – ${TransformationPlan.clockOf(p.wakeMin)}',
      ),
      if (p.hasBody) ...[
        _row(Icons.restaurant_rounded, 'Meals', '${count(PlanItemKind.meal)} planned'),
        _row(Icons.fitness_center_rounded, 'Workouts', '${count(PlanItemKind.workout)} planned'),
        _row(Icons.directions_walk_rounded, 'Cardio', '${count(PlanItemKind.cardio)} sessions'),
      ],
      _row(
        Icons.medication_rounded,
        'Supplements & habits',
        '${count(PlanItemKind.supplement) + count(PlanItemKind.habit)}',
      ),
      if (p.hasSkin)
        _row(Icons.face_retouching_natural_rounded, 'Skincare', '${count(PlanItemKind.skincare)} routines'),
      const SizedBox(height: 12),
      if (errors.isNotEmpty)
        for (final e in errors)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('• $e', style: const TextStyle(color: AppColors.danger)),
          )
      else
        Text(
          'Each day FiT shows this as a checklist. Tick items as you do them — meals, workouts, cardio and '
          'sleep are logged for you. Anything off-plan can still be logged as usual.',
          style: AppText.caption,
        ),
    ];
  }

  Widget _row(IconData icon, String title, String value) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: AppColors.primary),
    title: Text(title),
    subtitle: Text(value),
  );
}
