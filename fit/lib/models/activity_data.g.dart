// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activity_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ActivityDataAdapter extends TypeAdapter<ActivityData> {
  @override
  final int typeId = 8;

  @override
  ActivityData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ActivityData(
      neatCalories: fields[0] as double,
    );
  }

  @override
  void write(BinaryWriter writer, ActivityData obj) {
    writer
      ..writeByte(1)
      ..writeByte(0)
      ..write(obj.neatCalories);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActivityDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
