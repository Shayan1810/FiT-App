import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../core/widgets/common.dart';
import '../../../../core/widgets/depth_card.dart';
import '../../../insights/domain/calculators/energy_calculator.dart';
import '../../../insights/domain/calculators/training_load_calculator.dart';
import '../../../profile/presentation/bloc/profile_bloc.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/entities/workout_session.dart';
import '../bloc/workout_bloc.dart';

/// Borg CR-10 descriptors for the RPE slider.
const Map<int, String> kRpeLabels = {
  1: 'Very easy',
  2: 'Easy',
  3: 'Moderate',
  4: 'Somewhat hard',
  5: 'Hard',
  6: 'Hard+',
  7: 'Very hard',
  8: 'Very hard+',
  9: 'Near max',
  10: 'Maximal',
};

/// One exercise block being edited.
class _Block {
  _Block(this.exercise, [List<(int, double)>? sets]) : sets = sets ?? [(8, 20)];
  final Exercise exercise;
  final List<(int reps, double kg)> sets;
}

/// Log or edit a workout: type, time, duration, RPE and exercise sets.
class WorkoutEditorPage extends StatefulWidget {
  const WorkoutEditorPage({super.key, this.initial});
  final WorkoutSession? initial;

  @override
  State<WorkoutEditorPage> createState() => _WorkoutEditorPageState();
}

class _WorkoutEditorPageState extends State<WorkoutEditorPage> {
  late final WorkoutSession? w = widget.initial;
  late final _title = TextEditingController(text: w?.title ?? '');
  late WorkoutType _type = w?.type ?? WorkoutType.strength;
  late DateTime _start = w?.start ?? DateTime.now().subtract(const Duration(hours: 1));
  late double _minutes = (w?.durationMin ?? 45).toDouble().clamp(5, 240);

  /// Until the user moves the slider, duration is estimated from the sets.
  late bool _durationTouched = w != null;

  /// ~3 min per set (work + rest) plus 5 min warm-up, 10–240 min.
  int get _estimatedMinutes {
    final sets = _blocks.fold<int>(0, (a, b) => a + b.sets.length);
    if (sets == 0) return _minutes.round();
    return (sets * 3 + 5).clamp(10, 240);
  }

  int get _effectiveMinutes => _durationTouched ? _minutes.round() : _estimatedMinutes;
  late double _rpe = (w?.rpe ?? 7).toDouble();
  late final List<_Block> _blocks = _fromSets(w?.sets ?? const []);

  static List<_Block> _fromSets(List<WorkoutSet> sets) {
    final out = <_Block>[];
    for (final s in sets) {
      if (out.isEmpty || out.last.exercise.id != s.exerciseId) {
        out.add(_Block(Exercise(id: s.exerciseId, name: s.exerciseName, muscle: s.muscle), []));
      }
      out.last.sets.add((s.reps, s.weightKg));
    }
    return out;
  }

  WorkoutSession _build() => WorkoutSession(
    id: w?.id ?? IdGenerator.next('wo_'),
    start: _start,
    title: _title.text.trim().isEmpty
        ? (_blocks.isEmpty ? _type.label : _blocks.map((b) => b.exercise.muscle.label).toSet().join(' & '))
        : _title.text.trim(),
    type: _type,
    durationMin: _effectiveMinutes,
    rpe: _rpe.round(),
    sets: [
      for (final b in _blocks)
        for (final s in b.sets)
          WorkoutSet(
            exerciseId: b.exercise.id,
            exerciseName: b.exercise.name,
            muscle: b.exercise.muscle,
            reps: s.$1,
            weightKg: s.$2,
          ),
    ],
  );

