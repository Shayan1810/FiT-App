import 'dart:isolate';

import '../../insights/domain/usecases/build_health_snapshot.dart';
import 'progress_calculator.dart';

/// Use case: long snapshot (UI isolate) → [ProgressCalculator] (background).
class GetProgress {
  GetProgress(this._buildSnapshot, {this.useIsolate = true});

  final BuildHealthSnapshot _buildSnapshot;
  final bool useIsolate;

  /// Report for the last [days] days; null before onboarding.
  Future<ProgressReport?> call(int days, [DateTime? at]) async {
    final snapshot = _buildSnapshot(at, days);
    if (snapshot == null) return null;
    if (!useIsolate) return ProgressCalculator.compute(snapshot);
    return Isolate.run(() => ProgressCalculator.compute(snapshot), debugName: 'Progress');
  }
}
