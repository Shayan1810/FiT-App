import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/di/injector.dart';
import 'core/storage/hive_boxes.dart';
import 'features/nutrition/data/sync/sync_coordinator.dart';

/// App entry point.
///
/// Order matters: open Hive boxes → register dependencies → start the
/// offline-queue coordinator → draw the first frame. Everything after
/// `runApp` reads from in-memory Hive boxes, so the UI is instant.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  await HiveBoxes.init();
  await configureDependencies();
  sl<SyncCoordinator>().start();
  runApp(const FitApp());
}
