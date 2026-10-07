import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injector.dart';
import '../../core/widgets/nav_bar_3d.dart';
import '../activity/presentation/bloc/activity_cubit.dart';
import '../coach/presentation/coach_page.dart';
import '../dashboard/presentation/today_page.dart';
import '../health_sync/domain/health_sync_repository.dart';
import '../hevy/data/hevy_sync.dart';
import '../insights/presentation/bloc/insights_bloc.dart';
import '../nutrition/data/sync/sync_coordinator.dart';
import '../nutrition/presentation/pages/nutrition_page.dart';
import '../progress/presentation/progress_page.dart';
import '../sleep/presentation/sleep_page.dart';
import '../transformation/presentation/transformation_cubit.dart';
import '../transformation/presentation/transformation_page.dart';
import '../workout/presentation/pages/train_page.dart';

/// Tab indices of the shell. In Transformation mode tab 0 is the plan.
class AppTab {
  AppTab._();
  static const int today = 0, food = 1, train = 2, sleep = 3, progress = 4, coach = 5;
}

/// The main 6-tab layout with the floating 3D nav bar.
///
/// Tabs live in an [IndexedStack] (state & scroll positions are kept); the
/// newly selected tab swings in with a short 3D "page turn".
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  /// Switches tab from anywhere below the shell.
  static void goTo(BuildContext context, int tab) =>
      context.findAncestorStateOfType<_MainShellState>()?._select(tab);

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _index = 0;
  int _previous = 0;

  static const _todayItem = NavItem(Icons.dashboard_rounded, 'Today');
  static const _planItem = NavItem(Icons.flag_rounded, 'Plan');

  static const _items = [
    _todayItem,
    NavItem(Icons.restaurant_rounded, 'Food'),
    NavItem(Icons.fitness_center_rounded, 'Train'),
    NavItem(Icons.nightlight_round, 'Sleep'),
    NavItem(Icons.insights_rounded, 'Progress'),
    NavItem(Icons.auto_awesome_rounded, 'Coach'),
  ];

  static const _pages = [TodayPage(), NutritionPage(), TrainPage(), SleepPage(), ProgressPage(), CoachPage()];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncHevy();
  }

  /// Pulls new Hevy workouts quietly (only when connected).
  void _syncHevy() {
    final hevy = sl<HevySync>();
    if (hevy.configured) hevy.sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// On resume: new day? new steps? back online? → refresh everything.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    context.read<InsightsBloc>().add(const InsightsRefreshRequested());
    final activity = context.read<ActivityCubit>();
    if (activity.state.link == HealthLinkStatus.connected) activity.sync(quiet: true);
    sl<SyncCoordinator>().drain();
    _syncHevy();
  }

  void _select(int i) {
    if (i == _index) return;
    setState(() {
      _previous = _index;
      _index = i;
    });
  }

  @override
  Widget build(BuildContext context) {
    final forward = _index >= _previous;
    // Transformation mode replaces the Today tab with the plan.
    final planMode = context.select((TransformationCubit c) => c.state.isActive(DateTime.now()));
    final pages = [planMode ? const TransformationPage() : const TodayPage(), ..._pages.skip(1)];
    final items = [planMode ? _planItem : _todayItem, ..._items.skip(1)];
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: [
          for (var i = 0; i < pages.length; i++)
            TickerMode(
              enabled: i == _index,
              child: _TabTurn(
                key: i == 0 ? ValueKey(planMode) : null,
                active: i == _index,
                forward: forward,
                child: pages[i],
              ),
            ),
        ],
      ),
      bottomNavigationBar: NavBar3D(items: items, index: _index, onChanged: _select),
    );
  }
}

/// Short 3D swing-in played whenever a tab becomes active. The wrapper is
/// always present, so the page below keeps its state.
class _TabTurn extends StatefulWidget {
  const _TabTurn({super.key, required this.child, required this.active, required this.forward});
  final Widget child;
  final bool active;
  final bool forward;

  @override
  State<_TabTurn> createState() => _TabTurnState();
}

class _TabTurnState extends State<_TabTurn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
    value: 1,
  );

  @override
  void didUpdateWidget(_TabTurn old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_c.value);
        return Opacity(
          opacity: 0.4 + 0.6 * t,
          child: Transform(
            alignment: widget.forward ? Alignment.centerLeft : Alignment.centerRight,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY((widget.forward ? 1 : -1) * 0.12 * (1 - t)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
