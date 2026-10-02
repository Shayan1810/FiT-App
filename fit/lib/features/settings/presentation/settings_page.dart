import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/dev/demo_data.dart';
import '../../../core/di/injector.dart';
import '../../../core/storage/settings_store.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/depth_card.dart';
import '../../../core/widgets/entrance.dart';
import '../../activity/domain/repositories/activity_repository.dart';
import '../../activity/presentation/bloc/activity_cubit.dart';
import '../../health_sync/domain/health_sync_repository.dart';
import '../../insights/presentation/bloc/insights_bloc.dart';
import '../../nutrition/domain/repositories/nutrition_repository.dart';
import '../../profile/domain/repositories/profile_repository.dart';
import '../../profile/presentation/bloc/profile_bloc.dart';
import '../../sleep/domain/repositories/sleep_repository.dart';
import '../../workout/domain/repositories/workout_repository.dart';
import 'settings_cubit.dart';
import 'theme_cubit.dart';
import '../../../core/platform/health_brand.dart';

/// Settings, integrations, diagnostics and about.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
    context.read<SettingsCubit>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: const [
          Entrance(child: _AppearanceSection()),
          SizedBox(height: 16),
          Entrance(index: 1, child: _HealthSection()),
          SizedBox(height: 16),
          Entrance(index: 2, child: _GeminiSection()),
          SizedBox(height: 16),
          Entrance(index: 3, child: _DiagnosticsSection()),
          SizedBox(height: 16),
          Entrance(index: 4, child: _DataSection()),
          SizedBox(height: 16),
          Entrance(index: 5, child: _AboutSection()),
        ],
      ),
    );
  }
}

