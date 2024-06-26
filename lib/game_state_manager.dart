
import 'package:flutter/material.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:word_flower/played_game.dart';
import 'package:word_flower/player.dart';

import 'game.dart';

class GameStateManager extends ChangeNotifier {
  Game? _gameState;
  late final Box<PlayedGame> _box;
  late final Box<Player> _playerBox;
  late final Player _player;
  final ValueNotifier<ThemeMode> themeNotifier;
  String lettersToAttempt = '';

  bool isSortAlphabetical = false;
  void toggleSort() {
    isSortAlphabetical = !isSortAlphabetical;
  }

  GameStateManager({required this.themeNotifier});

  List<String> get lettersToShow => _gameState?.lettersToShow??[];
  String get centerLetter => _gameState?.centerLetter??'';
  int get score => _gameState?.score??0;
  int get possibleScore => _gameState?.possibleScore??0;
  List<String> get commonWords => _gameState?.commonWords??[];
  List<String> get validWords => _gameState?.validWords??[];

  List<String> get obtainedWords => isSortAlphabetical
      ? _gameState?.alphaObtainedWords??[]
      : _gameState?.obtainedWords??[];

  bool get isPractice => _gameState?.isPractice??false;
  bool get isReviewed => _gameState?.isReviewed??false;

  bool isLoading = true;


  bool get isCurrentDailyGame {
    final dailySeed = getDailySeed();
    return dailySeed == _gameState?.seed;
  }

  Future<void> initLoad() async {
    await Hive.initFlutter();
    Hive.registerAdapter(PlayedGameAdapter());
    Hive.registerAdapter(PlayerAdapter());

    final futures = [
      Hive.openBox<PlayedGame>('gamesBox'),
      Hive.openBox<Player>('playerBox'),
    ];

    final results = await Future.wait(futures);

    _box = results[0] as Box<PlayedGame>;
    _playerBox = results[1] as Box<Player>;

    final currentTheme = themeNotifier.value;
    final isCurrentlyDarkMode = currentTheme == ThemeMode.dark;
    if(_playerBox.isNotEmpty){
      _player = _playerBox.values.first;
      if (_player.isDarkMode != isCurrentlyDarkMode){
        themeNotifier.value = _player.isDarkMode ? ThemeMode.dark : ThemeMode.light;
      }
    } else {
      _player = Player(0, 0, 0, isCurrentlyDarkMode);
      _playerBox.add(_player);
      _player.save();
    }

    themeNotifier.addListener(themeSave);

    await loadDailyGame();
    notifyListeners();
  }

  @override
  void dispose() {
    _box.close();
    _playerBox.close();
    themeNotifier.removeListener(themeSave);
    super.dispose();
  }

  Future<void> loadDailyGame() => loadGame(getDailySeed(), false);
  Future<void> loadPracticeGame() => loadGame(DateTime.now().millisecond, true);

  Future<void> loadGame(int seed, bool isPractice) async {
    if (!isLoading) {
      isLoading = true;
      notifyListeners();

      // as we're doing the current frame now, this will be run as
      // soon as it's finished. this frame won't include the loading
      // screen, so if we init the game after this frame we won't see
      // the loading screen while it's being created
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // this will be run after the following frame, which will draw
        // the loading screen, so we see the loading screen while the
        // new game initialises
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await loadGame(seed, isPractice);
        });
      });
      return;
    }

    lettersToAttempt = '';
    _gameState = await Game.createGame(seed, _box, isPractice);

    isLoading = false;

    notifyListeners();
  }

  void setAsReviewed(){
    if (_gameState==null) return;
    _gameState!.setAsReviewed();
    notifyListeners();
  }

  void clearLetters() {
    if (lettersToAttempt.isEmpty) return;
    lettersToAttempt = '';
    notifyListeners();
  }

  static int getDailySeed() {
    final dateSeed = DateTime.now().toUtc();
    return (DateTime
        .utc(dateSeed.year, dateSeed.month, dateSeed.day)
        .millisecondsSinceEpoch / 10000).floor();
  }

  void themeSave() {
    final isDarkMode = themeNotifier.value == ThemeMode.dark;
    if (_player.isDarkMode == isDarkMode) return;
    _player.isDarkMode = isDarkMode;
    // i don't like this isn't awaited?
    savePlayer(_player);
  }

  void shuffleAndSetLetters(){
    if (_gameState==null) return;
    _gameState!.shuffleAndSetLetters();
    notifyListeners();
  }

  static Future<void> savePlayer(Player player) async {
    await player.save();
  }

  void pressLetter(String letter) {
    lettersToAttempt = lettersToAttempt + letter;
    notifyListeners();
  }
  void backspace(){
    if (lettersToAttempt.isEmpty) return;
    lettersToAttempt = lettersToAttempt.substring(0, lettersToAttempt.length - 1);
    notifyListeners();
  }

  bool get isValidToAttempt => ((lettersToAttempt.length) > 3 && !(_gameState?.isReviewed??false));
  bool get isAllLetters => lettersToAttempt.length > lettersToShow.length && lettersToAttempt.contains(centerLetter) && !lettersToShow.any((l) => !lettersToAttempt.contains(l));


  bool attemptLetters() {
    if (!isValidToAttempt) return false;
    if ((_gameState?.checkLetters(lettersToAttempt) ?? false)) {
      lettersToAttempt = '';
      notifyListeners();
      return true;
    }
    return false;
  }
}