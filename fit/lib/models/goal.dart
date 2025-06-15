import 'package:hive/hive.dart';

part 'goal.g.dart';

@HiveType(typeId: 4)
class DailyGoal {
  @HiveField(0) final int proteinGoal;
  @HiveField(1) final int carbGoal;
  @HiveField(2) final int fatGoal;
  @HiveField(3) final int calorieGoal;

  DailyGoal({
    required this.proteinGoal,
    required this.carbGoal,
    required this.fatGoal,
    required this.calorieGoal,
  });

  DailyGoal copyWith({
    int? proteinGoal,
    int? carbGoal,
    int? fatGoal,
    int? calorieGoal,
  }) {
    return DailyGoal(
      proteinGoal: proteinGoal ?? this.proteinGoal,
      carbGoal: carbGoal ?? this.carbGoal,
      fatGoal: fatGoal ?? this.fatGoal,
      calorieGoal: calorieGoal ?? this.calorieGoal,
    );
  }

  factory DailyGoal.defaultGoal() {
    return DailyGoal(
      proteinGoal: 150,
      carbGoal: 300,
      fatGoal: 80,
      calorieGoal: 2500,
    );
  }
}
