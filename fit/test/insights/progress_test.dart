import 'package:fit/core/dev/demo_transformation.dart';
import 'package:fit/core/di/injector.dart';
import 'package:fit/features/insights/domain/usecases/build_health_snapshot.dart';
import 'package:fit/features/progress/domain/get_progress.dart';
import 'package:fit/features/progress/domain/progress_calculator.dart';
import 'package:fit/features/transformation/domain/repositories/transformation_repository.dart';
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
      expect(r.of(ProgressCategory.plan), isEmpty); // General mode
      for (final c in ProgressCategory.values.where((c) => c != ProgressCategory.plan)) {
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

  test('Transformation mode adds plan series over the plan period', () async {
    await seed();
    await DemoTransformation.seed(sl<TransformationRepository>(), daysAgo: 12);
    final r = (await GetProgress(sl<BuildHealthSnapshot>(), useIsolate: false)(13))!;
    final plan = r.of(ProgressCategory.plan);
    expect(plan.map((s) => s.id), containsAll(['plan_fat', 'plan_weight', 'plan_adherence', 'plan_skin']));
    final adherence = plan.firstWhere((s) => s.id == 'plan_adherence');
    expect(adherence.values.whereType<double>(), everyElement(inInclusiveRange(0, 100)));
    expect(adherence.count, greaterThanOrEqualTo(12));
    final fat = plan.firstWhere((s) => s.id == 'plan_fat');
    expect(fat.values.first, isNotNull);
  });
}
