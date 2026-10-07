import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;

import '../../features/activity/data/activity_repository_impl.dart';
import '../../features/activity/domain/entities/daily_activity.dart';
import '../../features/activity/domain/repositories/activity_repository.dart';
import '../../features/health_sync/data/health_connect_source.dart';
import '../../features/health_sync/data/health_sync_repository_impl.dart';
import '../../features/health_sync/domain/health_sync_repository.dart';
import '../../features/insights/domain/usecases/build_health_snapshot.dart';
import '../../features/hevy/data/hevy_client.dart';
import '../../features/hevy/data/hevy_sync.dart';
import '../../features/insights/domain/usecases/generate_briefing.dart';
import '../../features/progress/domain/get_progress.dart';
import '../../features/nutrition/data/datasources/gemini_nutrition_client.dart';
import '../../features/nutrition/data/datasources/nutrition_cache.dart';
import '../../features/nutrition/data/nutrition_mappers.dart';
import '../../features/nutrition/data/repositories/nutrition_pipeline.dart';
import '../../features/nutrition/data/repositories/nutrition_repository_impl.dart';
import '../../features/nutrition/data/sync/sync_coordinator.dart';
import '../../features/nutrition/data/sync/sync_queue.dart';
import '../../features/nutrition/domain/entities/food_item.dart';
import '../../features/nutrition/domain/entities/food_log_entry.dart';
import '../../features/nutrition/domain/entities/recipe.dart';
import '../../features/nutrition/domain/repositories/nutrition_repository.dart';
import '../../features/nutrition/domain/usecases/log_food.dart';
import '../../features/profile/data/profile_mappers.dart';
import '../../features/profile/data/profile_repository_impl.dart';
import '../../features/profile/domain/entities/user_profile.dart';
import '../../features/profile/domain/entities/weight_entry.dart';
import '../../features/profile/domain/repositories/profile_repository.dart';
import '../../features/sleep/data/sleep_repository_impl.dart';
import '../../features/sleep/domain/entities/sleep_session.dart';
import '../../features/sleep/domain/repositories/sleep_repository.dart';
import '../../features/transformation/data/plan_codec.dart';
import '../../features/transformation/data/transformation_repository_impl.dart';
import '../../features/transformation/domain/entities/transformation_plan.dart';
import '../../features/transformation/domain/repositories/transformation_repository.dart';
import '../../features/transformation/domain/usecases/toggle_plan_item.dart';
import '../../features/workout/data/workout_repository_impl.dart';
import '../../features/workout/domain/entities/exercise.dart';
import '../../features/workout/domain/entities/workout_session.dart';
import '../../features/workout/domain/repositories/workout_repository.dart';
import '../network/connectivity_service.dart';
import '../storage/hive_boxes.dart';
import '../storage/hive_store.dart';
import '../storage/settings_store.dart';

/// Global service locator. Pages obtain dependencies via `sl<T>()` only
/// when creating BLoCs; widgets themselves never reach into it.
final GetIt sl = GetIt.instance;

