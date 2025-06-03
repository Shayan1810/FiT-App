// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recipe.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RecipeIngredientAdapter extends TypeAdapter<RecipeIngredient> {
  @override
  final int typeId = 4;

  @override
  RecipeIngredient read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RecipeIngredient(
      foodItemName: fields[0] as String,
      quantity: fields[1] as double,
      unit: fields[2] as String,
      calories: fields[3] as double,
      protein: fields[4] as double,
      carbohydrate: fields[5] as double,
      fat: fields[6] as double,
    );
  }

  @override
  void write(BinaryWriter writer, RecipeIngredient obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.foodItemName)
      ..writeByte(1)
      ..write(obj.quantity)
      ..writeByte(2)
      ..write(obj.unit)
      ..writeByte(3)
      ..write(obj.calories)
      ..writeByte(4)
      ..write(obj.protein)
      ..writeByte(5)
      ..write(obj.carbohydrate)
      ..writeByte(6)
      ..write(obj.fat);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecipeIngredientAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RecipeAdapter extends TypeAdapter<Recipe> {
  @override
  final int typeId = 5;

  @override
  Recipe read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Recipe(
      name: fields[0] as String,
      tag: fields[1] as String,
      unit: fields[2] as String,
      ingredients: (fields[3] as List).cast<RecipeIngredient>(),
      totalCalories: fields[4] as double,
      totalProtein: fields[5] as double,
      totalCarbohydrate: fields[6] as double,
      totalFat: fields[7] as double,
    );
  }

  @override
  void write(BinaryWriter writer, Recipe obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.tag)
      ..writeByte(2)
      ..write(obj.unit)
      ..writeByte(3)
      ..write(obj.ingredients)
      ..writeByte(4)
      ..write(obj.totalCalories)
      ..writeByte(5)
      ..write(obj.totalProtein)
      ..writeByte(6)
      ..write(obj.totalCarbohydrate)
      ..writeByte(7)
      ..write(obj.totalFat);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecipeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
