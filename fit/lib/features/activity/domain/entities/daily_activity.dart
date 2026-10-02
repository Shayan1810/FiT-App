import 'package:equatable/equatable.dart';

import '../../../../core/domain/data_source.dart';

/// Steps / walking / running summary for one day.
///
/// Filled from Health Connect (where Samsung Health writes its pedometer
/// data) or typed in manually.
class DailyActivity extends Equatable {
  const DailyActivity({
    required this.dayKey,
    required this.steps,
    this.distanceKm,
    this.activeKcal,
    this.restingHr,
    this.source = DataSource.manual,
    this.syncedAt,
  });

  final String dayKey;
  final int steps;

  /// Measured distance; null → estimated from steps × stride length.
  final double? distanceKm;

  /// Device-measured active energy (already excludes BMR); may be null.
  final double? activeKcal;

  /// Resting heart rate (bpm) for the day, if a wearable provided it.
  final double? restingHr;
  final DataSource source;
  final DateTime? syncedAt;

  DailyActivity copyWith({
    int? steps,
    double? distanceKm,
    double? activeKcal,
    double? restingHr,
    DataSource? source,
    DateTime? syncedAt,
  }) {
    return DailyActivity(
      dayKey: dayKey,
      steps: steps ?? this.steps,
      distanceKm: distanceKm ?? this.distanceKm,
      activeKcal: activeKcal ?? this.activeKcal,
      restingHr: restingHr ?? this.restingHr,
      source: source ?? this.source,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  @override
  List<Object?> get props => [dayKey, steps, distanceKm, activeKcal, restingHr, source, syncedAt];
}
