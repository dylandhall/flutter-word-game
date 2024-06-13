import 'package:hive/hive.dart';
part 'player.g.dart';

@HiveType(typeId: 2)
class Player extends HiveObject {

  Player(this.gamesPlayed, this.streak, this.averageScore, this.isDarkMode);

  @HiveField(0)
  int gamesPlayed;

  @HiveField(1)
  int streak;

  @HiveField(2)
  double averageScore;

  @HiveField(3)
  bool isDarkMode;

  @HiveField(4)
  DateTime? lastFinished;
}