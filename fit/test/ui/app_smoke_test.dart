import 'package:fit/app.dart';
import 'package:fit/core/dev/demo_transformation.dart';
import 'package:fit/core/di/injector.dart';
import 'package:fit/core/utils/date_utils.dart';
import 'package:fit/core/widgets/nav_bar_3d.dart';
import 'package:fit/features/transformation/domain/repositories/transformation_repository.dart';
import 'package:fit/features/coach/presentation/coach_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_env.dart';
import '../insights/insight_engine_test.dart' show seed;

/// Pumps frames for [ms] milliseconds (pumpAndSettle can't be used: the
/// ambient 3D animation loops forever by design).
Future<void> settle(WidgetTester t, [int ms = 1500]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Finder navIcon(IconData icon) => find.descendant(of: find.byType(NavBar3D), matching: find.byIcon(icon));

void main() {
  setUpAll(loadAppFonts);

  void phone(WidgetTester t) {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.625; // ≈ 411 × 891 dp (typical Android)
    addTearDown(t.view.reset);
  }

  testWidgets('first launch shows onboarding and finishes into the app', (t) async {
    phone(t);
    await t.runAsync(() => setUpTestEnv(engineInIsolate: false));
    await t.pumpWidget(const FitApp());
    await settle(t);
    expect(find.text("Hi, I'm Nebula."), findsOneWidget);

    await t.tap(find.text("Let's start"));
    await settle(t, 800);
    await t.enterText(find.byType(TextField).first, 'Alex');
    await t.pump();
    await t.tap(find.text('Next'));
    await settle(t, 800);
    await t.tap(find.text('Next'));
    await settle(t, 800);
    await t.tap(find.text('Lose fat'));
    await t.pump();
    await t.tap(find.text('Finish'));
    await settle(t, 2500);

    expect(find.text('Hi, Alex'), findsOneWidget);
    expect(find.text('Calories IN'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await settle(t, 500);
    await t.runAsync(tearDownTestEnv);
  });

  testWidgets('every tab and page renders with 3 weeks of data (no overflow)', (t) async {
    phone(t);
    await t.runAsync(() async {
      await setUpTestEnv(engineInIsolate: false);
      await seed();
    });
    await t.pumpWidget(const FitApp());
    await settle(t, 2500);

    // Today
    expect(find.text('Calories OUT'), findsOneWidget);
    expect(find.text('Macronutrients'), findsOneWidget);
    final flip = find.byIcon(Icons.local_fire_department_rounded).last;
    await t.ensureVisible(flip);
    await settle(t, 300);
    await t.tap(flip); // flip card
    await settle(t, 900);
    expect(find.text('Energy burned'), findsOneWidget);
    await t.drag(find.byType(CustomScrollView).first, const Offset(0, -1500));
    await settle(t);

    // Food
    await t.tap(navIcon(Icons.restaurant_rounded));
    await settle(t);
    expect(find.text('Breakfast'), findsOneWidget);
    await t.enterText(find.byType(TextField).first, '2 roti, dal and a banana');
    await t.pump();
    final analyse = find.byIcon(Icons.auto_awesome_rounded).first;
    await t.ensureVisible(analyse);
    await t.tap(analyse);
    await settle(t, 1500);
    expect(find.text('From My foods (offline)'), findsOneWidget);
    await t.tap(find.textContaining('Log to'));
    await settle(t, 1000);
    await t.drag(find.byType(CustomScrollView).first, const Offset(0, -2000));
    await settle(t);

    // Train
    await t.tap(navIcon(Icons.fitness_center_rounded));
    await settle(t);
    expect(find.text('Training load'), findsOneWidget);
    await t.drag(find.byType(CustomScrollView).first, const Offset(0, -2500));
    await settle(t);

    // Sleep
    await t.tap(navIcon(Icons.nightlight_round));
    await settle(t);
    expect(find.text('Last night'), findsOneWidget);
    await t.drag(find.byType(CustomScrollView).first, const Offset(0, -2000));
    await settle(t);

    // Progress: every category, an exercise curve and the heat-map.
    await t.tap(navIcon(Icons.insights_rounded));
    await settle(t, 2500);
    expect(find.text('Progress'), findsWidgets);
    expect(find.text('Calories eaten'), findsOneWidget);
    for (final c in ['Body', 'Activity', 'Sleep', 'Training', 'Recovery']) {
      await t.tap(find.widgetWithText(ChoiceChip, c));
      await settle(t, 1000);
      await t.drag(find.byType(CustomScrollView).first, const Offset(0, -2500));
      await settle(t, 500);
      await t.drag(find.byType(CustomScrollView).first, const Offset(0, 5000));
      await settle(t, 500);
    }
    expect(find.text('Strength by exercise'), findsNothing); // on Recovery now
    await t.tap(find.widgetWithText(ChoiceChip, 'Training'));
    await settle(t, 1000);
    expect(find.text('Strength by exercise'), findsOneWidget);
    expect(find.text('Sets per muscle per week'), findsOneWidget);
    await t.tap(find.text('1 Y'));
    await settle(t, 2500);
    expect(find.text('Strength by exercise'), findsOneWidget);

    // Coach
    await t.tap(navIcon(Icons.auto_awesome_rounded));
    await settle(t, 2500);
    expect(find.text("Tomorrow's plan"), findsOneWidget);
    await t.scrollUntilVisible(
      find.byType(PageView),
      300,
      scrollable: find.descendant(of: find.byType(CoachPage), matching: find.byType(Scrollable)).first,
    );
    await settle(t, 300);
    await t.drag(find.byType(PageView).first, const Offset(-300, 0));
    await settle(t);
    await t.drag(find.byType(CustomScrollView).first, const Offset(0, -3000));
    await settle(t);

    // Workout editor
    await t.tap(navIcon(Icons.fitness_center_rounded));
    await settle(t);
    await t.tap(find.text('Log workout'));
    await settle(t);
    expect(find.text('Add exercise'), findsOneWidget);
    await t.pageBack();
    await settle(t);

    // Profile & settings
    await t.tap(navIcon(Icons.dashboard_rounded));
    await settle(t);
    await t.drag(find.byType(CustomScrollView).first, const Offset(0, 3000));
    await settle(t);
    await t.tap(find.byTooltip('Settings'));
    await settle(t);
    expect(find.text('Samsung Health'), findsOneWidget);
    final settingsScroll = find
        .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
        .first;
    await t.scrollUntilVisible(find.text('Diagnostics'), 300, scrollable: settingsScroll);
    await settle(t, 500);
    expect(find.text('Diagnostics'), findsOneWidget);
    // Switch to dark mode and back: every page must survive the palette swap.
    await t.scrollUntilVisible(find.text('Appearance'), -300, scrollable: settingsScroll);
    await t.tap(find.text('Dark'));
    await settle(t, 800);
    expect(Theme.of(t.element(find.text('Appearance'))).brightness, Brightness.dark);
    await t.tap(find.text('Light'));
    await settle(t, 800);
    await t.pageBack();
    await settle(t);
    await t.tap(find.byType(CircleAvatar).first);
    await settle(t);
    await t.drag(find.text('About you'), const Offset(0, -1200));
    await settle(t, 600);
    expect(find.text('Weight trend'), findsWidgets);

    await t.pumpWidget(const SizedBox());
    await settle(t, 500);
    await t.runAsync(tearDownTestEnv);
  });

  testWidgets('Transformation mode opens on the plan and its checklist works', (t) async {
    phone(t);
    await t.runAsync(() async {
      await setUpTestEnv(engineInIsolate: false);
      await seed();
      await DemoTransformation.seed(sl<TransformationRepository>());
    });
    await t.pumpWidget(const FitApp());
    await settle(t, 2500);

    // Opens on the plan, not the General dashboard.
    expect(find.text('Summer Cut'), findsWidgets);
    expect(find.textContaining('Day 18 of 84'), findsOneWidget);
    expect(find.textContaining('fat lost'), findsWidgets);
    expect(navIcon(Icons.flag_rounded), findsOneWidget);

    // Tick a planned item.
    final scroll = find.byType(CustomScrollView).first;
    await t.scrollUntilVisible(
      find.text('Afternoon'),
      300,
      scrollable: find.descendant(of: scroll, matching: find.byType(Scrollable)).first,
    );
    await settle(t, 600);
    final lunch = find.bySemanticsLabel('Lunch done');
    expect(lunch, findsOneWidget);
    await t.tap(lunch);
    await settle(t, 1200);
    expect(sl<TransformationRepository>().checksFor(DateKeys.of(DateTime.now())), contains('m_lunch'));
    await t.drag(scroll, const Offset(0, -3000));
    await settle(t, 600);
    await t.drag(scroll, const Offset(0, 5000));
    await settle(t, 600);

    // Plan editor walks through every step.
    await t.tap(find.byTooltip('Edit plan'));
    await settle(t);
    for (var k = 0; k < 8; k++) {
      expect(find.textContaining('Step ${k + 1} of 9'), findsOneWidget);
      await t.tap(find.text('Next'));
      await settle(t, 500);
    }
    expect(find.text('Save plan'), findsOneWidget);
    await t.pageBack();
    await settle(t);

    // Progress shows the plan period.
    await t.tap(navIcon(Icons.insights_rounded));
    await settle(t, 2500);
    expect(find.text('Plan'), findsWidgets);
    expect(
      find.text('Fat lost (from deficit)').evaluate().isNotEmpty ||
          find.text('Mass gained (from surplus)').evaluate().isNotEmpty,
      isTrue,
    );

    // Settings → General mode brings back the dashboard with a Resume card.
    await t.tap(navIcon(Icons.flag_rounded));
    await settle(t);
    await t.tap(find.byTooltip('Full dashboard'));
    await settle(t);
    await t.drag(find.byType(CustomScrollView).last, const Offset(0, 3000));
    await settle(t, 600);
    await t.tap(find.byTooltip('Settings').last);
    await settle(t);
    await t.tap(find.text('General'));
    await settle(t, 1500);
    expect(sl<TransformationRepository>().mode, AppMode.general);
    await t.pageBack();
    await settle(t);
    await t.pageBack();
    await settle(t, 1500);
    expect(find.text('Resume Summer Cut'), findsOneWidget);
    expect(navIcon(Icons.dashboard_rounded), findsOneWidget);

    await t.pumpWidget(const SizedBox());
    await settle(t, 500);
    await t.runAsync(tearDownTestEnv);
  });

  testWidgets('a plan starting tomorrow shows a countdown and a day-1 preview', (t) async {
    phone(t);
    await t.runAsync(() async {
      await setUpTestEnv(engineInIsolate: false);
      await seed();
      final repo = sl<TransformationRepository>();
      final plan = DemoTransformation.plan(DateKeys.startOfDay(DateTime.now()).add(const Duration(days: 1)));
      await repo.savePlan(plan);
      await repo.setMode(AppMode.transformation);
    });
    await t.pumpWidget(const FitApp());
    await settle(t, 2500);
    expect(find.textContaining('Starts '), findsOneWidget);
    expect(find.text('to start'), findsOneWidget);
    expect(find.textContaining('Day 1 ·'), findsOneWidget);
    await t.drag(find.byType(CustomScrollView).first, const Offset(0, -3000));
    await settle(t, 800);
    await t.pumpWidget(const SizedBox());
    await settle(t, 500);
    await t.runAsync(tearDownTestEnv);
  });
}
