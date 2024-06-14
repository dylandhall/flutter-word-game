import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:word_flower/game_state_manager.dart';


void main() {
  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
  static final GameStateManager _gameStateManager = GameStateManager();

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
          home: MyHomePage(title: 'Word Finder 3000', gameStateManager: _gameStateManager),
      )
    );
  }
}

//
// class ReviewPage extends StatefulWidget {
//
// }
//
// class _ReviewPageState ex

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title, required this.gameStateManager});

  final String title;
  final GameStateManager gameStateManager;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _offsetAnimation;
  late int _repeatCount = 0;
  late FocusNode _focusNode;
  PageState _pageState = PageState.playing;
  bool _isDarkMode = MyApp.themeNotifier.value == ThemeMode.dark;

  _MyHomePageState();

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    // not required, just testing
    _offsetAnimation.removeStatusListener(statusListener);
    MyApp.themeNotifier.removeListener(themeUpdate);
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
    )
      ..addStatusListener(statusListener);

    MyApp.themeNotifier.addListener(themeUpdate);
    _isDarkMode = MyApp.themeNotifier.value == ThemeMode.dark;
    widget.gameStateManager.initLoad();
  }

  void themeUpdate() {
    _isDarkMode = MyApp.themeNotifier.value == ThemeMode.dark;
  }

  void statusListener(AnimationStatus status) {
    if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
      setState(() {
        _repeatCount++;
        if (_repeatCount > 3) {
          _controller.stop();
          _repeatCount = 0; // Reset the repeat count for future animations
        } else {
          if (status == AnimationStatus.dismissed) {
            _controller.forward();
            return;
          }
          _controller.reverse();
        }
      });
    }
  }

  List<Widget> getWidgetsForPage(PageState pageState, GameStateManager gameState, ThemeData theme) {
    switch (pageState) {
      case PageState.playing:
        return getAllPlayingWidgets(theme, gameState).toList();
      case PageState.reviewing:
        return getAllReviewingWidgets(theme, gameState).toList();
    }
  }

  Iterable<Widget> getAllReviewingWidgets(ThemeData theme, GameStateManager gameState) sync* {
    if (gameState.isLoading) {
      yield const Text('loading..');
      return;
    }

    const bold = TextStyle(fontWeight: FontWeight.bold);
    const big = TextStyle(fontSize: 22);

    yield Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Text('Center letter: ${gameState.centerLetter.toUpperCase()}'),
            Text('Additional letters: ${gameState.lettersToShow.map((l) => l.toUpperCase()).join(', ')}'),
            Text('You scored: ${gameState.score} out of a possible ${gameState.possibleScore}', style: bold,),
          ],
        )
    );
    var commonWords = gameState.commonWords.toList();
    var uncommonWords = gameState.validWords.where((w) =>
    !commonWords.contains(w)).toList();
    commonWords.sort((a, b) => a.compareTo(b));
    uncommonWords.sort((a, b) => a.compareTo(b));

    yield Padding(
        padding: const EdgeInsets.all(12),
        child: TextButton(
          onPressed: () => setState(() { _pageState = PageState.playing; }),
          child: const Text('Back to game..'),
        ));

    final commonPercent = ((commonWords.where((w) => gameState.obtainedWords.contains(w)).length)
        / (commonWords.length) * 100).round();

    yield Padding(
        padding: const EdgeInsets.all(12),
        child: Text("Common words (included in max score) - $commonPercent%", style: big,));

    yield getGridView(commonWords, gameState.obtainedWords, _isDarkMode);

    final uncommonPercent = ((uncommonWords.where((w) => gameState.obtainedWords.contains(w)).length)
        / uncommonWords.length * 100).round();

    yield Padding(
        padding: const EdgeInsets.fromLTRB(12, 50, 12, 12),
        child: Text("Uncommon words - $uncommonPercent%", style: big,));

    yield getGridView(uncommonWords, gameState.obtainedWords, _isDarkMode);

    yield Padding(
        padding: const EdgeInsets.all(20),
        child: TextButton(
          onPressed: () =>
              setState(() {
                _pageState = PageState.playing;
              }),
          child: const Text('Back to game..'),
        ));
  }

  static GridView getGridView(List<String> allWords, List<String> obtainedWords, bool isDarkMode) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: allWords.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 230,
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
                color: isFound ? Colors.green : isDarkMode
                    ? Colors.white30
                    : Colors.black38,
              ),
              title: Text(allWords[index]),
            ),
          );
      },
    );
  }


  Iterable<Widget> getAllPlayingWidgets(ThemeData theme, GameStateManager gameState) sync* {
    if (gameState.isLoading) {
      yield const Padding(padding: EdgeInsets.fromLTRB(0, 80, 0, 0),
          child: Image(image: AssetImage('assets/word-flower-image.webp'),
            height: 256,
            fit: BoxFit.fitHeight,));
      return;
    }

    const boldStyle = TextStyle(fontWeight: FontWeight.bold);
    const wordsStyle = TextStyle(fontSize: 16);
    const titleStyle = TextStyle(fontSize: 20);

    yield const Padding(padding: EdgeInsets.only(top: 18),
        child: Text('How many words can you get?', style: titleStyle,));

    const edgeInsets = EdgeInsets.all(8.0);

    yield Padding(
      padding: edgeInsets,
      child: Text(gameState.obtainedWords.join(" — ") ?? '', style: wordsStyle,
          textAlign: TextAlign.center),
    );

    var info = (gameState.isReviewed)
        ? ' (Finished)'
        : (gameState.isPractice)
        ? ' (Practice)'
        : '';

    yield Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text('Score: ${gameState.score} of a possible ${(gameState.possibleScore)} $info', style: boldStyle)
    );

    yield Padding(
        padding: edgeInsets,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: getLetterButtonWidgets(theme, gameState).toList(),
        ));

    var buttonColor = theme.floatingActionButtonTheme.foregroundColor ??
        theme.colorScheme.primary;
    var disabledButtonColor = (theme.floatingActionButtonTheme
        .foregroundColor ?? theme.colorScheme.primary).withOpacity(0.5);

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
                      borderRadius: const BorderRadius.all(
                          Radius.circular(16.0)),
                      border: Border.all(
                          color: theme.colorScheme.outline,
                          style: BorderStyle.solid
                      ),
                    ),
                    width: 250.0,
                    child: Padding(
                        padding: edgeInsets,
                        child: Text(gameState.lettersToAttempt)
                    ),
                  ),
                  builder: (context, child) =>
                      Transform.translate(
                          offset: Offset(_offsetAnimation.value, 0),
                          child: child
                      )
              ),
              Padding(
                  padding: const EdgeInsets.all(2),
                  child: IconButton(
                    onPressed: gameState.lettersToAttempt.isNotEmpty
                        ? gameState.backspace
                        : null,
                    icon: const Icon(Icons.backspace),
                  )),
            ])
    );

    var validToCheck = !gameState.isReviewed &&
        gameState.lettersToAttempt.length > 3;
    yield Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: TextButton(
                  onPressed: gameState.lettersToAttempt.isNotEmpty
                      ? gameState.clearLetters
                      : null,
                  child: Text('Clear', style: TextStyle(
                      color: gameState.lettersToAttempt.isNotEmpty
                          ? buttonColor
                          : disabledButtonColor),
                  )
              )
          ),
          Padding(
              padding: edgeInsets,
              child: IconButton(
                  onPressed: gameState.shuffleAndSetLetters,
                  icon: const Icon(Icons.recycling_rounded)
              )
          ),
          Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: TextButton(
                  onPressed: validToCheck ? gameState.attemptLetters : null,
                  child: Text('Check', style: TextStyle(color: (validToCheck
                      ? buttonColor
                      : disabledButtonColor)),)
              )
          )
        ]
    );

    yield TextButton(
      onPressed: () async {
        if (gameState.isReviewed) {
          setState(() {
            _pageState = PageState.reviewing;
          });
          return;
        }
        await showDialog<String>(
          context: context,
          builder: (BuildContext context) =>
              AlertDialog(
                title: const Text('Review?'),
                content: const Text(
                    'This will finish the game and let you review the words'),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.pop(context, 'Cancel'),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context, 'OK');
                      setState(() {
                        gameState.setAsReviewed();
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

    final isCurrentDailyGame = gameState.isCurrentDailyGame;
    yield TextButton(
      onPressed:
      isCurrentDailyGame
          ? null
          : gameState.loadDailyGame,
      child: const Text('Today''s game'),
    );
  }

  Iterable<Widget> getLetterButtonWidgets(ThemeData theme,
      GameStateManager gameState) sync* {
    const edgeInsets = EdgeInsets.all(4.0);
    const circleBorder = CircleBorder();

    yield Column(mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: gameState.lettersToShow.take(2).map((letter) =>
          Padding(
              padding: edgeInsets,
              child: FloatingActionButton(
                  onPressed: () => gameState.pressLetter(letter),
                  shape: circleBorder,
                  child: Text(letter.toUpperCase())
              )
          )).toList(),
    );

    yield Column(mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
            padding: edgeInsets,
            child: FloatingActionButton(
                onPressed: () => gameState.pressLetter(gameState.lettersToShow[2]),
                shape: circleBorder,
                child: Text(gameState.lettersToShow[2].toUpperCase()))),
        Padding(
            padding: edgeInsets,
            child: FloatingActionButton(
              onPressed: () => gameState.pressLetter(gameState.centerLetter),
              shape: circleBorder,
              backgroundColor: theme.buttonTheme.colorScheme?.surfaceBright ??
                  theme.colorScheme.surfaceBright,
              child: Text(
                  gameState.centerLetter.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold)
              ),
            )),
        Padding(
            padding: edgeInsets,
            child: FloatingActionButton(
                onPressed: () =>
                    gameState.pressLetter(gameState.lettersToShow[3]),
                shape: circleBorder,
                child: Text(gameState.lettersToShow[3].toUpperCase()))),
      ],
    );

    yield Column(mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: gameState.lettersToShow.skip(4).take(2).map((letter) =>
          Padding(
              padding: edgeInsets,
              child: FloatingActionButton(
                  onPressed: () => gameState.pressLetter(letter),
                  shape: circleBorder,
                  child: Text(letter.toUpperCase())
              )
          )).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return
      KeyboardListener(
          focusNode: _focusNode,
          onKeyEvent: (KeyEvent k) => onKeyEvent(k),
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
                  },
                ),
              ],
              title: Row(children: [
                Text(widget.title),
                const Padding(padding: EdgeInsets.fromLTRB(20, 0, 0, 0),
                    child: Image(image: AssetImage('assets/word-flower-image.webp'),
                      height: 32,
                      fit: BoxFit.fitHeight,))
              ]),
            ),
            body: SingleChildScrollView(
                child: Center(
                  child: ListenableBuilder(
                    listenable: widget.gameStateManager,
                    builder: (bc, _) => Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: getWidgetsForPage(_pageState, widget.gameStateManager, Theme.of(context))
                  )),
                ),
            ),
            floatingActionButton:
              ListenableBuilder(
                listenable: widget.gameStateManager,
                child: const Center(),
                builder: (bc, child) => (_pageState == PageState.playing && !widget.gameStateManager.isReviewed
                  ? child!
                  : FloatingActionButton(
                      onPressed: () async {
                        setState(() {
                          _pageState = PageState.playing;
                        });
                        await widget.gameStateManager.loadPracticeGame();
                      },
                      tooltip: 'New practice game',
                      child: const Icon(Icons.add),
                    )),
          ),
        ));
  }

  void onKeyEvent(KeyEvent k) {
    if (k is! KeyDownEvent) return;
    final gameState = widget.gameStateManager;
    if (k.logicalKey == LogicalKeyboardKey.enter) {
      gameState.attemptLetters();
      return;
    }
    if (k.logicalKey == LogicalKeyboardKey.backspace) {
      gameState.backspace();
      return;
    }
    if (k.character == null || !(k.character == gameState.centerLetter || (gameState.lettersToShow.any((l) => k.character!.toLowerCase() == l)))) {
      return;
    }
    gameState.pressLetter(k.character!.toLowerCase());
  }
}
enum PageState {
  playing,
  reviewing,
}