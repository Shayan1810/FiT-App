import 'package:hive/hive.dart';

part 'activity_data.g.dart';

@HiveType(typeId: 8)
class ActivityData {
  @HiveField(0)
  double neatCalories;

  ActivityData({required this.neatCalories});
}
