import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/domain/data_source.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/bars_3d.dart';
import '../../../../core/widgets/common.dart';
import '../../../../core/widgets/depth_card.dart';
import '../../../../core/widgets/entrance.dart';
import '../../../../core/widgets/gauge_3d.dart';
import '../../../../core/widgets/macro_bar.dart';
import '../../../../core/widgets/ring_3d.dart';
import '../../../activity/presentation/bloc/activity_cubit.dart';
import '../../../activity/presentation/edit_steps_sheet.dart';
import '../../../health_sync/domain/health_sync_repository.dart';
import '../../../insights/domain/calculators/energy_calculator.dart';
import '../../../insights/domain/calculators/training_load_calculator.dart';
import '../../../insights/domain/entities/daily_briefing.dart';
import '../../../insights/presentation/bloc/insights_bloc.dart';
import '../../../profile/presentation/bloc/profile_bloc.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/entities/workout_session.dart';
import '../bloc/workout_bloc.dart';
import 'workout_editor_page.dart';
import '../../../../core/platform/health_brand.dart';

/// Train tab: steps (Samsung Health), training load and workout history.
class TrainPage extends StatelessWidget {
  const TrainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<ActivityCubit, ActivityState>(
      listenWhen: (a, b) => b.message != null && a.message != b.message,
      listener: (context, s) => showToast(context, s.message!),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 84),
          child: GradientFab(
            icon: Icons.add_rounded,
            label: 'Log workout',
            onTap: () =>
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WorkoutEditorPage())),
          ),
        ),
        body: BlocBuilder<InsightsBloc, InsightsState>(
          builder: (context, ins) {
            final b = ins.briefing;
            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverSafeArea(
                  bottom: false,
                  sliver: SliverToBoxAdapter(
                    child: PageHeader(
                      title: 'Train',
                      subtitle: 'Steps, training load & workouts',
                      trailing: const _SyncButton(),
                    ),
                  ),
                ),
                SliverList.list(
                  children: [
                    const Entrance(child: _HealthConnectBanner()),
                    if (b != null) ...[
                      Entrance(index: 1, child: _StepsHero(b)),
                      const Entrance(index: 2, child: _StepsWeek()),
                      Entrance(index: 3, child: _LoadCard(b)),
                      Entrance(index: 4, child: _MuscleRecoveryCard(b)),
                      Entrance(index: 5, child: _VolumeCard(b.load)),
                      Entrance(index: 5, child: _TomorrowCard(b.plan.training)),
                      const _StepsHistory(),
                    ],
                    const SectionHeader('History'),
                    const _History(),
                    const SizedBox(height: 170),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SyncButton extends StatelessWidget {
  const _SyncButton();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<ActivityCubit>().state;
    if (s.link != HealthLinkStatus.connected) return const SizedBox();
    return IconButton.filledTonal(
      tooltip: 'Sync ${HealthBrand.app}',
      onPressed: s.syncing ? null : () => context.read<ActivityCubit>().sync(),
      icon: s.syncing
          ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.sync_rounded),
    );
  }
}

class _HealthConnectBanner extends StatelessWidget {
  const _HealthConnectBanner();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<ActivityCubit>().state;
    if (s.link == HealthLinkStatus.connected || s.link == HealthLinkStatus.unavailable) {
      return const SizedBox();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: DepthCard(
        style: DepthStyle.accent,
        accent: AppColors.steps,
        tilt: true,
        child: Row(
          children: [
            const IconBadge(icon: Icons.favorite_rounded),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Connect ${HealthBrand.app}',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Auto-import steps, runs, sleep & weight via ${HealthBrand.hub}.',
                    style: TextStyle(color: Colors.white70, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.steps,
                minimumSize: const Size(0, 40),
              ),
              onPressed: () => context.read<ActivityCubit>().connect(),
              child: Text(s.link == HealthLinkStatus.needsInstall ? 'Install' : 'Connect'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepsHero extends StatelessWidget {
  const _StepsHero(this.b);
  final DailyBriefing b;

  @override
  Widget build(BuildContext context) {
    final t = b.today;
    final act = context.select((ActivityCubit c) => c.state.today);
    final fromDevice = act?.source == DataSource.healthConnect;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: DepthCard(
        style: DepthStyle.dark,
        tilt: true,
        child: Row(
          children: [
            SingleRing(
              progress: t.stepTarget == 0 ? 0 : t.steps / t.stepTarget,
              color: AppColors.steps,
              size: 120,
              stroke: 13,
              center: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fmtInt(t.steps),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
                  ),
                  const Text('steps', style: TextStyle(color: Colors.white60, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Goal ${fmtInt(t.stepTarget)}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  _stat(Icons.straighten_rounded, '${t.distanceKm.toStringAsFixed(2)} km'),
                  _stat(Icons.local_fire_department_rounded, '${fmtInt(t.energy.neat)} kcal moving'),
                  if (act?.restingHr != null)
                    _stat(Icons.favorite_rounded, '${act!.restingHr!.round()} bpm resting'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Pill(
                        fromDevice ? HealthBrand.app : 'Manual',
                        color: fromDevice ? AppColors.steps : Colors.white,
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => showEditStepsSheet(context),
                        child: const Icon(Icons.edit_rounded, color: Colors.white60, size: 18),
                      ),
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

  Widget _stat(IconData i, String s) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Icon(i, size: 14, color: Colors.white60),
        const SizedBox(width: 6),
        Text(s, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ],
    ),
  );
}

class _StepsWeek extends StatelessWidget {
  const _StepsWeek();

  @override
  Widget build(BuildContext context) {
    final week = context.select((ActivityCubit c) => c.state.week);
    final target = context.select((InsightsBloc b) => b.state.briefing?.today.stepTarget.toDouble());
    final days = DateKeys.lastNDays(DateTime.now(), 7);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: DepthCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Steps this week', style: AppText.title),
            const SizedBox(height: 12),
            Bars3D(
              color: AppColors.steps,
              target: target,
              valueLabel: (v) => fmtInt(v),
              data: [
                for (var i = 0; i < days.length; i++)
                  BarDatum(
                    label: DateFormat('E').format(days[i]).substring(0, 1),
                    value: (i < week.length ? week[i]?.steps ?? 0 : 0).toDouble(),
                    highlight: i == days.length - 1,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Last 14 days of steps — tap any day to edit (manual or Samsung Health).
class _StepsHistory extends StatelessWidget {
  const _StepsHistory();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<ActivityCubit>();
    final days = DateKeys.lastNDays(DateTime.now(), 14).reversed.toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: DepthCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Steps history', style: AppText.title)),
                TextButton.icon(
                  onPressed: () => showEditStepsSheet(context),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add / edit'),
                ),
              ],
            ),
            for (final d in days.take(7))
              Builder(
                builder: (context) {
                  final r = cubit.dayRecord(d);
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.only(right: 8),
                    onTap: () => showEditStepsSheet(context, day: d),
                    title: Text(DateKeys.friendly(d), style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text(
                      r == null
                          ? 'No data — tap to add'
                          : '${r.distanceKm == null ? '' : '${r.distanceKm!.toStringAsFixed(2)} km · '}'
                                '${r.source == DataSource.healthConnect ? HealthBrand.app : 'Manual'}',
                      style: AppText.caption,
                    ),
                    trailing: Text(
                      r == null ? '—' : fmtInt(r.steps),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _LoadCard extends StatelessWidget {
  const _LoadCard(this.b);
  final DailyBriefing b;

  @override
  Widget build(BuildContext context) {
    final l = b.load;
    final (zone, color) = switch (l.zone) {
      AcwrZone.sweetSpot => ('Sweet spot', AppColors.success),
      AcwrZone.detraining => ('Below usual', AppColors.info),
      AcwrZone.caution => ('Caution', AppColors.warning),
      AcwrZone.danger => ('Spike — injury risk', AppColors.danger),
      AcwrZone.unknown => ('Baseline ${l.baselineDays.clamp(0, 21)}/21 days', AppColors.textSecondary),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: DepthCard(
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: Text('Training load', style: AppText.title)),
                Pill(zone, color: color),
              ],
            ),
            const SizedBox(height: 8),
            Gauge3D(
              value: (l.acwr ?? 0).clamp(0, 2),
              max: 2,
              label: l.acwr == null ? '—' : l.acwr!.toStringAsFixed(2),
              caption: 'acute : chronic ratio',
              colors: const [
                AppColors.info,
                AppColors.success,
                AppColors.success,
                AppColors.warning,
                AppColors.danger,
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _mini('This week', fmtInt(l.acuteLoad)),
                _mini('Usual week', fmtInt(l.chronicWeeklyLoad)),
                _mini('Monotony', l.monotony == null ? '—' : l.monotony!.toStringAsFixed(1)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Load = session RPE × minutes (Foster). Keep weekly increases ≤ 10 %.',
              style: AppText.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _mini(String k, String v) => Column(
    children: [
      Text(v, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      Text(k, style: AppText.caption),
    ],
  );
}

/// Per-muscle recovery bars, scaled by the personal recovery factor.
class _MuscleRecoveryCard extends StatelessWidget {
  const _MuscleRecoveryCard(this.b);
  final DailyBriefing b;

  @override
  Widget build(BuildContext context) {
    if (b.load.lastTrainedByMuscle.isEmpty) return const SizedBox();
    final rec = TrainingLoadCalculator.muscleRecovery(b.load, DateTime.now(), factor: b.recovery.factor);
    final f = b.recovery.factor;
    final trained = rec.entries.where((e) => b.load.lastTrainedByMuscle.containsKey(e.key)).toList()
      ..sort((a, c) => a.value.compareTo(c.value));
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: DepthCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Muscle recovery', style: AppText.title)),
                Pill(
                  'Speed ×${f.toStringAsFixed(2)}',
                  color: f >= 0.95 ? AppColors.success : (f >= 0.85 ? AppColors.warning : AppColors.danger),
                ),
              ],
            ),
            Text(
              b.recovery.factorParts.isEmpty
                  ? 'Typical recovery speed.'
                  : b.recovery.factorParts.map((p) => '${p.$1} ×${p.$2.toStringAsFixed(2)}').join(' · '),
              style: AppText.caption,
            ),
            const SizedBox(height: 12),
            for (final e in trained)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: MacroBar(
                  label: e.key.label,
                  value: e.value * 100,
                  target: 100,
                  unit: '%',
                  color: e.value >= 1
                      ? AppColors.success
                      : (e.value >= 0.6 ? AppColors.warning : AppColors.danger),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VolumeCard extends StatelessWidget {
  const _VolumeCard(this.l);
  final TrainingLoadSummary l;

  @override
  Widget build(BuildContext context) {
    const groups = [
      MuscleGroup.chest,
      MuscleGroup.back,
      MuscleGroup.shoulders,
      MuscleGroup.arms,
      MuscleGroup.legs,
      MuscleGroup.glutes,
      MuscleGroup.core,
    ];
    if (l.weeklySetsByMuscle.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: DepthCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Weekly sets per muscle', style: AppText.title),
            Text('Target ≥ 10 hard sets / muscle / week (Schoenfeld 2017)', style: AppText.caption),
            const SizedBox(height: 12),
            for (final g in groups)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: MacroBar(
                  label: g.label,
                  value: (l.weeklySetsByMuscle[g] ?? 0).toDouble(),
                  target: TrainingLoadCalculator.minWeeklySets.toDouble(),
                  color: AppColors.primary,
                  unit: 'sets',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TomorrowCard extends StatelessWidget {
  const _TomorrowCard(this.t);
  final TrainingRecommendation t;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: DepthCard(
        style: DepthStyle.primary,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "NOVA'S PLAN FOR TOMORROW",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
                letterSpacing: 1,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              t.headline,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(t.detail, style: const TextStyle(color: Colors.white, height: 1.4)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: [
                Pill('RPE ${t.rpeRange}', color: Colors.white),
                Pill('~${t.durationMin} min', color: Colors.white),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Icon shown for each [WorkoutType].
IconData workoutIcon(WorkoutType t) => switch (t) {
  WorkoutType.strength => Icons.fitness_center_rounded,
  WorkoutType.cardio => Icons.directions_bike_rounded,
  WorkoutType.hiit => Icons.bolt_rounded,
  WorkoutType.sport => Icons.sports_tennis_rounded,
  WorkoutType.mobility => Icons.self_improvement_rounded,
  WorkoutType.walk => Icons.directions_walk_rounded,
  WorkoutType.run => Icons.directions_run_rounded,
};

class _History extends StatelessWidget {
  const _History();

  @override
  Widget build(BuildContext context) {
    final sessions = context.select((WorkoutBloc b) => b.state.sessions);
    final kg = context.select((ProfileBloc b) => b.state.profile?.weightKg) ?? 70;
    if (sessions.isEmpty) {
      return EmptyState(
        icon: Icons.fitness_center_rounded,
        title: 'No workouts yet',
        message: 'Log a gym session, or connect ${HealthBrand.app} to import runs & walks.',
      );
    }
    return Column(
      children: [
        for (final s in sessions.take(30))
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Dismissible(
              key: ValueKey(s.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Icon(Icons.delete_rounded, color: AppColors.danger),
              ),
              onDismissed: (_) => context.read<WorkoutBloc>().add(WorkoutDeleted(s.id)),
              child: DepthCard(
                padding: const EdgeInsets.all(14),
                onTap: s.source == DataSource.manual
                    ? () => Navigator.of(
                        context,
                      ).push(MaterialPageRoute(builder: (_) => WorkoutEditorPage(initial: s)))
                    : null,
                child: Row(
                  children: [
                    IconBadge(icon: workoutIcon(s.type), color: AppColors.primary, onDark: false),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                          Text(
                            '${DateKeys.friendly(s.start)} · ${s.durationMin} min · RPE ${s.rpe}'
                            '${s.sets.isNotEmpty ? ' · ${s.sets.length} sets · ${fmtInt(s.volume)} kg vol' : ''}',
                            style: AppText.caption,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${fmtInt(EnergyCalculator.workoutKcal(s, weightKg: kg))} kcal',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text('load ${fmtInt(s.load)}', style: AppText.caption),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
