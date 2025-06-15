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

  @HiveField(11)
  final double? bmr;

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
    this.bmr,
  });

    UserData copyWith({
    String? name,
    double? weight,
    int? caloriesIn,
    int? caloriesOut,
    DateTime? lastUpdated,
    double? bodyFatPercentage,
    double? height,
    int? age,
    String? gender,
    DateTime? dateOfBirth,
    String? profileImagePath,
    double? bmr,
  }) {
    return UserData(
      name: name ?? this.name,
      weight: weight ?? this.weight,
      caloriesIn: caloriesIn ?? this.caloriesIn,
      caloriesOut: caloriesOut ?? this.caloriesOut,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      bodyFatPercentage: bodyFatPercentage ?? this.bodyFatPercentage,
      height: height ?? this.height,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      profileImagePath: profileImagePath ?? this.profileImagePath,
      bmr: bmr ?? this.bmr,
    );
  }
}
