import 'package:hive/hive.dart';

part 'user_data.g.dart';

@HiveType(typeId: 0)
class UserData extends HiveObject {
  @HiveField(0)
  late String name;

  @HiveField(1)
  late double weight;

  @HiveField(2)
  late int caloriesIn;

  @HiveField(3)
  late int caloriesOut;

  @HiveField(4)
  late DateTime lastUpdated;

  @HiveField(5)
  late double bodyFatPercentage;

  @HiveField(6)
  late double height; // in cm

  @HiveField(7)
  late int age;

  @HiveField(8)
  late String gender;

  @HiveField(9)
  late DateTime dateOfBirth;

  @HiveField(10)
  String? profileImagePath;

  UserData({
    required this.name,
    required this.weight,
    required this.caloriesIn,
    required this.caloriesOut,
    required this.lastUpdated,
    required this.bodyFatPercentage,
    required this.height,
    required this.age,
    required this.gender,
    required this.dateOfBirth,
    this.profileImagePath,
  });
}