  Future<void> _addExercise() async {
    final all = context.read<WorkoutBloc>().state.exercises;
    final ex = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(heightFactor: 0.9, child: _ExercisePicker(all: all)),
    );
    if (ex != null) setState(() => _blocks.add(_Block(ex)));
  }

  Future<void> _pickTime() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_start));
    if (t == null) return;
    setState(() => _start = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  @override
  Widget build(BuildContext context) {
    final kg = context.select((ProfileBloc b) => b.state.profile?.weightKg) ?? 70;
    final preview = _build();
    return Scaffold(
      appBar: AppBar(title: Text(w == null ? 'Log workout' : 'Edit workout')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Title (optional)', hintText: 'e.g. Push day'),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in WorkoutType.values)
                ChoiceChip(
                  label: Text(t.label),
                  selected: _type == t,
                  onSelected: (_) => setState(() => _type = t),
                ),
            ],
          ),
          const SizedBox(height: 14),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.event_rounded, color: AppColors.primary),
            title: Text(DateFormat('EEE d MMM, HH:mm').format(_start)),
            trailing: const Icon(Icons.edit_calendar_rounded),
            onTap: _pickTime,
          ),
          Text(
            'Duration: $_effectiveMinutes min${_durationTouched ? '' : ' (estimated from sets — drag to set)'}',
            style: AppText.subtitle,
          ),
          Slider(
            value: _effectiveMinutes.toDouble().clamp(5, 240),
            min: 5,
            max: 240,
            divisions: 47,
            onChanged: (v) => setState(() {
              _minutes = v;
              _durationTouched = true;
            }),
          ),
          Text(
            'Effort (session RPE): ${_rpe.round()} — ${kRpeLabels[_rpe.round()]}',
            style: AppText.subtitle,
          ),
          Slider(value: _rpe, min: 1, max: 10, divisions: 9, onChanged: (v) => setState(() => _rpe = v)),
          Text(
            'How hard was the whole session? Rate ~30 min after finishing (Foster 2001).',
            style: AppText.caption,
          ),
          const SizedBox(height: 16),
          for (final (bi, b) in _blocks.indexed) _blockCard(bi, b),
          OutlinedButton.icon(
            onPressed: _addExercise,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add exercise'),
          ),
          const SizedBox(height: 16),
          DepthCard(
            style: DepthStyle.primary,
            child: DefaultTextStyle(
              style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _sum(fmtInt(EnergyCalculator.workoutKcal(preview, weightKg: kg)), 'kcal (net)'),
                  _sum(fmtInt(preview.load), 'load AU'),
                  _sum(fmtInt(preview.volume), 'kg volume'),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton.icon(
            icon: const Icon(Icons.check_rounded),
            label: const Text('Save workout'),
            onPressed: () {
              context.read<WorkoutBloc>().add(WorkoutSaved(_build()));
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }

  Widget _sum(String v, String k) => Column(
    children: [
      Text(v, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      Text(k, style: const TextStyle(color: Colors.white70, fontSize: 12)),
    ],
  );

  Widget _blockCard(int bi, _Block b) {
    final best = b.sets.isEmpty
        ? 0.0
        : b.sets.map((s) => TrainingLoadCalculator.epley1Rm(s.$2, s.$1)).reduce((a, c) => a > c ? a : c);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DepthCard(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(b.exercise.name, style: AppText.subtitle)),
                Pill(b.exercise.muscle.label),
                IconButton(
                  onPressed: () => setState(() => _blocks.removeAt(bi)),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            if (best > 0)
              Text('Best set ≈ ${best.toStringAsFixed(1)} kg estimated 1RM (Epley)', style: AppText.caption),
            for (final (si, s) in b.sets.indexed)
              Row(
                children: [
                  SizedBox(width: 44, child: Text('Set ${si + 1}', style: AppText.caption)),
                  _stepper(
                    '${s.$1} reps',
                    () => setState(() => b.sets[si] = (s.$1 > 1 ? s.$1 - 1 : 1, s.$2)),
                    () => setState(() => b.sets[si] = (s.$1 + 1, s.$2)),
                  ),
                  const SizedBox(width: 6),
                  _stepper(
                    '${s.$2 % 1 == 0 ? s.$2.toInt() : s.$2} kg',
                    () => setState(() => b.sets[si] = (s.$1, (s.$2 - 2.5).clamp(0, 500))),
                    () => setState(() => b.sets[si] = (s.$1, s.$2 + 2.5)),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => b.sets.removeAt(si)),
                    icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
                  ),
                ],
              ),
            TextButton.icon(
              onPressed: () => setState(() => b.sets.add(b.sets.isEmpty ? (8, 20) : b.sets.last)),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add set'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepper(String label, VoidCallback minus, VoidCallback plus) => Container(
    decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: minus,
          child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.remove_rounded, size: 16)),
        ),
        SizedBox(
          width: 62,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
          ),
        ),
        InkWell(
          onTap: plus,
          child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.add_rounded, size: 16)),
        ),
      ],
    ),
  );
}

