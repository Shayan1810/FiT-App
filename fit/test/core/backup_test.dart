import 'package:fit/core/di/injector.dart';
import 'package:fit/core/dev/demo_transformation.dart';
import 'package:fit/core/storage/backup_service.dart';
import 'package:fit/features/nutrition/domain/repositories/nutrition_repository.dart';
import 'package:fit/features/profile/domain/repositories/profile_repository.dart';
import 'package:fit/features/transformation/domain/repositories/transformation_repository.dart';
import 'package:fit/features/workout/domain/repositories/workout_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_env.dart';
import '../insights/insight_engine_test.dart' show seed;

void main() {
  setUp(() => setUpTestEnv());
  tearDown(tearDownTestEnv);

  test('backup → wipe → restore brings every record back', () async {
    await seed();
    await DemoTransformation.seed(sl<TransformationRepository>());
    final profile = sl<ProfileRepository>().getProfile();
    final workouts = sl<WorkoutRepository>().sessions().length;
    final foods = sl<NutritionRepository>().customFoods().length;
    final plan = sl<TransformationRepository>().activePlan();

    final service = BackupService();
    final text = service.export();
    expect(text, startsWith(BackupService.prefix));
    expect(service.inspect(text)['fit_workouts'], workouts);

    // A damaged backup is rejected before anything is changed.
    await expectLater(service.restore('${BackupService.prefix}not-base64!'), throwsFormatException);
    expect(sl<WorkoutRepository>().sessions(), hasLength(workouts));
    expect(() => service.inspect('hello'), throwsFormatException);

    // Wipe by restoring an empty-ish state, then the real backup.
    final empty = BackupService(boxes: const []);
    expect(empty.export(), startsWith(BackupService.prefix));
    for (final w in sl<WorkoutRepository>().sessions()) {
      await sl<WorkoutRepository>().delete(w.id);
    }
    expect(sl<WorkoutRepository>().sessions(), isEmpty);

    await service.restore(text);
    expect(sl<WorkoutRepository>().sessions(), hasLength(workouts));
    expect(sl<NutritionRepository>().customFoods(), hasLength(foods));
    expect(sl<ProfileRepository>().getProfile(), profile);
    expect(sl<TransformationRepository>().activePlan(), plan);
    expect(sl<TransformationRepository>().mode, AppMode.transformation);
  });
}
