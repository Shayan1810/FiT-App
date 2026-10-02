import 'dart:io';

import 'package:flutter/services.dart';

import 'package:fit/core/di/injector.dart';
import 'package:fit/core/network/connectivity_service.dart';
import 'package:fit/core/storage/hive_boxes.dart';
import 'package:hive_ce/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Initialises Hive with in-memory boxes and registers all dependencies
/// with fakes (offline-capable connectivity, scripted HTTP).
Future<FakeConnectivityService> setUpTestEnv({
  bool online = true,
  http.Client? httpClient,
  bool engineInIsolate = true,
}) async {
  final dir = await Directory.systemTemp.createTemp('fit_test_');
  Hive.init(dir.path);
  await HiveBoxes.openAllInMemory();
  final connectivity = FakeConnectivityService(online: online);
  await configureDependencies(
    connectivity: connectivity,
    httpClient: httpClient ?? MockClient((_) async => http.Response('{}', 500)),
    engineInIsolate: engineInIsolate,
  );
  return connectivity;
}

/// Closes Hive after a test file.
Future<void> tearDownTestEnv() async {
  await Hive.close();
}

/// Loads Poppins and Material Icons so widget tests and screenshots render
/// real glyphs (by default tests use the square "Ahem" font).
Future<void> loadAppFonts() async {
  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    for (final p in paths) {
      final f = File(p);
      if (f.existsSync()) loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    }
    await loader.load();
  }

  await load('Poppins', [
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) 'fonts/Poppins-$w.ttf',
  ]);
  final exe = Platform.resolvedExecutable;
  final root =
      Platform.environment['FLUTTER_ROOT'] ??
      (exe.contains('/bin/cache/') ? exe.substring(0, exe.indexOf('/bin/cache/')) : '');
  await load('MaterialIcons', ['$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
}