class _HealthSection extends StatelessWidget {
  const _HealthSection();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ActivityCubit, ActivityState>(
      listenWhen: (a, b) => b.message != null && a.message != b.message,
      listener: (context, s) => showToast(context, s.message!),
      builder: (context, s) {
        final (label, color) = switch (s.link) {
          HealthLinkStatus.connected => ('Connected', AppColors.success),
          HealthLinkStatus.notAuthorized => ('Not connected', AppColors.warning),
          HealthLinkStatus.needsInstall => ('Install ${HealthBrand.hub}', AppColors.warning),
          HealthLinkStatus.unavailable => ('Unavailable', AppColors.danger),
        };
        return DepthCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const IconBadge(icon: Icons.favorite_rounded, color: AppColors.steps, onDark: false),
                  const SizedBox(width: 12),
                  Expanded(child: Text(HealthBrand.app, style: AppText.title)),
                  Pill(label, color: color),
                ],
              ),
              const SizedBox(height: 12),
              Text(HealthBrand.setup, style: AppText.body),
              if (s.lastSync != null) ...[
                const SizedBox(height: 8),
                Text('Last sync: ${DateFormat('d MMM, HH:mm').format(s.lastSync!)}', style: AppText.caption),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: s.link == HealthLinkStatus.connected
                          ? null
                          : () => context.read<ActivityCubit>().connect(),
                      icon: const Icon(Icons.link_rounded),
                      label: Text(s.link == HealthLinkStatus.needsInstall ? 'Install' : 'Connect'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: s.link != HealthLinkStatus.connected || s.syncing
                          ? null
                          : () => context.read<ActivityCubit>().sync(days: 28),
                      icon: s.syncing
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync_rounded),
                      label: const Text('Sync now'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GeminiSection extends StatefulWidget {
  const _GeminiSection();

  @override
  State<_GeminiSection> createState() => _GeminiSectionState();
}

class _GeminiSectionState extends State<_GeminiSection> {
  final _key = TextEditingController();
  late final _model = TextEditingController(text: sl<SettingsStore>().geminiModel);
  bool _obscure = true;

  @override
  void dispose() {
    _key.dispose();
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsCubit>().state;
    return DepthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(icon: Icons.auto_awesome_rounded, color: AppColors.primary, onDark: false),
              const SizedBox(width: 12),
              Expanded(child: Text('AI food recognition', style: AppText.title)),
              Pill(
                s.hasApiKey ? 'On' : 'Optional',
                color: s.hasApiKey ? AppColors.success : AppColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Describe any meal in plain words and Nebula AI (Google Gemini) works out the calories and '
            'macros. Foods you save in "My foods" and meals you have logged before are recognised '
            'offline without the AI. Get a free key at aistudio.google.com/apikey — it is stored '
            'only on this phone.',
            style: AppText.body,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _key,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: s.hasApiKey ? 'Replace API key (saved)' : 'Gemini API key',
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _model,
            decoration: const InputDecoration(
              labelText: 'Model',
              helperText: 'Default: ${SettingsStore.defaultModel}',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    final cubit = context.read<SettingsCubit>();
                    await cubit.setModel(_model.text);
                    if (_key.text.trim().isNotEmpty) await cubit.setApiKey(_key.text);
                    _key.clear();
                    if (context.mounted) showToast(context, 'AI settings saved');
                  },
                  child: const Text('Save'),
                ),
              ),
              if (s.hasApiKey) ...[
                const SizedBox(width: 10),
                TextButton(
                  onPressed: () => context.read<SettingsCubit>().setApiKey(''),
                  child: const Text('Remove key'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DiagnosticsSection extends StatelessWidget {
  const _DiagnosticsSection();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsCubit>().state;
    final storage = s.perf.where((p) => p.count > 0).toList();
    return DepthCard(
      style: DepthStyle.dark,
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Diagnostics',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
                IconButton(
                  onPressed: () => context.read<SettingsCubit>().refresh(),
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                ),
              ],
            ),
            _kv('Avg storage op (this session)', '${s.avgMs.toStringAsFixed(2)} ms'),
            _kv('Nutrition query success', '${(s.successRate * 100).toStringAsFixed(2)} %'),
            _kv('Queries · cache · offline DB', '${s.queries} · ${s.cacheHits} · ${s.localHits}'),
            _kv('Gemini calls (HTTP attempts)', '${s.geminiCalls} (${s.geminiAttempts})'),
            _kv('Waiting for connection', '${s.pendingJobs}'),
            if (storage.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                'Hive operations (avg / p95 ms)',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 4),
              for (final p in storage.take(12))
                _kv(
                  p.op.replaceFirst('fit_', ''),
                  '${p.avgMs.toStringAsFixed(2)} / ${p.p95Ms.toStringAsFixed(2)}  ×${p.count}',
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(k, style: const TextStyle(color: Colors.white70)),
        ),
        Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

class _DataSection extends StatelessWidget {
  const _DataSection();

  @override
  Widget build(BuildContext context) {
    return DepthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your data', style: AppText.title),
          const SizedBox(height: 8),
          Text(
            'Everything is stored offline on this phone (Hive database). Nothing is uploaded, '
            'except meal text sent to Gemini when you enable AI recognition.',
            style: AppText.body,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.science_rounded),
            label: const Text('Load 3 weeks of demo data'),
            onPressed: () async {
              await DemoData.seed(
                profile: sl<ProfileRepository>(),
                nutrition: sl<NutritionRepository>(),
                activity: sl<ActivityRepository>(),
                workouts: sl<WorkoutRepository>(),
                sleep: sl<SleepRepository>(),
                settings: sl<SettingsStore>(),
              );
              if (context.mounted) showToast(context, 'Demo data loaded — explore every tab!');
            },
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
            icon: const Icon(Icons.delete_forever_rounded),
            label: const Text('Reset all data'),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete everything?'),
                  content: const Text(
                    'Profile, food diary, workouts, sleep and settings will be erased. This cannot be undone.',
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
                    ),
                  ],
                ),
              );
              if (ok != true || !context.mounted) return;
              await context.read<SettingsCubit>().resetAll();
              if (!context.mounted) return;
              context.read<ProfileBloc>().add(const ProfileStarted());
              context.read<InsightsBloc>().add(const InsightsRefreshRequested());
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
          ),
        ],
      ),
    );
  }
}

/// System / Light / Dark switch.
class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context) {
    final mode = context.watch<ThemeCubit>().state;
    return DepthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.palette_rounded, color: AppColors.primary),
              const SizedBox(width: 10),
              Text('Appearance', style: AppText.subtitle),
            ],
          ),
          const SizedBox(height: 4),
          Text('Dark mode uses the black & lime colours of the FiT logo.', style: AppText.caption),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_rounded),
                  label: Text('System'),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_rounded),
                  label: Text('Light'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_rounded),
                  label: Text('Dark'),
                ),
              ],
              selected: {mode},
              onSelectionChanged: (s) => context.read<ThemeCubit>().set(s.first),
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    final on = AppColors.onPrimary;
    final soft = on.withValues(alpha: 0.75);
    return DepthCard(
      style: DepthStyle.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset('assets/branding/logo_tile.png', width: 56, height: 56),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FiT',
                      style: TextStyle(color: on, fontSize: 22, fontWeight: FontWeight.w700),
                    ),
                    Text('Version 1.0.0 · MDG Nebula Project', style: TextStyle(color: soft)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Developed by Shayan Zafar',
            style: TextStyle(color: on, fontWeight: FontWeight.w600),
          ),
          Text('IIT Roorkee', style: TextStyle(color: soft)),
          Text('shayanzafar1810@gmail.com', style: TextStyle(color: soft)),
          const SizedBox(height: 12),
          Text(
            'Nebula\'s advice is educational and based on published research; it is not medical advice. '
            'Consult a professional for medical conditions.',
            style: TextStyle(color: soft, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
