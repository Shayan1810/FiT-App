// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calorie_log.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MealEntryAdapter extends TypeAdapter<MealEntry> {
  @override
  final int typeId = 6;

  @override
  MealEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MealEntry(
      name: fields[0] as String,
      protein: fields[1] as double,
      carbs: fields[2] as double,
      fat: fields[3] as double,
      calories: fields[4] as double,
    );
  }

  @override
  void write(BinaryWriter writer, MealEntry obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.protein)
      ..writeByte(2)
      ..write(obj.carbs)
      ..writeByte(3)
      ..write(obj.fat)
      ..writeByte(4)
      ..write(obj.calories);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MealEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DayLogAdapter extends TypeAdapter<DayLog> {
  @override
  final int typeId = 7;

  @override
  DayLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DayLog(
      date: fields[0] as DateTime,
      meals: (fields[1] as List).cast<MealEntry>(),
      extras: (fields[2] as List).cast<MealEntry>(),
    );
  }

  @override
  void write(BinaryWriter writer, DayLog obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.meals)
      ..writeByte(2)
      ..write(obj.extras);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DayLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
