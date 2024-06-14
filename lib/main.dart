import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:word_flower/played_game.dart';
import 'package:word_flower/player.dart';

import 'game_info.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

  const MyApp({super.key});
  final int state = 0;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder:(buildContext, ThemeMode currentMode, _) =>
        MaterialApp(
          title: 'Word Flower',
          themeMode: currentMode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.green, brightness: Brightness.light),
            useMaterial3: true
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.green, brightness: Brightness.dark),
            useMaterial3: true
          ),
          home: const MyHomePage(title: 'Word Fucker 3000'),
      )
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {
  GameState? _gameState;
  late AnimationController _controller;
  late Animation<double> _offsetAnimation;
  late int _repeatCount = 0;
  late FocusNode _focusNode;
  late final Box<PlayedGame> _box;
  late final Box<Player> _playerBox;
  late final Player _player;
  String _lettersToAttempt = '';
  PageState _pageState = PageState.playing;
  bool _isLoading = true;
  bool _isDarkMode = MyApp.themeNotifier.value == ThemeMode.dark;

  _MyHomePageState();

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    _box.close();
    // not required, just testing
    _offsetAnimation.removeStatusListener(statusListener);
    super.dispose();
  }


  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );

    _offsetAnimation = Tween<double>(begin: -4, end: 4).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    )..addStatusListener(statusListener);
    initLoad();
  }

  void statusListener(AnimationStatus status) {
    if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
      setState(() {
        _repeatCount++;
        if (_repeatCount > 3) {
          _controller.stop();
          _repeatCount = 0; // Reset the repeat count for future animations
        } else {
          if (status == AnimationStatus.dismissed){
            _controller.forward();
            return;
          }
          _controller.reverse();
        }
      });
    }
  }

  void initLoad() async {
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

    if(_playerBox.isNotEmpty){
      _player = _playerBox.values.first;
      if (_player.isDarkMode != _isDarkMode){
        _isDarkMode = _player.isDarkMode;
        MyApp.themeNotifier.value = _isDarkMode ? ThemeMode.dark : ThemeMode.light;
      }
    } else {
      _player = Player(0, 0, 0, _isDarkMode);
      _playerBox.add(_player);
      _player.save();
    }

    await loadGame(getDailySeed(), false);
  }

  int getDailySeed() {
    final dateSeed = DateTime.now().toUtc();
    return (DateTime
        .utc(dateSeed.year, dateSeed.month, dateSeed.day)
        .millisecondsSinceEpoch / 10000).floor();
  }

  Future<void> loadGame(int seed, bool isPractice) async {
    var gs = await GameState.createGame(seed, _box, isPractice);

    setState(() {
      _lettersToAttempt = '';
      _gameState = gs;
      _isLoading = false;
    });
  }

  pressLetter(String letter) {
    setState(() {
      _lettersToAttempt = _lettersToAttempt + letter;
    });
  }

  attemptLetters() {
    if ((_lettersToAttempt.length) < 4 || (_gameState?.isReviewed??false)) return;
    setState(() {
      if ((_gameState?.checkLetters(_lettersToAttempt) ?? false)) {
        _lettersToAttempt = '';
        return;
      }
      _repeatCount = 0; // Reset the repeat count before starting the animation
      _controller.reset();
      _controller.forward();
    });
  }

  List<Widget> getWidgetsForPage(ThemeData theme) {
    switch (_pageState){
      case PageState.playing:
        return getAllPlayingWidgets(theme).toList();
      case PageState.reviewing:
        return getAllReviewingWidgets(theme).toList();
    }
  }

  Iterable<Widget> getAllReviewingWidgets(ThemeData theme) sync* {
    if (_gameState == null) {
      yield const Text('loading..');
      setState(() {
        _pageState = PageState.playing;
      });
      return;
    }
    assert(_gameState != null);

    const bold = TextStyle(fontWeight: FontWeight.bold);
    const big = TextStyle(fontSize: 22);

    yield Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Text('Center letter: ${_gameState!.centerLetter.toUpperCase()}'),
          Text('Additional letters: ${_gameState!.lettersToShow.map((l) => l.toUpperCase()).join(', ')}'),
          Text('You scored: ${_gameState?.score} out of a possible ${_gameState?.possibleScore}', style: bold,),
        ],
      )
    );
    var commonWords = _gameState!.commonWords.toList();
    var uncommonWords = _gameState!.validWords.where((w) => !commonWords.contains(w)).toList();
    commonWords.sort((a,b) => a.compareTo(b));
    uncommonWords.sort((a,b) => a.compareTo(b));

    yield Padding(
        padding: const EdgeInsets.all(12),
        child: TextButton(
          onPressed: () => setState(() {_pageState = PageState.playing;}),
          child: const Text('Back to game..'),
        ));

    final commonPercent =
      ((commonWords.where((w) => _gameState!.obtainedWords.contains(w)).length)
          / (commonWords.length) * 100).round();

    yield Padding(
        padding: const EdgeInsets.all(12),
        child: Text("Common words (included in max score) - $commonPercent%", style: big,));

    yield getGridView(commonWords, _gameState!.obtainedWords, _isDarkMode);

    final uncommonPercent =
    ((uncommonWords.where((w) => _gameState!.obtainedWords.contains(w)).length)
        / uncommonWords.length * 100).round();

    yield Padding(
        padding: const EdgeInsets.fromLTRB(12, 50, 12, 12),
        child: Text("Uncommon words - $uncommonPercent%", style: big,));

    yield getGridView(uncommonWords, _gameState!.obtainedWords, _isDarkMode);

    yield Padding(
        padding: const EdgeInsets.all(20),
        child: TextButton(
          onPressed: () => setState(() {_pageState = PageState.playing;}),
          child: const Text('Back to game..'),
        ));

  }

  static GridView getGridView(List<String> allWords, List<String> obtainedWords, bool isDarkMode) {
    return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: allWords.length,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          mainAxisSpacing: 2,
          childAspectRatio: 6,
          crossAxisSpacing: 2,
        ),
        itemBuilder: (context, index) {
          var isFound = obtainedWords.contains(allWords[index]);
          return
            Center(
              child: ListTile(
                        leading: Icon(
                            isFound
                              ? CupertinoIcons.checkmark_seal_fill
                              : CupertinoIcons.xmark_seal_fill,
                        color: isFound ? Colors.green : isDarkMode ? Colors.white30 : Colors.black38,
                        ),
                        title: Text(allWords[index]),
            ),
          );
        },
      );
  }


  Iterable<Widget> getAllPlayingWidgets(ThemeData theme) sync* {
    if (_isLoading || _gameState == null) {
      yield const Padding(padding: EdgeInsets.fromLTRB(0, 80, 0, 0), child: Image(image: AssetImage('assets/word-flower-image.webp'), height: 256, fit: BoxFit.fitHeight,));
      return;
    }

    const boldStyle = TextStyle(fontWeight: FontWeight.bold);
    const wordsStyle = TextStyle(fontSize: 16);
    const titleStyle = TextStyle(fontSize: 20);

    yield const Padding(padding: EdgeInsets.only(top: 18), child: Text('How many words can you get?', style: titleStyle,));

    const edgeInsets = EdgeInsets.all(8.0);

    yield Padding(
        padding: edgeInsets,
        child: Text(_gameState?.obtainedWords.join(" — ")??'', style: wordsStyle, textAlign: TextAlign.center),
    );

    var info = (_gameState?.isReviewed??false)
        ? ' (Finished)'
        : (_gameState?.isPractice??false)
          ? ' (Practice)'
          : '';

    yield Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text('Score: ${_gameState?.score?.toString()??'0'} of a possible ${(_gameState?.possibleScore??0)} $info', style: boldStyle)
    );
    //     ]
    // );
    yield Padding(
        padding: edgeInsets,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: getLetterButtonWidgets(theme, _gameState!).toList(),
        ));

    var buttonColor = theme.floatingActionButtonTheme.foregroundColor ?? theme.colorScheme.primary;
    var disabledButtonColor = (theme.floatingActionButtonTheme.foregroundColor ?? theme.colorScheme.primary).withOpacity(0.5);

    yield Padding(
        padding: edgeInsets,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AnimatedBuilder(
              //key: Key(""),
              animation: _controller,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.circular(16.0)),
                  border: Border.all(
                      color: theme.colorScheme.outline,
                      style: BorderStyle.solid
                  ),
                ),
                width: 250.0,
                child: Padding(
                    padding: edgeInsets,
                    child: Text(_lettersToAttempt)
                ),
              ),
              builder: (context, child) => Transform.translate(
                offset: Offset(_offsetAnimation.value, 0),
                child: child
              )
            ),
            Padding(
                padding: const EdgeInsets.all(2),
                child: IconButton(
                  onPressed: _lettersToAttempt.isNotEmpty
                      ? () => setState(() { _lettersToAttempt = _lettersToAttempt.substring(0, _lettersToAttempt.length - 1); })
                      : null,
                  icon: const Icon(Icons.backspace),
                )),
        ])
    );

    var validToCheck = !(_gameState?.isReviewed??false) && _lettersToAttempt.length > 3;
    yield Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: TextButton(
                  onPressed: _lettersToAttempt.isNotEmpty
                      ? () => setState(() { _lettersToAttempt = ''; })
                      : null,
                  child: Text('Clear', style: TextStyle(color: _lettersToAttempt.isNotEmpty
                      ? buttonColor
                      : disabledButtonColor),))),
          Padding(
              padding: edgeInsets,
              child: IconButton(
                  onPressed: () => setState((){
                    _gameState?.shuffleAndSetLetters();
                  }),
                  icon: const Icon(Icons.recycling_rounded)
              )
          ),
          Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: TextButton(
                  onPressed: validToCheck ? attemptLetters : null,
                  child: Text('Check', style: TextStyle(color: (validToCheck ? buttonColor : disabledButtonColor)),)
              )
          )
        ]
    );

    yield TextButton(
            onPressed: () async {
              if (_gameState?.isReviewed??false){
                setState(() {
                  _pageState = PageState.reviewing;
                });
                return;
              }
              await showDialog<String>(
                context: context,
                builder: (BuildContext context) => AlertDialog(
                  title: const Text('Review?'),
                  content: const Text('This will finish the game and let you review the words'),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.pop(context, 'Cancel'),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context, 'OK');
                        setState(() {
                          _gameState?.setAsReviewed();
                          _pageState = PageState.reviewing;
                        });
                      },
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
            child: const Text('Review'),
          );

    var dailySeed = getDailySeed();

    final isCurrentDailyGame = dailySeed == _gameState!.seed;

    yield TextButton(
      onPressed:
          isCurrentDailyGame
            ? null
            : () async {
                setState(() {
                  _isLoading = true;
                  _pageState = PageState.playing;
                });

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  WidgetsBinding.instance.addPostFrameCallback((_) async {
                    await loadGame(dailySeed, false);
                  });
                });
              },
      child: const Text('Today''s game'),
    );
  }

  Iterable<Widget> getLetterButtonWidgets(ThemeData theme, GameState gameState) sync* {
    const edgeInsets = EdgeInsets.all(4.0);
    const circleBorder = CircleBorder();

    yield Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center,
      children: gameState.lettersToShow.take(2).map((letter) => Padding(
          padding: edgeInsets,
          child: FloatingActionButton(
              onPressed: () => pressLetter(letter),
              shape: circleBorder,
              child: Text(letter.toUpperCase())
          )
      )).toList(),
    );

    yield Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: edgeInsets,
          child: FloatingActionButton(
              onPressed: () => pressLetter(gameState.lettersToShow[2]),
              shape: circleBorder,
              child: Text(gameState.lettersToShow[2].toUpperCase()))),
        Padding(
            padding: edgeInsets,
            child: FloatingActionButton(
              onPressed: () => pressLetter(gameState.centerLetter),
              shape: circleBorder,
              backgroundColor: theme.buttonTheme.colorScheme?.surfaceBright ?? theme.colorScheme.surfaceBright,
              child: Text(
                  gameState.centerLetter.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold)
              ),
            )),
        Padding(
            padding: edgeInsets,
            child: FloatingActionButton(
                onPressed: () => pressLetter(gameState.lettersToShow[3]),
                shape: circleBorder,
                child: Text(gameState.lettersToShow[3].toUpperCase()))),
      ],
    );

    yield Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center,
      children: gameState.lettersToShow.skip(4).take(2).map((letter) => Padding(
          padding: edgeInsets,
          child: FloatingActionButton(
              onPressed: () => pressLetter(letter),
              shape: circleBorder,
              child: Text(letter.toUpperCase())
          )
      )).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: (KeyEvent k)  => onKeyEvent(k),
      autofocus: true,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          actions: [
            Switch(
              value: _isDarkMode,
              onChanged: (value) {
                MyApp.themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
                _isDarkMode = value;
                _player.isDarkMode = value;
                _player.save();
              },
            ),
          ],
          title: Row(children: [Text(widget.title), const Padding(padding: EdgeInsets.fromLTRB(20, 0, 0, 0), child: Image(image: AssetImage('assets/word-flower-image.webp'), height: 32, fit: BoxFit.fitHeight,))]),
        ),
        body: SingleChildScrollView(
          child: Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: getWidgetsForPage(Theme.of(context))
              ),
        )),
        floatingActionButton: _pageState == PageState.playing && !(_gameState?.isReviewed ?? false)
          ? null
          : FloatingActionButton(
              onPressed: () async {
                setState(() {
                  _isLoading = true;
                  _pageState = PageState.playing;
                });

                // as we're doing the current frame now, this will be run as
                // soon as it's finished. this frame won't include the loading
                // screen, so if we init the game after this frame we won't see
                // the loading screen while it's being created
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  // this will be run after the following frame, which will draw
                  // the loading screen, so we see the loading screen while the
                  // new game initialises
                  WidgetsBinding.instance.addPostFrameCallback((_) async {
                    await loadGame(DateTime.now().millisecond, true);
                  });
                });
              },
              tooltip: 'New practice game',
              child: const Icon(Icons.add),
            ),
      ),
    );
  }

  void onKeyEvent(KeyEvent k) {
    if (k is! KeyDownEvent) return;
    if (k.logicalKey == LogicalKeyboardKey.enter){
      attemptLetters();
      return;
    }
    if (k.logicalKey == LogicalKeyboardKey.backspace){
      if (_lettersToAttempt.isEmpty) return;
      setState(() { _lettersToAttempt = _lettersToAttempt.substring(0, _lettersToAttempt.length - 1); });
      return;
    }
    if (k.character == null || !(k.character == _gameState?.centerLetter || (_gameState?.lettersToShow.any((l) => k.character?.toLowerCase() == l) ?? false))) {
      return;
    }
    pressLetter(k.character!.toLowerCase());
  }
}
enum PageState {
  playing,
  reviewing,
}