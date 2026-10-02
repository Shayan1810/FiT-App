import 'package:equatable/equatable.dart';

import '../../../../core/domain/data_source.dart';

export '../../../../core/domain/data_source.dart';

/// One body-weight measurement (at most one per day; later entries replace).
class WeightEntry extends Equatable {
  const WeightEntry({
    required this.dayKey,
    required this.date,
    required this.kg,
    this.bodyFatPct,
    this.source = DataSource.manual,
  });

  /// `yyyy-MM-dd` — also the Hive key.
  final String dayKey;
  final DateTime date;
  final double kg;
  final double? bodyFatPct;
  final DataSource source;

  @override
  List<Object?> get props => [dayKey, date, kg, bodyFatPct, source];
}
