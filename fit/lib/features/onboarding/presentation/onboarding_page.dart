import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/depth_card.dart';
import '../../../core/widgets/nebula_orb.dart';
import '../../profile/domain/entities/user_profile.dart';
import '../../profile/presentation/bloc/profile_bloc.dart';
import '../../../core/platform/health_brand.dart';

/// First-launch flow: meet Nebula → you → body → goal.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _page = PageController();
  int _step = 0;

  final _name = TextEditingController();
  Sex _sex = Sex.male;
  DateTime _dob = DateTime(2002, 1, 1);
  double _height = 170;
  double _weight = 70;
  GoalType _goal = GoalType.maintain;
  double _rate = 0.5;

  static final _steps = 4;

  @override
  void dispose() {
    _page.dispose();
    _name.dispose();
    super.dispose();
  }

  bool get _canNext => _step != 1 || _name.text.trim().isNotEmpty;

  void _next() {
    FocusScope.of(context).unfocus();
    if (_step == _steps - 1) {
      context.read<ProfileBloc>().add(
        ProfileSaved(
          UserProfile(
            name: _name.text.trim(),
            sex: _sex,
            dateOfBirth: _dob,
            heightCm: _height,
            weightKg: _weight,
            goal: _goal,
            weeklyRateKg: _goal == GoalType.maintain ? 0 : _rate,
          ),
          completeOnboarding: true,
        ),
      );
      return;
    }
    _page.nextPage(duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  for (var i = 0; i < _steps; i++)
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: i <= _step ? AppColors.primary : AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _page,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _step = i),
                children: [_welcome(), _you(), _body(), _goalStep()],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Row(
                children: [
                  if (_step > 0)
                    TextButton(
                      onPressed: () => _page.previousPage(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOut,
                      ),
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _canNext ? _next : null,
                    icon: Icon(_step == _steps - 1 ? Icons.check_rounded : Icons.arrow_forward_rounded),
                    label: Text(
                      _step == 0
                          ? "Let's start"
                          : _step == _steps - 1
                          ? 'Finish'
                          : 'Next',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _frame(String title, String subtitle, List<Widget> children) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
    children: [
      Text(title, style: AppText.display),
      const SizedBox(height: 6),
      Text(subtitle, style: AppText.caption.copyWith(fontSize: 14)),
      const SizedBox(height: 24),
      ...children,
    ],
  );

  Widget _welcome() => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.asset('assets/branding/logo_tile.png', width: 72, height: 72),
          ),
        ),
      ),
      const SizedBox(height: 16),
      Center(child: NebulaOrb(size: 180)),
      const SizedBox(height: 12),
      Text('Hi, I\'m Nebula.', style: AppText.display, textAlign: TextAlign.center),
      SizedBox(height: 10),
      Text(
        'I\'m your FiT coach. I bring your food, workouts, steps and sleep together '
        'and every evening tell you exactly what to do tomorrow — using published sports '
        'science, not guesses. Everything stays on your phone, and works offline.',
        style: AppText.body,
        textAlign: TextAlign.center,
      ),
    ],
  );

  Widget _you() => _frame('About you', 'Used for your energy needs (Mifflin–St Jeor).', [
    TextField(
      controller: _name,
      textCapitalization: TextCapitalization.words,
      decoration: const InputDecoration(labelText: 'Your name'),
      onChanged: (_) => setState(() {}),
    ),
    const SizedBox(height: 16),
    SegmentedButton<Sex>(
      segments: const [
        ButtonSegment(value: Sex.male, label: Text('Male'), icon: Icon(Icons.male_rounded)),
        ButtonSegment(value: Sex.female, label: Text('Female'), icon: Icon(Icons.female_rounded)),
      ],
      selected: {_sex},
      onSelectionChanged: (v) => setState(() => _sex = v.first),
    ),
    const SizedBox(height: 16),
    DepthCard(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: _dob,
          firstDate: DateTime(1920),
          lastDate: DateTime.now().subtract(const Duration(days: 365 * 13)),
        );
        if (d != null) setState(() => _dob = d);
      },
      child: Row(
        children: [
          Icon(Icons.cake_rounded, color: AppColors.primary),
          const SizedBox(width: 12),
          const Expanded(child: Text('Date of birth')),
          Text(DateFormat('d MMM yyyy').format(_dob), style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    ),
  ]);

  Widget _body() => _frame('Your body', 'Drag to adjust. You can refine later.', [
    _sliderCard('Height', '${_height.round()} cm', _height, 130, 220, (v) => setState(() => _height = v)),
    const SizedBox(height: 16),
    _sliderCard(
      'Weight',
      '${_weight.toStringAsFixed(1)} kg',
      _weight,
      35,
      200,
      (v) => setState(() => _weight = (v * 2).round() / 2),
    ),
  ]);

  Widget _sliderCard(String label, String value, double v, double min, double max, ValueChanged<double> on) =>
      DepthCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(label, style: AppText.subtitle),
                const Spacer(),
                Text(value, style: AppText.title.copyWith(color: AppColors.primary)),
              ],
            ),
            Slider(value: v, min: min, max: max, onChanged: on),
          ],
        ),
      );

  Widget _goalStep() => _frame('Your goal', 'I\'ll set calories and protein from this.', [
    for (final (g, title, sub, icon) in [
      (GoalType.lose, 'Lose fat', 'Keep muscle with a moderate deficit', Icons.trending_down_rounded),
      (GoalType.maintain, 'Maintain & perform', 'Fuel training, stay at this weight', Icons.balance_rounded),
      (GoalType.gain, 'Build muscle', 'Small surplus for lean gains', Icons.trending_up_rounded),
    ])
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DepthCard(
          style: _goal == g ? DepthStyle.primary : DepthStyle.light,
          onTap: () => setState(() => _goal = g),
          child: Row(
            children: [
              Icon(icon, color: _goal == g ? Colors.white : AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _goal == g ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      sub,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: _goal == g ? Colors.white70 : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    if (_goal != GoalType.maintain) ...[
      const SizedBox(height: 8),
      Text('${_rate.toStringAsFixed(2)} kg / week', style: AppText.subtitle, textAlign: TextAlign.center),
      Slider(value: _rate, min: 0.1, max: 1.0, divisions: 18, onChanged: (v) => setState(() => _rate = v)),
      Text(
        _goal == GoalType.lose
            ? 'Recommended: 0.5–1 % of body weight per week (≈ ${(0.005 * _weight).toStringAsFixed(2)}–${(0.01 * _weight).toStringAsFixed(2)} kg).'
            : 'Recommended: ≤ 0.5 % of body weight per week (≈ ${(0.005 * _weight).toStringAsFixed(2)} kg).',
        style: AppText.caption,
        textAlign: TextAlign.center,
      ),
    ],
    const SizedBox(height: 12),
    Pill('Tip: connect ${HealthBrand.app} later in Train → Connect', icon: Icons.favorite_rounded),
  ]);
}
