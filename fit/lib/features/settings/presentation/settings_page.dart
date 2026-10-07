import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../transformation/domain/repositories/transformation_repository.dart';
import '../../transformation/presentation/transformation_cubit.dart';
import '../../transformation/presentation/transformation_page.dart';
import '../../../core/storage/backup_service.dart';
import '../../hevy/data/hevy_sync.dart';
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
          Entrance(child: _ModeSection()),
          SizedBox(height: 16),
          Entrance(child: _AppearanceSection()),
          SizedBox(height: 16),
          Entrance(index: 1, child: _HealthSection()),
          SizedBox(height: 16),
          Entrance(index: 2, child: _HevySection()),
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
          Text(
            'Backup: copies all your data as one line of text. Keep it in a note or send it to yourself, '
            'then restore it on a new phone or after reinstalling.',
            style: AppText.caption,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.backup_rounded),
                  label: const Text('Copy backup'),
                  onPressed: () async {
                    final text = BackupService().export();
                    await Clipboard.setData(ClipboardData(text: text));
                    if (context.mounted) {
                      showToast(
                        context,
                        'Backup copied (${(text.length / 1024).toStringAsFixed(0)} KB). Paste it somewhere safe.',
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.settings_backup_restore_rounded),
                  label: const Text('Restore'),
                  onPressed: () => _restore(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
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

  Future<void> _restore(BuildContext context) async {
    final clip = (await Clipboard.getData('text/plain'))?.text ?? '';
    if (!context.mounted) return;
    final c = TextEditingController(text: clip.trim().startsWith(BackupService.prefix) ? clip.trim() : '');
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Paste the backup text. It replaces all data on this phone.'),
            const SizedBox(height: 12),
            TextField(
              controller: c,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(hintText: 'FITBACKUP1:…'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Restore')),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty || !context.mounted) return;
    final service = BackupService();
    try {
      final counts = service.inspect(text);
      await service.restore(text);
      if (!context.mounted) return;
      context.read<ProfileBloc>().add(const ProfileStarted());
      context.read<InsightsBloc>().add(const InsightsRefreshRequested());
      await context.read<TransformationCubit>().start();
      if (!context.mounted) return;
      final records = counts.values.fold<int>(0, (a, b) => a + b);
      showToast(context, 'Restored $records records. Restart FiT if anything looks out of date.');
    } on FormatException catch (e) {
      if (context.mounted) showToast(context, e.message);
    }
  }
}

/// General / Transformation mode and the plan's management.
class _ModeSection extends StatelessWidget {
  const _ModeSection();

  @override
  Widget build(BuildContext context) {
    final st = context.watch<TransformationCubit>().state;
    final cubit = context.read<TransformationCubit>();
    final plan = st.plan;
    final now = DateTime.now();
    final usable = plan != null && !plan.isFinished(now);
    return DepthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag_rounded, color: AppColors.primary),
              const SizedBox(width: 10),
              Text('Mode', style: AppText.subtitle),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Transformation mode follows a time-boxed plan (diet, training, cardio, sleep, skincare) and opens on '
            'your daily checklist until you switch back or the plan ends.',
            style: AppText.caption,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<AppMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: AppMode.general,
                  icon: Icon(Icons.dashboard_rounded),
                  label: Text('General'),
                ),
                ButtonSegment(
                  value: AppMode.transformation,
                  icon: Icon(Icons.flag_rounded),
                  label: Text('Transformation'),
                ),
              ],
              selected: {st.mode},
              onSelectionChanged: (v) async {
                if (v.first == AppMode.transformation && !usable) {
                  await openPlanEditor(context);
                  return;
                }
                await cubit.setMode(v.first);
              },
            ),
          ),
          const SizedBox(height: 12),
          if (plan != null) ...[
            Text(
              '${plan.name} · ${DateFormat('d MMM').format(plan.start)} – ${DateFormat('d MMM yyyy').format(plan.end)}'
              '${plan.isFinished(now) ? ' · finished' : ''}',
              style: AppText.body.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: Icon(plan == null || !usable ? Icons.add_rounded : Icons.tune_rounded, size: 18),
                label: Text(plan == null || !usable ? 'New transformation' : 'Edit plan'),
                onPressed: () => openPlanEditor(context, usable ? plan : null),
              ),
              ActionChip(
                avatar: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Import plan'),
                onPressed: () => _import(context),
              ),
              if (plan != null)
                ActionChip(
                  avatar: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copy plan'),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: cubit.export()));
                    if (context.mounted) {
                      showToast(context, 'Plan copied as text. Paste it anywhere to back it up.');
                    }
                  },
                ),
              if (plan != null)
                ActionChip(
                  avatar: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
                  label: const Text('Delete plan'),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('Delete ${plan.name}?'),
                        content: const Text(
                          'The plan and its daily ticks are removed. Food, workouts, sleep and weigh-ins '
                          'you logged stay in your history.',
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) await cubit.deletePlan();
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _import(BuildContext context) async {
    final clip = (await Clipboard.getData('text/plain'))?.text ?? '';
    if (!context.mounted) return;
    final c = TextEditingController(text: clip.contains('fit-plan') ? clip : '');
    final json = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import plan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Paste a FiT plan (text copied with "Copy plan" or a .json plan file).'),
            const SizedBox(height: 12),
            TextField(
              controller: c,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(hintText: '{ "format": "fit-plan", … }'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Import')),
        ],
      ),
    );
    if (json == null || json.trim().isEmpty || !context.mounted) return;
    final error = await context.read<TransformationCubit>().import(json);
    if (error != null && context.mounted) showToast(context, error);
  }
}

