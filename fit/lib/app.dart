import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/di/injector.dart';
import 'core/storage/settings_store.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/palette_scope.dart';
import 'core/utils/streams.dart';
import 'core/widgets/ambient_motion.dart';
import 'core/widgets/nebula_orb.dart';
import 'features/activity/domain/repositories/activity_repository.dart';
import 'features/activity/presentation/bloc/activity_cubit.dart';
import 'features/health_sync/domain/health_sync_repository.dart';
import 'features/insights/domain/usecases/generate_briefing.dart';
import 'features/insights/presentation/bloc/insights_bloc.dart';
import 'features/nutrition/data/sync/sync_coordinator.dart';
import 'features/nutrition/domain/repositories/nutrition_repository.dart';
import 'features/nutrition/domain/usecases/log_food.dart';
import 'features/nutrition/presentation/bloc/nutrition_bloc.dart';
import 'features/onboarding/presentation/onboarding_page.dart';
import 'features/profile/domain/repositories/profile_repository.dart';
import 'features/profile/presentation/bloc/profile_bloc.dart';
import 'features/settings/presentation/settings_cubit.dart';
import 'features/settings/presentation/theme_cubit.dart';
import 'features/shell/main_shell.dart';
import 'features/sleep/domain/repositories/sleep_repository.dart';
import 'features/sleep/presentation/bloc/sleep_bloc.dart';
import 'features/workout/domain/repositories/workout_repository.dart';
import 'features/progress/domain/get_progress.dart';
import 'features/progress/presentation/progress_cubit.dart';
import 'features/transformation/domain/repositories/transformation_repository.dart';
import 'features/transformation/domain/usecases/toggle_plan_item.dart';
import 'features/transformation/presentation/transformation_cubit.dart';
import 'features/workout/presentation/bloc/workout_bloc.dart';

/// Root widget: provides every app-wide BLoC, the theme and the shared
/// ambient animation, then routes to onboarding or the main shell.
class FitApp extends StatelessWidget {
  const FitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              ProfileBloc(sl<ProfileRepository>(), sl<SettingsStore>())..add(const ProfileStarted()),
        ),
        BlocProvider(
          create: (_) => InsightsBloc(
            generate: sl<GenerateBriefing>(),
            changes: mergeChanges([
              sl<ProfileRepository>().watch(),
              sl<NutritionRepository>().watch(),
              sl<ActivityRepository>().watch(),
              sl<WorkoutRepository>().watch(),
              sl<SleepRepository>().watch(),
              sl<TransformationRepository>().watch(),
            ]),
          )..add(const InsightsStarted()),
        ),
        BlocProvider(
          create: (_) => NutritionBloc(
            repo: sl<NutritionRepository>(),
            logFood: sl<LogFood>(),
            sync: sl<SyncCoordinator>(),
          )..add(const NutritionStarted()),
        ),
        BlocProvider(create: (_) => WorkoutBloc(sl<WorkoutRepository>())..add(const WorkoutsStarted())),
        BlocProvider(create: (_) => SleepBloc(sl<SleepRepository>())..add(const SleepStarted())),
        BlocProvider(
          create: (_) => ActivityCubit(
            repo: sl<ActivityRepository>(),
            health: sl<HealthSyncRepository>(),
            settings: sl<SettingsStore>(),
          )..start(),
        ),
        BlocProvider(
          create: (_) => ProgressCubit(
            sl<GetProgress>(),
            mergeChanges([
              sl<ProfileRepository>().watch(),
              sl<NutritionRepository>().watch(),
              sl<ActivityRepository>().watch(),
              sl<WorkoutRepository>().watch(),
              sl<SleepRepository>().watch(),
              sl<TransformationRepository>().watch(),
            ]),
            planDays: () {
              final repo = sl<TransformationRepository>();
              final plan = repo.activePlan();
              final now = DateTime.now();
              if (repo.mode != AppMode.transformation || plan == null || plan.isFinished(now)) return null;
              final n = plan.dayNumber(now);
              return n < 1 ? null : n;
            },
          )..load(),
        ),
        BlocProvider(
          create: (_) => TransformationCubit(
            repo: sl<TransformationRepository>(),
            toggle: sl<TogglePlanItem>(),
            profile: sl<ProfileRepository>(),
          )..start(),
        ),
        BlocProvider(create: (_) => ThemeCubit(sl<SettingsStore>())),
        BlocProvider(create: (_) => SettingsCubit(sl<SettingsStore>(), sl<SyncCoordinator>())..refresh()),
      ],
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, mode) => MaterialApp(
          title: 'FiT',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: mode,
          builder: (context, child) => PaletteScope(child: AmbientMotion(child: child!)),
          home: const RootGate(),
        ),
      ),
    );
  }
}

/// Shows a splash until the profile is read, then onboarding or the shell.
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileBloc, ProfileState>(
      buildWhen: (a, b) => a.loaded != b.loaded || (a.profile == null) != (b.profile == null),
      builder: (context, state) {
        final Widget page;
        if (!state.loaded) {
          page = const _Splash();
        } else if (state.profile == null) {
          page = const OnboardingPage();
        } else {
          page = const MainShell();
        }
        return AnimatedSwitcher(duration: const Duration(milliseconds: 600), child: page);
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: Center(child: NebulaOrb(size: 140)),
  );
}