class _ExercisePicker extends StatefulWidget {
  const _ExercisePicker({required this.all});
  final List<Exercise> all;

  @override
  State<_ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends State<_ExercisePicker> {
  String _q = '';
  MuscleGroup? _muscle;
  late final List<Exercise> _all = [...widget.all];

  Future<void> _create() async {
    final ex = await showDialog<Exercise>(
      context: context,
      builder: (_) => _CustomExerciseDialog(initialName: _q),
    );
    if (ex == null || !mounted) return;
    context.read<WorkoutBloc>().add(ExerciseSaved(ex));
    Navigator.pop(context, ex);
  }

  Future<void> _delete(Exercise e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${e.name}"?'),
        content: const Text('Workouts you already logged keep this exercise.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    context.read<WorkoutBloc>().add(ExerciseDeleted(e.id));
    setState(() => _all.removeWhere((x) => x.id == e.id));
  }

  @override
  Widget build(BuildContext context) {
    final list = _all
        .where((e) => _muscle == null || e.muscle == _muscle)
        .where((e) => _q.isEmpty || e.name.toLowerCase().contains(_q.toLowerCase()))
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Search exercises',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: (v) => setState(() => _q = v),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final m in [null, ...MuscleGroup.values])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(m?.label ?? 'All'),
                    selected: _muscle == m,
                    onSelected: (_) => setState(() => _muscle = m),
                  ),
                ),
            ],
          ),
        ),
        ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.primarySoft,
            child: Icon(Icons.add_rounded, color: AppColors.primary),
          ),
          title: Text(
            _q.trim().isEmpty ? 'Create custom exercise' : 'Create "${_q.trim()}"',
            style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary),
          ),
          onTap: _create,
        ),
        Expanded(
          child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, i) {
              final e = list[i];
              return ListTile(
                title: Text(e.name),
                subtitle: Text(
                  '${e.muscle.label} · ${e.equipment}${e.compound ? ' · compound' : ''}${e.custom ? ' · custom (hold to delete)' : ''}',
                  style: AppText.caption,
                ),
                trailing: e.custom ? Icon(Icons.star_rounded, color: AppColors.primary, size: 18) : null,
                onTap: () => Navigator.pop(context, e),
                onLongPress: e.custom ? () => _delete(e) : null,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Form for a user-defined exercise.
class _CustomExerciseDialog extends StatefulWidget {
  const _CustomExerciseDialog({this.initialName = ''});
  final String initialName;

  @override
  State<_CustomExerciseDialog> createState() => _CustomExerciseDialogState();
}

class _CustomExerciseDialogState extends State<_CustomExerciseDialog> {
  late final _name = TextEditingController(text: widget.initialName.trim());
  MuscleGroup _muscle = MuscleGroup.chest;
  String _equipment = 'Barbell';
  bool _compound = false;

  static const _equipmentOptions = [
    'Barbell',
    'Dumbbell',
    'Machine',
    'Cable',
    'Bodyweight',
    'Kettlebell',
    'Band',
    'Other',
  ];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Custom exercise'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<MuscleGroup>(
              initialValue: _muscle,
              decoration: const InputDecoration(labelText: 'Main muscle group'),
              items: [for (final m in MuscleGroup.values) DropdownMenuItem(value: m, child: Text(m.label))],
              onChanged: (v) => setState(() => _muscle = v ?? _muscle),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _equipment,
              decoration: const InputDecoration(labelText: 'Equipment'),
              items: [for (final e in _equipmentOptions) DropdownMenuItem(value: e, child: Text(e))],
              onChanged: (v) => setState(() => _equipment = v ?? _equipment),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Compound (multi-joint)'),
              value: _compound,
              onChanged: (v) => setState(() => _compound = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _name.text.trim().isEmpty
              ? null
              : () => Navigator.pop(
                  context,
                  Exercise(
                    id: IdGenerator.next('cx_'),
                    name: _name.text.trim(),
                    muscle: _muscle,
                    equipment: _equipment,
                    compound: _compound,
                    custom: true,
                  ),
                ),
          child: const Text('Create'),
        ),
      ],
    );
  }
}
