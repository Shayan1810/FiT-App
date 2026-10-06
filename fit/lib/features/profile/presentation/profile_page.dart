import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/depth_card.dart';
import '../../../core/widgets/entrance.dart';
import '../../../core/widgets/trend_chart.dart';
import '../../insights/domain/calculators/body_composition_calculator.dart';
import '../../insights/domain/calculators/energy_calculator.dart';
import '../../insights/domain/calculators/weight_trend_calculator.dart';
import '../domain/entities/user_profile.dart';
import 'bloc/profile_bloc.dart';
import 'log_weight_sheet.dart';
import '../../../core/platform/health_brand.dart';

/// Profile: photo, body data, goal and the weight log with trend chart.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your profile')),
      body: BlocBuilder<ProfileBloc, ProfileState>(
        builder: (context, s) {
          final p = s.profile;
          if (p == null) return const SizedBox();
          return ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              Entrance(child: _Identity(p)),
              Entrance(
                index: 1,
                child: _ProfileForm(key: ValueKey(p), profile: p),
              ),
              Entrance(index: 2, child: _WeightSection(s)),
            ],
          );
        },
      ),
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity(this.p);
  final UserProfile p;

  Future<void> _pickPhoto(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !context.mounted) return;
    final file = await ImagePicker().pickImage(source: source, maxWidth: 600, imageQuality: 85);
    if (file == null || !context.mounted) return;
    // Copy into app storage so the photo survives gallery clean-ups.
    final dir = await getApplicationDocumentsDirectory();
    final saved = await File(
      file.path,
    ).copy('${dir.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg');
    if (!context.mounted) return;
    context.read<ProfileBloc>().add(ProfileSaved(p.copyWith(photoPath: saved.path)));
  }

  @override
  Widget build(BuildContext context) {
    final bmr = EnergyCalculator.bmr(p);
    final photo = p.photoPath;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: DepthCard(
        style: DepthStyle.primary,
        tilt: true,
        child: Row(
          children: [
            GestureDetector(
              onTap: () => _pickPhoto(context),
              child: Hero(
                tag: 'avatar',
                child: Container(
                  decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: AppShadows.dark(depth: 0.5)),
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.surface,
                    backgroundImage: photo != null && File(photo).existsSync()
                        ? FileImage(File(photo))
                        : null,
                    child: photo == null ? Icon(Icons.add_a_photo_rounded, color: AppColors.primary) : null,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Pill('${p.age} y', color: Colors.white),
                      Pill(
                        'BMI ${p.bmi.toStringAsFixed(1)} · ${BodyCompositionCalculator.bmiCategory(p.bmi)}',
                        color: Colors.white,
                      ),
                      Pill('BMR ${bmr.bmr.round()} kcal', color: Colors.white),
                    ],
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

class _ProfileForm extends StatefulWidget {
  const _ProfileForm({super.key, required this.profile});
  final UserProfile profile;

  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  late final _name = TextEditingController(text: widget.profile.name);
  late final _height = TextEditingController(text: widget.profile.heightCm.toStringAsFixed(0));
  late final _bf = TextEditingController(text: widget.profile.bodyFatPct?.toStringAsFixed(1) ?? '');
  late final _adj = TextEditingController(
    text: widget.profile.bmrAdjustPct == 0 ? '' : widget.profile.bmrAdjustPct.toStringAsFixed(0),
  );
  late Sex _sex = widget.profile.sex;
  late DateTime _dob = widget.profile.dateOfBirth;
  late GoalType _goal = widget.profile.goal;
  late double _rate = widget.profile.weeklyRateKg == 0 ? 0.5 : widget.profile.weeklyRateKg;

  @override
  void dispose() {
    _name.dispose();
    _height.dispose();
    _bf.dispose();
    _adj.dispose();
    super.dispose();
  }

  void _save() {
    final h = double.tryParse(_height.text.replaceAll(',', '.'));
    final bf = double.tryParse(_bf.text.replaceAll(',', '.'));
    if (_name.text.trim().isEmpty || h == null || h < 100 || h > 250) {
      showToast(context, 'Please enter a name and a height between 100 and 250 cm.');
      return;
    }
    if (bf != null && (bf < 3 || bf > 60)) {
      showToast(context, 'Body fat should be between 3 and 60 %.');
      return;
    }
    final adj = double.tryParse(_adj.text.replaceAll(',', '.')) ?? 0;
    if (adj < -30 || adj > 30) {
      showToast(context, 'Metabolism adjustment should be between −30 and +30 %.');
      return;
    }
    context.read<ProfileBloc>().add(
      ProfileSaved(
        widget.profile.copyWith(
          name: _name.text.trim(),
          heightCm: h,
          sex: _sex,
          dateOfBirth: _dob,
          goal: _goal,
          weeklyRateKg: _goal == GoalType.maintain ? 0 : _rate,
          bodyFatPct: bf,
          clearBodyFat: bf == null,
          bmrAdjustPct: adj,
        ),
      ),
    );
    showToast(context, 'Profile saved — targets updated.');
  }

  Future<void> _estimateBodyFat() async {
    final result = await showAppSheet<double>(
      context,
      _NavySheet(sex: _sex, heightCm: double.tryParse(_height.text) ?? widget.profile.heightCm),
    );
    if (result != null) setState(() => _bf.text = result.toStringAsFixed(1));
  }

  @override
  Widget build(BuildContext context) {
    final pctOfBw = _rate / widget.profile.weightKg * 100;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: DepthCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('About you', style: AppText.title),
            const SizedBox(height: 14),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            SegmentedButton<Sex>(
              segments: const [
                ButtonSegment(value: Sex.male, label: Text('Male'), icon: Icon(Icons.male_rounded)),
                ButtonSegment(value: Sex.female, label: Text('Female'), icon: Icon(Icons.female_rounded)),
              ],
              selected: {_sex},
              onSelectionChanged: (v) => setState(() => _sex = v.first),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _dob,
                        firstDate: DateTime(1920),
                        lastDate: DateTime.now().subtract(const Duration(days: 365 * 13)),
                      );
                      if (d != null) setState(() => _dob = d);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Date of birth'),
                      child: Text(DateFormat('d MMM yyyy').format(_dob)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _height,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Height', suffixText: 'cm'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bf,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Body fat (optional)',
                suffixText: '%',
                helperText: 'If set, BMR uses Katch–McArdle (lean mass based)',
                helperMaxLines: 2,
                suffixIcon: IconButton(
                  tooltip: 'Estimate with tape measure',
                  icon: const Icon(Icons.straighten_rounded),
                  onPressed: _estimateBodyFat,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _adj,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: const InputDecoration(
                labelText: 'Metabolism adjustment (optional)',
                suffixText: '%',
                helperText: 'e.g. −10 if a medication or condition lowers your resting metabolism',
                helperMaxLines: 2,
              ),
            ),
            const SizedBox(height: 20),
            Text('Goal', style: AppText.subtitle),
            const SizedBox(height: 10),
            SegmentedButton<GoalType>(
              segments: const [
                ButtonSegment(value: GoalType.lose, label: Text('Lose')),
                ButtonSegment(value: GoalType.maintain, label: Text('Maintain')),
                ButtonSegment(value: GoalType.gain, label: Text('Gain')),
              ],
              selected: {_goal},
              onSelectionChanged: (v) => setState(() => _goal = v.first),
            ),
            if (_goal != GoalType.maintain) ...[
              const SizedBox(height: 12),
              Text(
                '${_rate.toStringAsFixed(2)} kg per week  (${pctOfBw.toStringAsFixed(1)} % of body weight)',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Slider(
                value: _rate,
                min: 0.1,
                max: 1.0,
                divisions: 18,
                onChanged: (v) => setState(() => _rate = v),
              ),
              Text(
                _goal == GoalType.lose
                    ? 'Evidence favours 0.5–1 % of body weight per week to keep muscle (Helms 2014).'
                    : 'Lean gains: ~0.25–0.5 % of body weight per week limits fat gain (Iraki 2019).',
                style: AppText.caption,
              ),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Save profile'),
            ),
          ],
        ),
      ),
    );
  }
}

/// U.S. Navy tape-measure body-fat estimator.
class _NavySheet extends StatefulWidget {
  const _NavySheet({required this.sex, required this.heightCm});
  final Sex sex;
  final double heightCm;

  @override
  State<_NavySheet> createState() => _NavySheetState();
}

class _NavySheetState extends State<_NavySheet> {
  final _neck = TextEditingController();
  final _waist = TextEditingController();
  final _hip = TextEditingController();
  double? _result;

  void _calc() {
    double? v(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.'));
    setState(
      () => _result = (v(_neck) == null || v(_waist) == null)
          ? null
          : BodyCompositionCalculator.navyBodyFat(
              sex: widget.sex,
              heightCm: widget.heightCm,
              neckCm: v(_neck)!,
              waistCm: v(_waist)!,
              hipCm: v(_hip),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final female = widget.sex == Sex.female;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Estimate body fat', style: AppText.title),
          const SizedBox(height: 4),
          Text(
            'U.S. Navy method. Measure ${female ? 'neck, waist (narrowest) and hips (widest)' : 'neck and waist (at the navel)'} in cm.',
            style: AppText.caption,
          ),
          const SizedBox(height: 14),
          for (final (label, c) in [('Neck', _neck), ('Waist', _waist), if (female) ('Hips', _hip)])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                controller: c,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: label, suffixText: 'cm'),
                onChanged: (_) => _calc(),
              ),
            ),
          if (_result != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '≈ ${_result!.toStringAsFixed(1)} % body fat',
                textAlign: TextAlign.center,
                style: AppText.title.copyWith(color: AppColors.primary),
              ),
            ),
          FilledButton(
            onPressed: _result == null ? null : () => Navigator.pop(context, _result),
            child: const Text('Use this value'),
          ),
        ],
      ),
    );
  }
}

