// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'goal.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DailyGoalAdapter extends TypeAdapter<DailyGoal> {
  @override
  final int typeId = 4;

  @override
  DailyGoal read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyGoal(
      proteinGoal: fields[0] as int,
      carbGoal: fields[1] as int,
      fatGoal: fields[2] as int,
      calorieGoal: fields[3] as int,
    );
  }

  @override
  void write(BinaryWriter writer, DailyGoal obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.proteinGoal)
      ..writeByte(1)
      ..write(obj.carbGoal)
      ..writeByte(2)
      ..write(obj.fatGoal)
      ..writeByte(3)
      ..write(obj.calorieGoal);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyGoalAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