/// Registers every dependency. Hive boxes must already be open
/// ([HiveBoxes.init] or [HiveBoxes.openAll]).
///
/// Override points for tests: pass a fake [connectivity], [httpClient] or
/// [healthSource]; widget tests set [engineInIsolate] to false because
/// isolates cannot complete inside Flutter's fake-async test zone.
Future<void> configureDependencies({
  ConnectivityService? connectivity,
  http.Client? httpClient,
  HealthConnectSource? healthSource,
  bool engineInIsolate = true,
}) async {
  await sl.reset();

  // ── Core ──────────────────────────────────────────────────────────
  final settings = SettingsStore(HiveBoxes.box(HiveBoxes.settings));
  sl.registerSingleton<SettingsStore>(settings);
  sl.registerSingleton<ConnectivityService>(connectivity ?? ConnectivityPlusService());
  sl.registerSingleton<http.Client>(httpClient ?? http.Client());

  // ── Repositories ─────────────────────────────────────────────────
  sl.registerSingleton<ProfileRepository>(
    ProfileRepositoryImpl(
      profileStore: HiveStore<UserProfile>(
        HiveBoxes.box(HiveBoxes.profile),
        toMap: UserProfileMapper.toMap,
        fromMap: UserProfileMapper.fromMap,
      ),
      weightStore: HiveStore<WeightEntry>(
        HiveBoxes.box(HiveBoxes.weights),
        toMap: WeightEntryMapper.toMap,
        fromMap: WeightEntryMapper.fromMap,
      ),
    ),
  );

  final nutrition = NutritionRepositoryImpl(
    log: HiveStore<FoodLogEntry>(
      HiveBoxes.box(HiveBoxes.foodLog),
      toMap: FoodLogEntryMapper.toMap,
      fromMap: FoodLogEntryMapper.fromMap,
    ),
    customFoods: HiveStore<FoodItem>(
      HiveBoxes.box(HiveBoxes.customFoods),
      toMap: FoodItemMapper.toMap,
      fromMap: FoodItemMapper.fromMap,
    ),
    recipes: HiveStore<Recipe>(
      HiveBoxes.box(HiveBoxes.recipes),
      toMap: RecipeMapper.toMap,
      fromMap: RecipeMapper.fromMap,
    ),
    water: HiveStore<int>(
      HiveBoxes.box(HiveBoxes.water),
      toMap: (v) => {'ml': v},
      fromMap: (m) => (m['ml'] as num).toInt(),
    ),
  );
  sl.registerSingleton<NutritionRepository>(nutrition);

  sl.registerSingleton<ActivityRepository>(
    ActivityRepositoryImpl(
      HiveStore<DailyActivity>(
        HiveBoxes.box(HiveBoxes.activity),
        toMap: DailyActivityMapper.toMap,
        fromMap: DailyActivityMapper.fromMap,
      ),
    ),
  );
  sl.registerSingleton<WorkoutRepository>(
    WorkoutRepositoryImpl(
      HiveStore<WorkoutSession>(
        HiveBoxes.box(HiveBoxes.workouts),
        toMap: WorkoutSessionMapper.toMap,
        fromMap: WorkoutSessionMapper.fromMap,
      ),
      HiveStore<Exercise>(
        HiveBoxes.box(HiveBoxes.customExercises),
        toMap: ExerciseMapper.toMap,
        fromMap: ExerciseMapper.fromMap,
      ),
    ),
  );
  sl.registerSingleton<SleepRepository>(
    SleepRepositoryImpl(
      HiveStore<SleepSession>(
        HiveBoxes.box(HiveBoxes.sleep),
        toMap: SleepSessionMapper.toMap,
        fromMap: SleepSessionMapper.fromMap,
      ),
    ),
  );

  // ── Nutrition pipeline + offline queue ─────────────────────────────
  final gemini = GeminiNutritionClient(
    httpClient: sl<http.Client>(),
    apiKey: () => settings.geminiApiKey,
    model: () => settings.geminiModel,
  );
  final pipeline = NutritionPipeline(
    cache: NutritionCache(
      HiveStore<CachedAnalysis>(
        HiveBoxes.box(HiveBoxes.nutritionCache),
        toMap: CachedAnalysis.toMap,
        fromMap: CachedAnalysis.fromMap,
      ),
    ),
    gemini: gemini,
    connectivity: sl<ConnectivityService>(),
    settings: settings,
    foods: nutrition.allFoods,
  );
  sl.registerSingleton<NutritionAnalysisRepository>(pipeline);

  final queue = SyncQueue(
    HiveStore<PendingJob>(
      HiveBoxes.box(HiveBoxes.syncQueue),
      toMap: PendingJob.toMap,
      fromMap: PendingJob.fromMap,
    ),
  );
  sl.registerSingleton<SyncQueue>(queue);
  sl.registerSingleton<SyncCoordinator>(
    SyncCoordinator(
      queue: queue,
      analyzer: pipeline,
      nutrition: nutrition,
      connectivity: sl<ConnectivityService>(),
      settings: settings,
    ),
  );

  sl.registerSingleton<LogFood>(
    LogFood(
      nutrition,
      enqueue: (jobId, text, entryId) =>
          queue.enqueue(PendingJob(id: jobId, text: text, entryId: entryId, createdAt: DateTime.now())),
    ),
  );

  // ── Health Connect ─────────────────────────────────────────────────
  sl.registerSingleton<HealthSyncRepository>(
    HealthSyncRepositoryImpl(
      source: healthSource ?? HealthConnectSource(wasAuthorized: () => settings.healthConnected),
      activity: sl<ActivityRepository>(),
      sleep: sl<SleepRepository>(),
      workouts: sl<WorkoutRepository>(),
      profile: sl<ProfileRepository>(),
      settings: settings,
    ),
  );

  // ── Transformation ──────────────────────────────────────────────────
  final transformation = TransformationRepositoryImpl(
    HiveStore<TransformationPlan>(
      HiveBoxes.box(HiveBoxes.transformation),
      toMap: PlanCodec.toMap,
      fromMap: PlanCodec.fromMap,
    ),
    HiveBoxes.box(HiveBoxes.planChecks),
    settings,
  );
  sl.registerSingleton<TransformationRepository>(transformation);
  sl.registerSingleton<TogglePlanItem>(
    TogglePlanItem(
      plans: transformation,
      nutrition: nutrition,
      workouts: sl<WorkoutRepository>(),
      sleep: sl<SleepRepository>(),
    ),
  );

  // ── Hevy ──────────────────────────────────────────────────────────
  sl.registerSingleton<HevySync>(
    HevySync(
      client: HevyClient(sl<http.Client>()),
      settings: settings,
      workouts: sl<WorkoutRepository>(),
      plans: transformation,
    ),
  );

  // ── Insights ───────────────────────────────────────────────────────
  final snapshot = BuildHealthSnapshot(
    transformation: transformation,
    profile: sl<ProfileRepository>(),
    nutrition: nutrition,
    activity: sl<ActivityRepository>(),
    workouts: sl<WorkoutRepository>(),
    sleep: sl<SleepRepository>(),
  );
  sl.registerSingleton<BuildHealthSnapshot>(snapshot);
  sl.registerSingleton<GenerateBriefing>(GenerateBriefing(snapshot, useIsolate: engineInIsolate));
  sl.registerSingleton<GetProgress>(GetProgress(snapshot, useIsolate: engineInIsolate));
}
