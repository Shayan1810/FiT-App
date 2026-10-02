import '../../../core/storage/hive_store.dart';
import '../../../core/utils/streams.dart';
import '../domain/entities/user_profile.dart';
import '../domain/entities/weight_entry.dart';
import '../domain/repositories/profile_repository.dart';

/// Hive-backed [ProfileRepository].
class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl({
    required HiveStore<UserProfile> profileStore,
    required HiveStore<WeightEntry> weightStore,
  }) : _profile = profileStore,
       _weights = weightStore;

  /// Single-record key inside the profile box.
  static const String _key = 'me';

  final HiveStore<UserProfile> _profile;
  final HiveStore<WeightEntry> _weights;

  @override
  UserProfile? getProfile() => _profile.get(_key);

  @override
  Future<void> saveProfile(UserProfile profile) => _profile.put(_key, profile);

  @override
  List<WeightEntry> getWeights() => _weights.getAll()..sort((a, b) => a.date.compareTo(b.date));

  @override
  Future<void> logWeight(WeightEntry entry) async {
    await _weights.put(entry.dayKey, entry);
    final p = getProfile();
    final newest = getWeights().last;
    if (p != null && newest.dayKey == entry.dayKey) {
      await saveProfile(p.copyWith(weightKg: entry.kg, bodyFatPct: entry.bodyFatPct ?? p.bodyFatPct));
    }
  }

  @override
  Future<void> deleteWeight(String dayKey) => _weights.delete(dayKey);

  @override
  Stream<void> watch() => mergeChanges([_profile.watch(), _weights.watch()]);
}
