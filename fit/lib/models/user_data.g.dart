// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserDataAdapter extends TypeAdapter<UserData> {
  @override
  final int typeId = 0;

  @override
  UserData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserData(
      name: fields[0] as String,
      weight: fields[1] as double,
      caloriesIn: fields[2] as int,
      caloriesOut: fields[3] as int,
      lastUpdated: fields[4] as DateTime,
      bodyFatPercentage: fields[5] as double,
      height: fields[6] as double,
      age: fields[7] as int,
      gender: fields[8] as String,
      dateOfBirth: fields[9] as DateTime,
      profileImagePath: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, UserData obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.weight)
      ..writeByte(2)
      ..write(obj.caloriesIn)
      ..writeByte(3)
      ..write(obj.caloriesOut)
      ..writeByte(4)
      ..write(obj.lastUpdated)
      ..writeByte(5)
      ..write(obj.bodyFatPercentage)
      ..writeByte(6)
      ..write(obj.height)
      ..writeByte(7)
      ..write(obj.age)
      ..writeByte(8)
      ..write(obj.gender)
      ..writeByte(9)
      ..write(obj.dateOfBirth)
      ..writeByte(10)
      ..write(obj.profileImagePath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
