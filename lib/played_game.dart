
import 'package:hive/hive.dart';


part 'played_game.g.dart';

@HiveType(typeId: 1)
class PlayedGame extends HiveObject {
  PlayedGame({
    required this.seed,
    required this.reviewed,
    required this.obtainedWords,
    required this.centerLetter,
    required this.extraLetters,
    required this.datePlayed,
  });

  @HiveField(0)
  int seed;

  @HiveField(1)
  bool reviewed;

  @HiveField(2)
  List<String> obtainedWords;

  @HiveField(3)
  String centerLetter;

  @HiveField(4)
  List<String> extraLetters;

  @HiveField(5)
  DateTime? datePlayed;
}