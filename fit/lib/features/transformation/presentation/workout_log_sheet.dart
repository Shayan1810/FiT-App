import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../workout/domain/entities/workout_session.dart';
import '../domain/calculators/strength_calculator.dart';
import '../domain/entities/transformation_plan.dart';
import 'transformation_cubit.dart';

/// Opens the set-by-set logger for a planned workout.
Future<void> showWorkoutLogSheet(BuildContext context, PlanItem item) {
  final cubit = context.read<TransformationCubit>();
  return showAppSheet(context, BlocProvider.value(value: cubit, child: _WorkoutLogSheet(item)));
}

String _kg(double v) => v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

class _SetRow {
  _SetRow(int reps, double kg)
    : reps = TextEditingController(text: '$reps'),
      kg = TextEditingController(text: _kg(kg));
  final TextEditingController reps;
  final TextEditingController kg;
}

/// Logs what was actually lifted: every set of every planned exercise,
/// pre-filled with Nebula's overload target (last time + progression).
class _WorkoutLogSheet extends StatefulWidget {
  const _WorkoutLogSheet(this.item);
  final PlanItem item;

  @override
  State<_WorkoutLogSheet> createState() => _WorkoutLogSheetState();
}

class _WorkoutLogSheetState extends State<_WorkoutLogSheet> {
  late final List<OverloadSuggestion> _suggestions = context.read<TransformationCubit>().suggestionsFor(
    widget.item,
  );
  late final Map<String, List<_SetRow>> _rows = {
    for (final s in _suggestions)
      s.exercise.exerciseId: [for (var k = 0; k < s.sets; k++) _SetRow(s.reps, s.kg)],
  };
  late final _minutes = TextEditingController(text: '${widget.item.durationMin ?? 60}');
  late int _rpe = widget.item.rpe ?? 7;

  @override
  void dispose() {
    for (final rows in _rows.values) {
      for (final r in rows) {
        r.reps.dispose();
        r.kg.dispose();
      }
    }
    _minutes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final sets = <WorkoutSet>[];
    for (final s in _suggestions) {
      for (final r in _rows[s.exercise.exerciseId]!) {
        final reps = int.tryParse(r.reps.text.trim()) ?? 0;
        final kg = double.tryParse(r.kg.text.replaceAll(',', '.').trim()) ?? 0;
        if (reps <= 0) continue;
        sets.add(
          WorkoutSet(
            exerciseId: s.exercise.exerciseId,
            exerciseName: s.exercise.name,
            muscle: s.exercise.muscle,
            reps: reps,
            weightKg: kg,
          ),
        );
      }
    }
    if (sets.isEmpty) {
      showToast(context, 'Enter the reps of at least one set.');
      return;
    }
    HapticFeedback.mediumImpact();
    await context.read<TransformationCubit>().logWorkout(
      widget.item,
      sets,
      durationMin: int.tryParse(_minutes.text.trim()),
      rpe: _rpe,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Text('Log ${widget.item.title}', style: AppText.title),
          const SizedBox(height: 4),
          Text(
            'Pre-filled with your target for today. Change any set to what you actually did.',
            style: AppText.caption,
          ),
          for (final s in _suggestions) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: Text(s.exercise.name, style: AppText.subtitle)),
                if (s.isIncrease)
                  Pill(
                    '+${_kg(s.kg - s.last!.topKg)} kg',
                    color: AppColors.success,
                    icon: Icons.trending_up_rounded,
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              s.last == null
                  ? s.reason
                  : 'Last time: ${s.last!.sets.map((x) => '${x.$1}×${_kg(x.$2)}').join(', ')}. ${s.reason}',
              style: AppText.caption,
            ),
            const SizedBox(height: 6),
            for (var k = 0; k < _rows[s.exercise.exerciseId]!.length; k++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(width: 44, child: Text('Set ${k + 1}', style: AppText.caption)),
                    Expanded(
                      child: TextField(
                        controller: _rows[s.exercise.exerciseId]![k].reps,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(labelText: 'Reps', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _rows[s.exercise.exerciseId]![k].kg,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(labelText: 'kg', isDense: true),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove set',
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                      onPressed: () => setState(() => _rows[s.exercise.exerciseId]!.removeAt(k)),
                    ),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add set'),
                onPressed: () => setState(() {
                  final rows = _rows[s.exercise.exerciseId]!;
                  final last = rows.isEmpty ? null : rows.last;
                  rows.add(
                    _SetRow(
                      int.tryParse(last?.reps.text ?? '') ?? s.reps,
                      double.tryParse(last?.kg.text.replaceAll(',', '.') ?? '') ?? s.kg,
                    ),
                  );
                }),
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _minutes,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Duration', suffixText: 'min'),
          ),
          const SizedBox(height: 12),
          Text('Session effort: RPE $_rpe / 10', style: AppText.subtitle),
          Slider(
            value: _rpe.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            label: '$_rpe',
            onChanged: (v) => setState(() => _rpe = v.round()),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Save workout'),
          ),
        ],
      ),
    );
  }
}
