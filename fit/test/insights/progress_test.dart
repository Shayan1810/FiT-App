import 'package:fit/core/di/injector.dart';
import 'package:fit/features/insights/domain/usecases/build_health_snapshot.dart';
import 'package:fit/features/progress/domain/get_progress.dart';
import 'package:fit/features/progress/domain/progress_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_env.dart';
import 'insight_engine_test.dart' show seed;

void main() {
  setUp(() => setUpTestEnv());
  tearDown(tearDownTestEnv);

  test('no profile → no report', () async {
    expect(await GetProgress(sl<BuildHealthSnapshot>(), useIsolate: false)(30), isNull);
  });

  test('every category has data and every series is aligned to the range', () async {
    await seed();
    for (final days in [30, 90, 365]) {
      final r = (await GetProgress(sl<BuildHealthSnapshot>(), useIsolate: false)(days))!;
      expect(r.dates, hasLength(days));
      for (final s in r.series) {
        final n = s.id.startsWith('weekly_') ? r.weekStarts.length : days;
        expect(s.values, hasLength(n), reason: s.id);
        if (s.secondary != null) expect(s.secondary, hasLength(n), reason: s.id);
      }
      for (final c in ProgressCategory.values) {
        expect(r.of(c).any((s) => s.count > 0), isTrue, reason: '${c.label} @ $days d');
      }
    }
  });

  test('derived metrics are plausible', () async {
    await seed();
    final r = (await GetProgress(sl<BuildHealthSnapshot>(), useIsolate: false)(30))!;
    MetricSeries s(String id) => r.series.firstWhere((x) => x.id == id);

    final pk = s('protein_kg');
    expect(pk.count, greaterThan(10));
    expect(pk.average, inInclusiveRange(0.5, 3.5));
    expect(s('readiness').values.whereType<double>(), everyElement(inInclusiveRange(0, 100)));
    expect(s('factor').values.whereType<double>(), everyElement(inInclusiveRange(0.4, 1.1)));
    expect(s('sleep').average, inInclusiveRange(4, 11));

    // Per-exercise progress: e1RM ≥ top weight, volume = Σ reps × kg > 0.
    expect(r.exercises, isNotEmpty);
    final e = r.exercises.first;
    expect(e.sessions, greaterThan(1));
    for (var i = 0; i < e.sessions; i++) {
      if (e.e1rm[i] > 0) expect(e.e1rm[i], greaterThanOrEqualTo(e.topWeight[i] - 1e-9));
      expect(e.volume[i], greaterThanOrEqualTo(0));
    }
    expect(r.weeklySets.values.expand((w) => w).fold<int>(0, (a, b) => a + b), greaterThan(0));
  });
}
