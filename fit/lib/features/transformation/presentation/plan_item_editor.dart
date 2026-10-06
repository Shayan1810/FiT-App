import 'package:flutter/material.dart';

import '../../../core/di/injector.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/widgets/common.dart';
import '../../nutrition/domain/entities/food_log_entry.dart';
import '../../nutrition/domain/entities/nutrition_facts.dart';
import '../../nutrition/domain/repositories/nutrition_repository.dart';
import '../../workout/domain/entities/exercise.dart';
import '../../workout/domain/entities/workout_session.dart';
import '../../workout/domain/repositories/workout_repository.dart';
import '../domain/entities/transformation_plan.dart';

/// Opens the editor for a plan item of [kind]. Returns the edited item, or
/// null when cancelled.
Future<PlanItem?> showPlanItemEditor(BuildContext context, PlanItemKind kind, {PlanItem? initial}) =>
    showAppSheet<PlanItem>(context, _PlanItemEditor(kind: kind, initial: initial));

/// Weekday picker: M T W T F S S chips (empty selection = every day).
class WeekdayPicker extends StatelessWidget {
  const WeekdayPicker({super.key, required this.value, required this.onChanged});
  final Set<int> value;
  final ValueChanged<Set<int>> onChanged;

  static const _letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final all = value.isEmpty || value.length == 7;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var d = 1; d <= 7; d++)
              _DayDot(
                letter: _letters[d - 1],
                on: all || value.contains(d),
                onTap: () {
                  final next = all ? {1, 2, 3, 4, 5, 6, 7} : {...value};
                  next.contains(d) ? next.remove(d) : next.add(d);
                  onChanged(next.length == 7 ? <int>{} : next);
                },
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(all ? 'Every day' : 'Only on the highlighted days', style: AppText.caption),
      ],
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({required this.letter, required this.on, required this.onTap});
  final String letter;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: on ? AppColors.primaryGradient : null,
        color: on ? null : AppColors.surfaceAlt,
      ),
      child: Text(
        letter,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: on ? AppColors.onPrimary : AppColors.textSecondary,
        ),
      ),
    ),
  );
}

/// "Time: 07:30" row with a clear button.
class TimeField extends StatelessWidget {
  const TimeField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.optional = true,
  });
  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final v = value ?? 8 * 60;
        final t = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: v ~/ 60, minute: v % 60),
        );
        if (t != null) onChanged(t.hour * 60 + t.minute);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: optional && value != null
              ? IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => onChanged(null))
              : const Icon(Icons.schedule_rounded),
        ),
        child: Text(value == null ? 'Any time' : TransformationPlan.clockOf(value!)),
      ),
    );
  }
}

double? _num(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.').trim());
String _fmt(double? v) => v == null ? '' : (v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1));

class _PlanItemEditor extends StatefulWidget {
  const _PlanItemEditor({required this.kind, this.initial});
  final PlanItemKind kind;
  final PlanItem? initial;

  @override
  State<_PlanItemEditor> createState() => _PlanItemEditorState();
}

class _PlanItemEditorState extends State<_PlanItemEditor> {
  late final PlanItem? _i = widget.initial;
  late final _title = TextEditingController(text: _i?.title ?? '');
  late final _detail = TextEditingController(text: _i?.detail ?? '');
  late final _kcal = TextEditingController(text: _fmt(_i?.facts?.kcal));
  late final _p = TextEditingController(text: _fmt(_i?.facts?.protein));
  late final _c = TextEditingController(text: _fmt(_i?.facts?.carbs));
  late final _f = TextEditingController(text: _fmt(_i?.facts?.fat));
  late final _dur = TextEditingController(text: _i?.durationMin?.toString() ?? '');
  late final _km = TextEditingController(text: _fmt(_i?.distanceKm));
  late Set<int> _days = _i?.weekdays ?? {};
  late int? _time = _i?.time;
  late MealSlot _slot = _i?.slot ?? MealSlot.breakfast;
  late WorkoutType _type =
      _i?.workoutType ?? (widget.kind == PlanItemKind.cardio ? WorkoutType.walk : WorkoutType.strength);
  late int _rpe = _i?.rpe ?? (widget.kind == PlanItemKind.cardio ? 3 : 7);
  late List<PlannedExercise> _exercises = [...?_i?.exercises];
  bool _analysing = false;

  PlanItemKind get kind => widget.kind;

