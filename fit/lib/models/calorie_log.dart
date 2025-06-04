import 'package:hive/hive.dart';

part 'calorie_log.g.dart';

@HiveType(typeId: 6)
class MealEntry extends HiveObject {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final double protein;

  @HiveField(2)
  final double carbs;

  @HiveField(3)
  final double fat;

  @HiveField(4)
  final double calories;

  MealEntry({
    required this.name,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.calories,
  });
}

@HiveType(typeId: 7)
class DayLog extends HiveObject {
  @HiveField(0)
  final DateTime date;

  @HiveField(1)
  final List<MealEntry> meals;

  @HiveField(2)
  final List<MealEntry> extras;

  DayLog({
    required this.date,
    this.meals = const [],
    this.extras = const [],
  });
}
