import 'package:equatable/equatable.dart';

import '../../../../core/domain/data_source.dart';
import '../../../../core/utils/date_utils.dart';

/// One period of sleep (night or nap).
class SleepSession extends Equatable {
  const SleepSession({
    required this.id,
    required this.start,
    required this.end,
    this.quality,
    this.source = DataSource.manual,
  });

  final String id;
  final DateTime start;
  final DateTime end;

  /// Subjective quality 1–5 (null if imported without a rating).
  final int? quality;
  final DataSource source;

  /// Minutes asleep.
  int get minutes => end.difference(start).inMinutes;

  /// The night is attributed to the day you **wake up** on.
  String get wakeDayKey => DateKeys.of(end);

  /// Midpoint of the sleep period (used for regularity).
  DateTime get midpoint => start.add(Duration(minutes: minutes ~/ 2));

  @override
  List<Object?> get props => [id, start, end, quality, source];
}
