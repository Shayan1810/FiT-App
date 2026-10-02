// Renders every main screen with demo data and saves PNGs used by the
// handbook (docs/screenshots). Not part of the normal test suite.
//
//   cd fit && flutter test tool/generate_screenshots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fit/app.dart';
import 'package:fit/core/di/injector.dart';
import 'package:fit/core/storage/settings_store.dart';
import 'package:fit/core/widgets/nav_bar_3d.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/helpers/test_env.dart';
import '../test/insights/insight_engine_test.dart' show seed;

final _key = GlobalKey();
const _out = '../docs/screenshots';

Future<void> _settle(WidgetTester t, [int ms = 1800]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

String _dir = _out;

Future<void> _shot(WidgetTester t, String name) async {
  // Asset images decode asynchronously; load them before capturing.
  await t.runAsync(() async {
    for (final e in find.byType(Image).evaluate()) {
      await precacheImage((e.widget as Image).image, e);
    }
  });
  await t.pump();
  await t.runAsync(() async {
    final boundary = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_dir/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Finder _nav(IconData i) => find.descendant(of: find.byType(NavBar3D), matching: find.byIcon(i));

void main() {
  setUpAll(loadAppFonts);

  void phone(WidgetTester t) {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.625;
    addTearDown(t.view.reset);
  }

  testWidgets('onboarding', (t) async {
    phone(t);
    await t.runAsync(() => setUpTestEnv(engineInIsolate: false));
    await t.pumpWidget(RepaintBoundary(key: _key, child: const FitApp()));
    await _settle(t);
    await _shot(t, '01_onboarding');
    await t.pumpWidget(const SizedBox());
    await _settle(t, 300);
    await t.runAsync(tearDownTestEnv);
  });

  for (final dark in [false, true]) {
    testWidgets('main screens (${dark ? 'dark' : 'light'})', (t) async {
      _dir = dark ? '$_out/dark' : _out;
      await _tour(t, phone, dark);
    });
  }
}

Future<void> _tour(WidgetTester t, void Function(WidgetTester) phone, bool dark) async {
  phone(t);
  await t.runAsync(() async {
    await setUpTestEnv(engineInIsolate: false);
    await seed();
    if (dark) await sl<SettingsStore>().write(SettingsStore.kThemeMode, 'dark');
  });
  await t.pumpWidget(RepaintBoundary(key: _key, child: const FitApp()));
  await _settle(t, 3000);
  await _shot(t, '02_today');
  await t.drag(find.byType(CustomScrollView).first, const Offset(0, -650));
  await _settle(t);
  await _shot(t, '03_today_cards');
  await t.drag(find.byType(CustomScrollView).first, const Offset(0, -700));
  await _settle(t);
  await _shot(t, '04_today_week');

  await t.tap(_nav(Icons.restaurant_rounded));
  await _settle(t);
  await _shot(t, '05_food');
  await t.enterText(find.byType(TextField).first, '2 roti, 1 katori dal and a banana');
  await t.pump();
  await t.tap(find.byIcon(Icons.auto_awesome_rounded).first);
  await _settle(t);
  await _shot(t, '06_food_analysis');
  await t.tapAt(const Offset(200, 60));
  await _settle(t, 800);
  await t.drag(find.byType(CustomScrollView).first, const Offset(0, -600));
  await _settle(t);
  await _shot(t, '07_food_meals');

  await t.tap(_nav(Icons.fitness_center_rounded));
  await _settle(t);
  await _shot(t, '08_train');
  await t.drag(find.byType(CustomScrollView).first, const Offset(0, -750));
  await _settle(t);
  await _shot(t, '09_train_load');

  await t.tap(_nav(Icons.nightlight_round));
  await _settle(t);
  await _shot(t, '10_sleep');

  await t.tap(_nav(Icons.insights_rounded));
  await _settle(t, 3000);
  await _shot(t, '17_progress');
  await t.tap(find.widgetWithText(ChoiceChip, 'Training'));
  await _settle(t, 1500);
  await _shot(t, '18_progress_strength');
  await t.drag(find.byType(CustomScrollView).first, const Offset(0, -700));
  await _settle(t);
  await _shot(t, '19_progress_heatmap');
  await t.drag(find.byType(CustomScrollView).first, const Offset(0, 3000));
  await _settle(t);
  await t.tap(find.widgetWithText(ChoiceChip, 'Recovery'));
  await _settle(t, 1500);
  await _shot(t, '20_progress_recovery');

  await t.tap(_nav(Icons.auto_awesome_rounded));
  await _settle(t, 3000);
  await _shot(t, '11_coach');
  await t.drag(find.byType(CustomScrollView).first, const Offset(0, -700));
  await _settle(t);
  await _shot(t, '12_coach_plan');
  await t.drag(find.byType(CustomScrollView).first, const Offset(0, -650));
  await _settle(t);
  await _shot(t, '13_coach_insights');

  await t.tap(_nav(Icons.fitness_center_rounded));
  await _settle(t, 600);
  await t.tap(find.text('Log workout'));
  await _settle(t);
  await _shot(t, '14_workout_editor');
  await t.pageBack();
  await _settle(t, 600);

  await t.tap(_nav(Icons.dashboard_rounded));
  await _settle(t, 600);
  await t.drag(find.byType(CustomScrollView).first, const Offset(0, 3000));
  await _settle(t, 600);
  await t.tap(find.byType(CircleAvatar).first);
  await _settle(t);
  await _shot(t, '15_profile');
  await t.pageBack();
  await _settle(t, 600);
  await t.tap(find.byTooltip('Settings'));
  await _settle(t);
  await _shot(t, '16_settings');

  await t.pumpWidget(const SizedBox());
  await _settle(t, 300);
  await t.runAsync(tearDownTestEnv);
}
