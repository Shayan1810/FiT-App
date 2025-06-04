// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meal_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MealDataAdapter extends TypeAdapter<MealData> {
  @override
  final int typeId = 2;

  @override
  MealData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MealData(
      mealName: fields[0] as String,
      note: fields[1] as String?,
      items: (fields[2] as List?)?.cast<dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, MealData obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.mealName)
      ..writeByte(1)
      ..write(obj.note)
      ..writeByte(2)
      ..write(obj.items);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MealDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
