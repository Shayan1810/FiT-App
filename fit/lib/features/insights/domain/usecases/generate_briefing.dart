import 'dart:isolate';

import '../engine/insight_engine.dart';
import '../entities/daily_briefing.dart';
import 'build_health_snapshot.dart';

/// Use case: snapshot (UI isolate, ~ms) → engine (background isolate).
///
/// Running the engine via [Isolate.run] guarantees zero dropped frames even as
/// history grows. Tests can pass `useIsolate: false` to run inline.
class GenerateBriefing {
  GenerateBriefing(this._buildSnapshot, {this.useIsolate = true});

  final BuildHealthSnapshot _buildSnapshot;
  final bool useIsolate;

  /// Returns null before onboarding.
  Future<DailyBriefing?> call([DateTime? at]) async {
    final snapshot = _buildSnapshot(at);
    if (snapshot == null) return null;
    if (!useIsolate) return InsightEngine.generate(snapshot);
    return Isolate.run(() => InsightEngine.generate(snapshot), debugName: 'InsightEngine');
  }
}