class _WeightSection extends StatelessWidget {
  const _WeightSection(this.s);
  final ProfileState s;

  @override
  Widget build(BuildContext context) {
    final trend = WeightTrendCalculator.ema(s.weights);
    final rate = WeightTrendCalculator.weeklyRate(trend);
    final first = trend.isEmpty ? DateTime.now() : trend.first.date;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: DepthCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Weight trend', style: AppText.title)),
                FilledButton.tonalIcon(
                  onPressed: () => showLogWeightSheet(context),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Log'),
                ),
              ],
            ),
            if (rate != null)
              Text(
                '${rate >= 0 ? '+' : ''}${rate.toStringAsFixed(2)} kg/week (smoothed EMA trend)',
                style: AppText.caption,
              ),
            const SizedBox(height: 12),
            if (trend.length < 2)
              const EmptyState(
                icon: Icons.monitor_weight_rounded,
                title: 'Log a few weigh-ins',
                message: 'Your smoothed trend line appears after two entries.',
              )
            else
              TrendChart(
                points: [
                  for (final p in trend.length > 60 ? trend.sublist(trend.length - 60) : trend)
                    TrendDatum(p.date.difference(first).inHours / 24, p.raw, p.trend),
                ],
              ),
            const SizedBox(height: 8),
            for (final w in s.weights.reversed.take(10))
              Dismissible(
                key: ValueKey('w_${w.dayKey}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  child: const Icon(Icons.delete_rounded, color: AppColors.danger),
                ),
                onDismissed: (_) => context.read<ProfileBloc>().add(WeightDeleted(w.dayKey)),
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.scale_rounded, color: AppColors.textMuted),
                  title: Text(
                    '${w.kg.toStringAsFixed(1)} kg',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(DateKeys.friendly(w.date)),
                  trailing: w.source.name == 'healthConnect'
                      ? Pill(HealthBrand.hub, color: AppColors.steps)
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