  @override
  void dispose() {
    for (final c in [_title, _detail, _kcal, _p, _c, _f, _dur, _km]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _detailLabel => switch (kind) {
    PlanItemKind.meal => 'Foods (e.g. 85 g muesli, 500 ml skimmed milk)',
    PlanItemKind.supplement => 'Dose (e.g. 2 capsules, 25 mg)',
    PlanItemKind.skincare => 'Steps (e.g. cleanser, serum, moisturiser)',
    _ => 'Notes (optional)',
  };

  Future<void> _calculate() async {
    if (_detail.text.trim().isEmpty) {
      showToast(context, 'Type the foods first, e.g. "200 g rice, 4 boiled eggs".');
      return;
    }
    setState(() => _analysing = true);
    final a = await sl<NutritionAnalysisRepository>().analyze(_detail.text);
    if (!mounted) return;
    setState(() => _analysing = false);
    if (a.items.isEmpty) {
      showToast(
        context,
        'Couldn\'t recognise these foods. Enter the macros by hand, or add the foods to My foods.',
      );
      return;
    }
    final t = a.total;
    setState(() {
      _kcal.text = t.kcal.round().toString();
      _p.text = t.protein.toStringAsFixed(0);
      _c.text = t.carbs.toStringAsFixed(0);
      _f.text = t.fat.toStringAsFixed(1);
    });
    if (a.unmatched.isNotEmpty) {
      showToast(context, 'Not recognised: ${a.unmatched.join(', ')}. Add them by hand.');
    }
  }

  Future<void> _addExercise() async {
    final ex = await showAppSheet<Exercise>(context, const _ExercisePicker());
    if (ex == null) return;
    setState(
      () =>
          _exercises = [..._exercises, PlannedExercise(exerciseId: ex.id, name: ex.name, muscle: ex.muscle)],
    );
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      showToast(context, 'Give it a name.');
      return;
    }
    NutritionFacts? facts;
    if (kind == PlanItemKind.meal) {
      final kcal = _num(_kcal);
      if (kcal == null) {
        showToast(context, 'Enter the calories (or tap Calculate).');
        return;
      }
      facts = NutritionFacts(kcal: kcal, protein: _num(_p) ?? 0, carbs: _num(_c) ?? 0, fat: _num(_f) ?? 0);
    }
    final isSession = kind == PlanItemKind.workout || kind == PlanItemKind.cardio;
    Navigator.pop(
      context,
      PlanItem(
        id: _i?.id ?? '${kind.name}_${IdGenerator.next()}',
        kind: kind,
        title: title,
        detail: _detail.text.trim(),
        weekdays: _days,
        time: _time,
        slot: kind == PlanItemKind.meal ? _slot : null,
        facts: facts,
        workoutType: isSession ? _type : null,
        durationMin: isSession ? _num(_dur)?.round() : null,
        rpe: isSession ? _rpe : null,
        distanceKm: kind == PlanItemKind.cardio ? _num(_km) : null,
        exercises: kind == PlanItemKind.workout ? _exercises : const [],
        routineSlot: _i?.routineSlot,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSession = kind == PlanItemKind.workout || kind == PlanItemKind.cardio;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Text('${_i == null ? 'Add' : 'Edit'} ${kind.label.toLowerCase()}', style: AppText.title),
          const SizedBox(height: 14),
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: switch (kind) {
                PlanItemKind.meal => 'Meal name (e.g. Breakfast, post-workout)',
                PlanItemKind.workout => 'Workout name (e.g. Push day)',
                PlanItemKind.cardio => 'Session name (e.g. Evening walk)',
                PlanItemKind.supplement => 'Name (e.g. Creatine)',
                _ => 'Name',
              },
            ),
          ),
          const SizedBox(height: 12),
          if (kind == PlanItemKind.meal) ...[
            DropdownButtonFormField<MealSlot>(
              initialValue: _slot,
              decoration: const InputDecoration(labelText: 'Diary slot'),
              items: [for (final m in MealSlot.values) DropdownMenuItem(value: m, child: Text(m.label))],
              onChanged: (v) => setState(() => _slot = v ?? _slot),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _detail,
            minLines: 1,
            maxLines: 4,
            decoration: InputDecoration(labelText: _detailLabel),
          ),
          if (kind == PlanItemKind.meal) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _analysing ? null : _calculate,
                icon: _analysing
                    ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_awesome_rounded),
                label: const Text('Calculate macros from foods'),
              ),
            ),
            Row(
              children: [
                Expanded(child: _numField(_kcal, 'kcal')),
                const SizedBox(width: 8),
                Expanded(child: _numField(_p, 'Protein g')),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _numField(_c, 'Carbs g')),
                const SizedBox(width: 8),
                Expanded(child: _numField(_f, 'Fat g')),
              ],
            ),
          ],
          if (isSession) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<WorkoutType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: [
                for (final t
                    in kind == PlanItemKind.cardio
                        ? const [
                            WorkoutType.walk,
                            WorkoutType.run,
                            WorkoutType.cardio,
                            WorkoutType.sport,
                            WorkoutType.hiit,
                          ]
                        : const [
                            WorkoutType.strength,
                            WorkoutType.hiit,
                            WorkoutType.mobility,
                            WorkoutType.sport,
                          ])
                  DropdownMenuItem(value: t, child: Text(t.label)),
              ],
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _numField(_dur, 'Minutes')),
                if (kind == PlanItemKind.cardio) ...[
                  const SizedBox(width: 8),
                  Expanded(child: _numField(_km, 'Distance km (optional)')),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text('Effort: RPE $_rpe / 10', style: AppText.subtitle),
            Slider(
              value: _rpe.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              label: '$_rpe',
              onChanged: (v) => setState(() => _rpe = v.round()),
            ),
          ],
          if (kind == PlanItemKind.workout) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(child: Text('Exercises', style: AppText.subtitle)),
                TextButton.icon(
                  onPressed: _addExercise,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add'),
                ),
              ],
            ),
            for (var k = 0; k < _exercises.length; k++) _exerciseRow(k),
            if (_exercises.isEmpty)
              Text(
                'Add the exercises with sets × reps × kg. Ticking the workout logs them.',
                style: AppText.caption,
              ),
          ],
          const SizedBox(height: 16),
          Text('Days', style: AppText.subtitle),
          const SizedBox(height: 8),
          WeekdayPicker(value: _days, onChanged: (v) => setState(() => _days = v)),
          const SizedBox(height: 14),
          TimeField(label: 'Time (optional)', value: _time, onChanged: (v) => setState(() => _time = v)),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _numField(TextEditingController c, String label) => TextField(
    controller: c,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label, isDense: true),
  );

  Widget _exerciseRow(int k) {
    final e = _exercises[k];
    Widget n(String label, num v, ValueChanged<String> on) => SizedBox(
      width: 58,
      child: TextFormField(
        initialValue: v % 1 == 0 ? v.toInt().toString() : v.toString(),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        decoration: InputDecoration(labelText: label, isDense: true),
        onChanged: on,
      ),
    );
    return Padding(
      key: ValueKey('${e.exerciseId}_$k'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          n('Sets', e.sets, (v) => _exercises[k] = _exercises[k].copyWith(sets: int.tryParse(v) ?? e.sets)),
          const SizedBox(width: 4),
          n('Reps', e.reps, (v) => _exercises[k] = _exercises[k].copyWith(reps: int.tryParse(v) ?? e.reps)),
          const SizedBox(width: 4),
          n(
            'kg',
            e.weightKg,
            (v) => _exercises[k] = _exercises[k].copyWith(
              weightKg: double.tryParse(v.replaceAll(',', '.')) ?? e.weightKg,
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => setState(() => _exercises = [..._exercises]..removeAt(k)),
          ),
        ],
      ),
    );
  }
}

/// Searchable list of library + custom exercises.
class _ExercisePicker extends StatefulWidget {
  const _ExercisePicker();

  @override
  State<_ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends State<_ExercisePicker> {
  final _q = TextEditingController();
  late final List<Exercise> _all = sl<WorkoutRepository>().exercises();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.text.trim().toLowerCase();
    final list = q.isEmpty ? _all : _all.where((e) => e.name.toLowerCase().contains(q)).toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      builder: (context, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: TextField(
              controller: _q,
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search exercises',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scroll,
              itemCount: list.length,
              itemBuilder: (context, i) => ListTile(
                title: Text(list[i].name),
                subtitle: Text('${list[i].muscle.label} · ${list[i].equipment}'),
                trailing: list[i].custom ? Pill('Custom') : null,
                onTap: () => Navigator.pop(context, list[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
