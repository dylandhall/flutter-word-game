// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'played_game.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PlayedGameAdapter extends TypeAdapter<PlayedGame> {
  @override
  final int typeId = 1;

  @override
  PlayedGame read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PlayedGame(
      seed: fields[0] as int,
      reviewed: fields[1] as bool,
      obtainedWords: (fields[2] as List).cast<String>(),
      centerLetter: fields[3] as String,
      extraLetters: (fields[4] as List).cast<String>(),
      datePlayed: fields[5] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, PlayedGame obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.seed)
      ..writeByte(1)
      ..write(obj.reviewed)
      ..writeByte(2)
      ..write(obj.obtainedWords)
      ..writeByte(3)
      ..write(obj.centerLetter)
      ..writeByte(4)
      ..write(obj.extraLetters)
      ..writeByte(5)
      ..write(obj.datePlayed);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayedGameAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