/// Hevy workout tracker connection.
class _HevySection extends StatefulWidget {
  const _HevySection();

  @override
  State<_HevySection> createState() => _HevySectionState();
}

class _HevySectionState extends State<_HevySection> {
  final _key = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String?> Function() task) async {
    setState(() => _busy = true);
    final msg = await task();
    if (!mounted) return;
    setState(() => _busy = false);
    if (msg != null) showToast(context, msg);
  }

  @override
  Widget build(BuildContext context) {
    final hevy = sl<HevySync>();
    final last = hevy.lastSync;
    return DepthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge(icon: Icons.fitness_center_rounded, color: AppColors.info, onDark: false),
              const SizedBox(width: 12),
              Expanded(child: Text('Hevy', style: AppText.title)),
              Pill(
                hevy.configured ? 'Connected' : 'Optional',
                color: hevy.configured ? AppColors.success : AppColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Log your gym sessions in Hevy and FiT imports them automatically: sets, reps and kg feed your '
            'strength charts, training load and Nebula. In Transformation mode a Hevy workout ticks that day\'s '
            'planned workout. Needs a Hevy API key (Hevy Pro: Settings > Developer).',
            style: AppText.body,
          ),
          if (last != null) ...[
            const SizedBox(height: 8),
            Text('Last sync: ${DateFormat('d MMM, HH:mm').format(last)}', style: AppText.caption),
          ],
          const SizedBox(height: 12),
          if (!hevy.configured) ...[
            TextField(
              controller: _key,
              decoration: const InputDecoration(labelText: 'Hevy API key'),
              obscureText: true,
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                      if (_key.text.trim().isEmpty) return 'Paste your Hevy API key first.';
                      final err = await hevy.connect(_key.text);
                      if (err != null) return err;
                      _key.clear();
                      return (await hevy.sync()).toString();
                    }),
              icon: _busy
                  ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.link_rounded),
              label: const Text('Connect Hevy'),
            ),
          ] else
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _busy ? null : () => _run(() async => (await hevy.sync()).toString()),
                    icon: _busy
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync_rounded),
                    label: const Text('Sync now'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                            await hevy.disconnect();
                            return 'Hevy disconnected. Imported workouts are kept.';
                          }),
                    child: const Text('Disconnect'),
                  ),
                ),
              ],
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
                    Text('Version 2.1.0 · MDG Nebula Project', style: TextStyle(color: soft)),
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
          Text('github.com/Shayan1810/FiT-App', style: TextStyle(color: soft)),
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
