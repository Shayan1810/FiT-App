import '../entities/user_profile.dart';
import '../entities/weight_entry.dart';

/// Contract for reading/writing the user profile and weight history.
abstract class ProfileRepository {
  /// The saved profile, or null before onboarding.
  UserProfile? getProfile();

  /// Saves (creates or replaces) the profile.
  Future<void> saveProfile(UserProfile profile);

  /// All weight entries, oldest first.
  List<WeightEntry> getWeights();

  /// Adds/replaces the weight for that day and updates `profile.weightKg`
  /// when it is the newest entry.
  Future<void> logWeight(WeightEntry entry);

  /// Deletes the weight entry for [dayKey].
  Future<void> deleteWeight(String dayKey);

  /// Emits when the profile or weights change.
  Stream<void> watch();
}
