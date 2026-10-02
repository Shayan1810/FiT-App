import 'package:fit/core/di/injector.dart';
import 'package:fit/core/domain/data_source.dart';
import 'package:fit/core/storage/settings_store.dart';
import 'package:fit/core/utils/date_utils.dart';
import 'package:fit/features/activity/domain/entities/daily_activity.dart';
import 'package:fit/features/activity/domain/repositories/activity_repository.dart';
import 'package:fit/features/activity/presentation/bloc/activity_cubit.dart';
import 'package:fit/features/health_sync/domain/health_sync_repository.dart';
import 'package:fit/features/workout/domain/entities/exercise.dart';
import 'package:fit/features/workout/domain/repositories/workout_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_env.dart';

void main() {
  setUp(() => setUpTestEnv());
  tearDown(tearDownTestEnv);

  test('custom exercises are listed first, persist, and can be deleted', () async {
    final repo = sl<WorkoutRepository>();
    final builtIn = repo.exercises().length;
    const mine = Exercise(
      id: 'cx_landmine',
      name: 'Landmine press',
      muscle: MuscleGroup.shoulders,
      equipment: 'Barbell',
      compound: true,
      custom: true,
    );
    final changed = expectLater(repo.watch(), emits(anything));
    await repo.saveExercise(mine);
    await changed;

    final list = repo.exercises();
    expect(list, hasLength(builtIn + 1));
    expect(list.first.id, 'cx_landmine');
    expect(list.first.custom, isTrue);
    expect(list.first.muscle, MuscleGroup.shoulders);

    await repo.deleteExercise('cx_landmine');
    expect(repo.exercises(), hasLength(builtIn));
  });

  test('manual steps override a synced day and keep its heart-rate data', () async {
    final repo = sl<ActivityRepository>();
    final cubit = ActivityCubit(
      repo: repo,
      health: sl<HealthSyncRepository>(),
      settings: sl<SettingsStore>(),
    );
    final day = DateTime.now().subtract(const Duration(days: 2));
    final key = DateKeys.of(day);
    await repo.save(
      DailyActivity(
        dayKey: key,
        steps: 3000,
        activeKcal: 150,
        restingHr: 58,
        source: DataSource.healthConnect,
      ),
    );

    await cubit.setManualSteps(day, 9500, distanceKm: 7.1);
    final edited = cubit.dayRecord(day)!;
    expect(edited.steps, 9500);
    expect(edited.distanceKm, 7.1);
    expect(edited.source, DataSource.manual);
    expect(edited.restingHr, 58);
    expect(edited.activeKcal, 150);

    await cubit.revertToDevice(day);
    expect(cubit.dayRecord(day), isNull);
    await cubit.close();
  });
}
