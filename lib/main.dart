import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:word_flower/played_game.dart';

import 'game_info.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  final int state = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Word Flower',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Word Flower'),
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
  String _lettersToAttempt = '';
  PageState _pageState = PageState.playing;

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
    _box = await Hive.openBox<PlayedGame>('gamesBox');
    var dateSeed = DateTime.now().toUtc();
    var m = dateSeed.year+dateSeed.day+dateSeed.month;
    await loadGame(m, false);
  }

  Future<void> loadGame(int seed, bool isPractice) async {
    var gs = await GameState.createGame(seed, _box, isPractice);

    setState(() {
      _lettersToAttempt = '';
      _gameState = gs;
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

    yield const Padding(
        padding: EdgeInsets.all(12),
        child: Text("Common words (included in max score)", style: big,));

    yield getGridView(commonWords, _gameState!.obtainedWords);

    yield const Padding(
        padding: EdgeInsets.fromLTRB(12, 50, 12, 12),
        child: Text("Uncommon words", style: big,));

    yield getGridView(uncommonWords, _gameState!.obtainedWords);

    yield Padding(
        padding: const EdgeInsets.all(20),
        child: TextButton(
          onPressed: () => setState(() {_pageState = PageState.playing;}),
          child: const Text('Back to game..'),
        ));

  }

  static GridView getGridView(List<String> allWords, List<String> obtainedWords) {
    return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: allWords.length,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          mainAxisSpacing: 2,
          childAspectRatio: 5,
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
                        color: isFound ? Colors.green : Colors.black,
                        ),
                        title: Text(allWords[index]),
            ),
          );
        },
      );
  }


  Iterable<Widget> getAllPlayingWidgets(ThemeData theme) sync* {
    if (_gameState == null) {
      yield const Text('loading..');
      return;
    }

    const boldStyle = TextStyle(fontWeight: FontWeight.bold);
    const wordsStyle = TextStyle(fontSize: 16);
    const titleStyle = TextStyle(fontSize: 20);

    yield const Text('How many words can you get?', style: titleStyle,);

    const edgeInsets = EdgeInsets.all(8.0);

    // yield Row(
    //     crossAxisAlignment: CrossAxisAlignment.center,
    //     mainAxisAlignment: MainAxisAlignment.center,
    //     children: [

    yield Padding(
        padding: edgeInsets,
        child: Text(_gameState?.obtainedWords.join(" — ")??'', style: wordsStyle, textAlign: TextAlign.center),
    );
    yield Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text('Score: ${_gameState?.score?.toString()??'0'} ${(_gameState?.isReviewed??false)? ' (Finished)':''}', style: boldStyle)
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

    var buttonBackground = theme.floatingActionButtonTheme.backgroundColor;
    var disabledButtonBackground = theme.floatingActionButtonTheme.backgroundColor?.withOpacity(0.5);
    var buttonColor = theme.floatingActionButtonTheme.foregroundColor ?? theme.colorScheme.primary;
    var disabledButtonColor = (theme.floatingActionButtonTheme.foregroundColor ?? theme.colorScheme.primary).withOpacity(0.5);

    const circleBorder = CircleBorder();
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
                child: FloatingActionButton(
                  shape: circleBorder,
                  backgroundColor: _lettersToAttempt.isNotEmpty
                      ? buttonBackground
                      : disabledButtonBackground,
                  foregroundColor: _lettersToAttempt.isNotEmpty
                      ? buttonColor
                      : disabledButtonColor,
                  onPressed: _lettersToAttempt.isNotEmpty
                      ? () => setState(() { _lettersToAttempt = _lettersToAttempt.substring(0, _lettersToAttempt.length - 1); })
                      : null,
                  child: const Icon(Icons.backspace),
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
              child: FloatingActionButton(
                  onPressed: () => setState((){
                    _gameState?.shuffleAndSetLetters();
                  }),
                  shape: circleBorder,
                  child: const Icon(Icons.recycling_rounded))),
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
          // actions: [],
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
                _pageState = PageState.playing;
                await loadGame(DateTime.now().millisecond, true);
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