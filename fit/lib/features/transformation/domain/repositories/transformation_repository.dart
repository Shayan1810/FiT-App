import '../entities/transformation_plan.dart';

/// General mode (the everyday dashboard) or Transformation mode (the plan's
/// daily checklist opens first).
enum AppMode { general, transformation }

/// Stores transformation plans, daily check-ins and the app mode.
abstract class TransformationRepository {
  /// All plans, newest first.
  List<TransformationPlan> plans();

  /// The plan Transformation mode follows (null if none).
  TransformationPlan? activePlan();

  /// Creates or replaces a plan and makes it the active one.
  Future<void> savePlan(TransformationPlan plan);

  /// Deletes a plan and its check-ins.
  Future<void> deletePlan(String id);

  /// Current mode.
  AppMode get mode;

  /// Switches mode.
  Future<void> setMode(AppMode mode);

  /// Ids of the items ticked on [dayKey].
  Set<String> checksFor(String dayKey);

  /// Ticked item ids per day for several days.
  Map<String, Set<String>> checksForDays(Iterable<String> dayKeys);

  /// Marks an item done / not done.
  Future<void> setCheck(String dayKey, String itemId, bool done);

  /// Emits when plans, checks or the mode change.
  Stream<void> watch();

  /// Serialises a plan to shareable JSON (import / export / backup).
  String exportPlan(TransformationPlan plan);

  /// Parses JSON produced by [exportPlan]. Throws [FormatException] if invalid.
  TransformationPlan importPlan(String json);
}
