import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/domain/data_source.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/common.dart';
import 'bloc/activity_cubit.dart';
import '../../../core/platform/health_brand.dart';

/// Opens the steps editor for [day] (defaults to today). Works for days
/// imported from Samsung Health too — the edit is kept as a manual value.
Future<void> showEditStepsSheet(BuildContext context, {DateTime? day}) {
  final cubit = context.read<ActivityCubit>();
  return showAppSheet(
    context,
    BlocProvider.value(
      value: cubit,
      child: _EditStepsSheet(initialDay: day ?? DateTime.now()),
    ),
  );
}

class _EditStepsSheet extends StatefulWidget {
  const _EditStepsSheet({required this.initialDay});
  final DateTime initialDay;

  @override
  State<_EditStepsSheet> createState() => _EditStepsSheetState();
}

class _EditStepsSheetState extends State<_EditStepsSheet> {
  late DateTime _day = DateKeys.startOfDay(widget.initialDay);
  final _steps = TextEditingController();
  final _km = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final r = context.read<ActivityCubit>().dayRecord(_day);
    _steps.text = r == null || r.steps == 0 ? '' : '${r.steps}';
    _km.text = r?.distanceKm == null ? '' : r!.distanceKm!.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _steps.dispose();
    _km.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final record = context.read<ActivityCubit>().dayRecord(_day);
    final fromDevice = record?.source == DataSource.healthConnect;
    final edited = record?.source == DataSource.manual;
    final connected = context.read<ActivityCubit>().state.syncing || record != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Steps & walking', style: AppText.title),
          const SizedBox(height: 4),
          Text(
            fromDevice
                ? 'Imported from ${HealthBrand.app}. Your edit will be kept and not overwritten by sync.'
                : 'Type your steps for this day. Distance is optional (estimated from your height otherwise).',
            style: AppText.caption,
          ),
          const SizedBox(height: 14),
          ActionChip(
            avatar: Icon(Icons.event_rounded, size: 18, color: AppColors.primary),
            label: Text(DateKeys.friendly(_day)),
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _day,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (d != null) {
                setState(() => _day = d);
                _load();
              }
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _steps,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Steps', suffixText: 'steps'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _km,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Distance (optional)', suffixText: 'km'),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () async {
              final steps = int.tryParse(_steps.text.trim());
              if (steps == null || steps < 0 || steps > 150000) {
                showToast(context, 'Enter a step count between 0 and 150 000.');
                return;
              }
              final km = double.tryParse(_km.text.replaceAll(',', '.').trim());
              await context.read<ActivityCubit>().setManualSteps(_day, steps, distanceKm: km);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
          if (edited && connected) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                await context.read<ActivityCubit>().revertToDevice(_day);
                if (context.mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.restore_rounded),
              label: Text('Revert to ${HealthBrand.app} data'),
            ),
          ],
        ],
      ),
    );
  }
}
