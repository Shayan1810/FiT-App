import '../domain/entities/user_profile.dart';
import '../domain/entities/weight_entry.dart';

/// Converts [UserProfile] ↔ Hive map.
class UserProfileMapper {
  UserProfileMapper._();

  static Map<String, dynamic> toMap(UserProfile p) => {
    'name': p.name,
    'sex': p.sex.name,
    'dob': p.dateOfBirth.millisecondsSinceEpoch,
    'heightCm': p.heightCm,
    'weightKg': p.weightKg,
    'bodyFatPct': p.bodyFatPct,
    'goal': p.goal.name,
    'weeklyRateKg': p.weeklyRateKg,
    'photoPath': p.photoPath,
  };

  static UserProfile fromMap(Map<String, dynamic> m) => UserProfile(
    name: m['name'] as String? ?? 'Friend',
    sex: Sex.values.firstWhere((s) => s.name == m['sex'], orElse: () => Sex.male),
    dateOfBirth: DateTime.fromMillisecondsSinceEpoch(
      (m['dob'] as int?) ?? DateTime(1998).millisecondsSinceEpoch,
    ),
    heightCm: (m['heightCm'] as num?)?.toDouble() ?? 170,
    weightKg: (m['weightKg'] as num?)?.toDouble() ?? 70,
    bodyFatPct: (m['bodyFatPct'] as num?)?.toDouble(),
    goal: GoalType.values.firstWhere((g) => g.name == m['goal'], orElse: () => GoalType.maintain),
    weeklyRateKg: (m['weeklyRateKg'] as num?)?.toDouble() ?? 0,
    photoPath: m['photoPath'] as String?,
  );
}

/// Converts [WeightEntry] ↔ Hive map.
class WeightEntryMapper {
  WeightEntryMapper._();

  static Map<String, dynamic> toMap(WeightEntry e) => {
    'dayKey': e.dayKey,
    'date': e.date.millisecondsSinceEpoch,
    'kg': e.kg,
    'bodyFatPct': e.bodyFatPct,
    'source': e.source.name,
  };

  static WeightEntry fromMap(Map<String, dynamic> m) => WeightEntry(
    dayKey: m['dayKey'] as String,
    date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
    kg: (m['kg'] as num).toDouble(),
    bodyFatPct: (m['bodyFatPct'] as num?)?.toDouble(),
    source: DataSource.values.firstWhere((s) => s.name == m['source'], orElse: () => DataSource.manual),
  );
}
