import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/common.dart';
import 'bloc/profile_bloc.dart';

/// Opens the "Log weight" sheet (number wheel-like stepper + date).
Future<void> showLogWeightSheet(BuildContext context) {
  final bloc = context.read<ProfileBloc>();
  final current = bloc.state.profile?.weightKg ?? 70;
  return showAppSheet(
    context,
    BlocProvider.value(
      value: bloc,
      child: _LogWeightSheet(initial: current),
    ),
  );
}

class _LogWeightSheet extends StatefulWidget {
  const _LogWeightSheet({required this.initial});
  final double initial;

  @override
  State<_LogWeightSheet> createState() => _LogWeightSheetState();
}

class _LogWeightSheetState extends State<_LogWeightSheet> {
  late double _kg = widget.initial;
  DateTime _date = DateTime.now();

  void _step(double d) => setState(() => _kg = (_kg + d).clamp(25, 300));

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Log weight', style: AppText.title),
          const SizedBox(height: 4),
          Text('Best: on waking, after the bathroom, before food.', style: AppText.caption),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StepBtn(icon: Icons.remove_rounded, onTap: () => _step(-0.1), onLong: () => _step(-1)),
              const SizedBox(width: 20),
              Column(
                children: [
                  Text(
                    _kg.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 46, fontWeight: FontWeight.w700, height: 1),
                  ),
                  Text('kg', style: AppText.caption),
                ],
              ),
              const SizedBox(width: 20),
              _StepBtn(icon: Icons.add_rounded, onTap: () => _step(0.1), onLong: () => _step(1)),
            ],
          ),
          const SizedBox(height: 6),
          Text('Tap ±0.1 · hold ±1', style: AppText.caption),
          const SizedBox(height: 16),
          ActionChip(
            avatar: Icon(Icons.event_rounded, size: 18, color: AppColors.primary),
            label: Text(DateKeys.friendly(_date)),
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2015),
                lastDate: DateTime.now(),
              );
              if (d != null) setState(() => _date = d);
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.check_rounded),
              label: const Text('Save'),
              onPressed: () {
                context.read<ProfileBloc>().add(WeightLogged(_kg, _date));
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap, required this.onLong});
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback onLong;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLong,
      child: IconButton.filledTonal(onPressed: onTap, icon: Icon(icon), iconSize: 28),
    );
  }
}
