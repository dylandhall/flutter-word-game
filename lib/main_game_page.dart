
import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:word_flower/hint_page.dart';
import 'package:word_flower/wiktionary.dart';
import 'package:word_flower/word_list_widget.dart';

import 'game_state_manager.dart';

class MainGamePage extends StatefulWidget {
  const MainGamePage({super.key, required this.title, required this.themeNotifier, required this.gameStateManager});

  final String title;
  final ValueNotifier<ThemeMode> themeNotifier;
  final GameStateManager gameStateManager;

  @override
  State<MainGamePage> createState() => _MainGamePageState();
}

class _MainGamePageState extends State<MainGamePage> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _offsetAnimation;
  final ConfettiController _confettiController = ConfettiController(duration: const Duration( seconds: 1));
  late int _repeatCount = 0;
  late final FocusNode _focusNode;
  final incorrectWordNotifier = ValueNotifier<String?>(null);
  final _hintLevelNotifier = ValueNotifier<int>(1);

  PageState _pageState = PageState.playing;
  late bool _isDarkMode = false;
  OverlayEntry? _overlayEntry;
  final DefinitionLookupState _lookupState = DefinitionLookupState();

  _MainGamePageState();

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.themeNotifier.value == ThemeMode.dark;
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

    widget.themeNotifier.addListener(themeUpdate);

    _isDarkMode = widget.themeNotifier.value == ThemeMode.dark;
    _lookupState.addListener(_overlayListener);
    widget.gameStateManager.initLoad();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    // not required, just testing
    _offsetAnimation.removeStatusListener(statusListener);
    widget.themeNotifier.removeListener(themeUpdate);
    _lookupState.removeListener(_overlayListener);
    _lookupState.dispose();
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
    _confettiController.dispose();
    super.dispose();
  }


  void _overlayListener(){
    _showOverlay(context, _lookupState);
  }

  void _showOverlay(BuildContext context, DefinitionLookupState definition) {
    if (_overlayEntry != null ) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }

    if (definition.word == null) {
      return;
    }

    Navigator.of(context).overlay!.insert(_overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: _dismissOverlay,
            child: Container(
              color: Colors.black87,
              child: SingleChildScrollView(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(80),
                    child: Text(definition.toString(), style: const TextStyle(color: Colors.white70, fontSize: 14),),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ));
  }

  _dismissOverlay() {
    _lookupState.dismissDefinition();
  }


  void themeUpdate() {
    _isDarkMode = widget.themeNotifier.value == ThemeMode.dark;
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
      case PageState.hint:
        return getAllHintWidgets(theme, gameState).toList();
    }
  }

  Iterable<Widget> getAllHintWidgets(ThemeData theme, GameStateManager gameState) sync* {


    yield Padding(
        padding: const EdgeInsets.all(12),
        child: TextButton(
          onPressed: () => setState(() { _pageState = PageState.playing; }),
          child: const Text('Back to game..'),
        ));

    yield HintPage(themeNotifier: widget.themeNotifier, gameStateManager: widget.gameStateManager, hintLevelNotifier: _hintLevelNotifier,);


    if (_hintLevelNotifier.value<4) {
      yield ValueListenableBuilder(
        valueListenable: _hintLevelNotifier,
        child: Padding(
            padding: const EdgeInsets.all(12),
            child:
            TextButton(
              onPressed: () => _hintLevelNotifier.value++,
              child: const Text('Next hint'),
            ),
          ),
        builder: (context, value, child) => (value < 4 ? child! : const Text('')),
      );
    }

    yield Padding(
        padding: const EdgeInsets.all(12),
        child: TextButton(
          onPressed: () => setState(() { _pageState = PageState.playing; }),
          child: const Text('Back to game..'),
        ));

  }

  Iterable<Widget> getAllReviewingWidgets(ThemeData theme, GameStateManager gameState) sync* {
    if (gameState.isLoading) {
      yield const Text('loading..');
      return;
    }

    var numParticles = widget.gameStateManager.score >= widget.gameStateManager.possibleScore
        ? 50
        : widget.gameStateManager.score >= (widget.gameStateManager.possibleScore / 2)
          ? 20
          : 0;

    if (numParticles>0) {
      yield ConfettiWidget(
        confettiController: _confettiController,
        blastDirectionality: BlastDirectionality.directional,
        blastDirection: pi / 2,
        maxBlastForce: 5,
        minBlastForce: 2,
        emissionFrequency: 0.05,
        numberOfParticles: numParticles,
        gravity: 0.1,
      );
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

    yield getGridView(commonWords, gameState.obtainedWords, _isDarkMode, _lookupState);

    final uncommonPercent = ((uncommonWords.where((w) => gameState.obtainedWords.contains(w)).length)
        / uncommonWords.length * 100).round();

    yield Padding(
        padding: const EdgeInsets.fromLTRB(12, 50, 12, 12),
        child: Text("Uncommon words - $uncommonPercent%", style: big,));

    yield getGridView(uncommonWords, gameState.obtainedWords, _isDarkMode, _lookupState);

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

  static Widget getGridView(List<String> allWords, List<String> obtainedWords, bool isDarkMode, DefinitionLookupState lookupState) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: ColumnOrderedGrid(allWords: allWords, isDarkMode: isDarkMode, lookupState: lookupState, obtainedWords: obtainedWords,)
    );
  }

  static const String _gameKey = 'game-panel';

  Iterable<Widget> getAllPlayingWidgets(ThemeData theme, GameStateManager gameState) sync* {
    if (gameState.isLoading) {
      yield const Padding(padding: EdgeInsets.fromLTRB(0, 80, 0, 0),
          child: Image(image: AssetImage('assets/word-flower-image.webp'),
            height: 256,
            fit: BoxFit.fitHeight,));
      return;
    }

    const boldStyle = TextStyle(fontWeight: FontWeight.bold);
    const titleStyle = TextStyle(fontSize: 20);

    yield const Padding(padding: EdgeInsets.only(top: 18),
        child: Text('How many words can you get?', style: titleStyle,));

    const edgeInsets = EdgeInsets.all(8.0);

    yield Padding(
        padding: edgeInsets,
        child: GestureDetector(
          onTap: () {
            setState(() {
              widget.gameStateManager.toggleSort();
            });
          },
          child: WordListWidget(gameState.obtainedWords, incorrectWordNotifier),
        )


    );

    var info = (gameState.isReviewed)
        ? ' (Finished)'
        : (gameState.isPractice)
        ? ' (Practice)'
        : '';



    yield ConfettiWidget(
      confettiController: _confettiController,
      blastDirectionality: BlastDirectionality.explosive,
      numberOfParticles: 25,
    );

    yield RepaintBoundary(
      key: const ValueKey(_gameKey),
      child: Column(
          children:[
            Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('Score: ${gameState.score} of a possible ${(gameState.possibleScore)} $info', style: boldStyle)
            ),
            Padding(
                padding: edgeInsets,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: getLetterButtonWidgets(theme, gameState).toList(),
                )
            )]
      ),
    );

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
                  onPressed: gameState.isValidToAttempt ? (){ attemptLettersAndAnimate(gameState); } : null,
                  child: Text('Check', style: TextStyle(color: (gameState.isValidToAttempt
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
                        gameState.setAsReviewed();
                        _pageState = PageState.reviewing;
                        var scoreMessage = gameState.possibleScore <= gameState.score
                          ? 'Great score!'
                          : 'Good score';
                        if (gameState.possibleScore / 2 <= gameState.score) {
                          WidgetsBinding.instance.addPostFrameCallback((_) => _confettiController.play());
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Center(child: Text(scoreMessage))));
                        }
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

    yield Padding(
        padding: const EdgeInsets.all(20.0),
        child: TextButton(
          onPressed: () { setState(() => _pageState = PageState.hint); },
          child: const Text('Hints'),
      ),
    );
  }

  Iterable<Widget> getLetterButtonWidgets(ThemeData theme, GameStateManager gameState) sync* {
    const edgeInsets = EdgeInsets.all(4.0);
    const circleBorder = CircleBorder();

    yield Column(mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: gameState.lettersToShow.take(2).map((letter) =>
          Padding(
              padding: edgeInsets,
              child: FloatingActionButton(
                heroTag: '$letter-letter',
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
              heroTag: '${gameState.lettersToShow[2]}-letter',
              onPressed: () => gameState.pressLetter(gameState.lettersToShow[2]),
              shape: circleBorder,
              child: Text(gameState.lettersToShow[2].toUpperCase()))),
        Padding(
            padding: edgeInsets,
            child: FloatingActionButton(
              heroTag: 'center-letter',
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
                heroTag: '${gameState.lettersToShow[3]}-letter',
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
                  heroTag: '$letter-letter',
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
                    widget.themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
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
                    )
                ),
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
                    _hintLevelNotifier.value = 1;
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

    switch (k.logicalKey) {
      case LogicalKeyboardKey.enter:
        attemptLettersAndAnimate(gameState);
        return;
      case LogicalKeyboardKey.backspace:
        gameState.backspace();
        return;
      case LogicalKeyboardKey.backspace:
        gameState.backspace();
        return;
      case LogicalKeyboardKey.delete:
        gameState.clearLetters();
        return;
    }
    if (k.character == null || !(k.character == gameState.centerLetter || (gameState.lettersToShow.any((l) => k.character!.toLowerCase() == l)))) {
      return;
    }
    gameState.pressLetter(k.character!.toLowerCase());
  }

  void attemptLettersAndAnimate(GameStateManager gameState) {
    if (!gameState.isValidToAttempt) return;

    if (gameState.obtainedWords.contains(gameState.lettersToAttempt)){
      incorrectWordNotifier.value = gameState.lettersToAttempt;
      startIncorrectAnim();
      return;
    }

    var isAllLetters = gameState.isAllLetters;
    var res = gameState.attemptLetters();
    if (res) {
      if (isAllLetters) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Center(child: Text('Every letter! 👖')), duration: Duration(seconds: 2),));
        _confettiController.play();
      }
      return;
    }
    startIncorrectAnim();
  }

  void startIncorrectAnim() {
    // animate the shake of the input fields
    _repeatCount = 0; // Reset the repeat count before starting the animation
    _controller.reset();
    _controller.forward();
  }
}


enum PageState {
  playing,
  reviewing,
  hint,
}



class ColumnOrderedGrid extends StatelessWidget {
  final List<String> allWords;
  final bool isDarkMode;
  final DefinitionLookupState lookupState;
  final List<String> obtainedWords;

  const ColumnOrderedGrid({super.key, required this.allWords, required this.isDarkMode, required this.lookupState, required this.obtainedWords});

  @override
  Widget build(BuildContext context) {
    return
      LayoutBuilder(
        builder: (context, constraints) {
          const columnWidth = 180;
          var columns = (constraints.maxWidth / columnWidth).floor();
          if (columns<1) columns = 1;
          final rows = (allWords.length / columns).ceil();

          final gridWidth = columns * columnWidth.toDouble();
          return SingleChildScrollView(
              child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: gridWidth,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(columns, (i) =>
                    Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: allWords.skip(i*rows).take(rows).map((w) =>
                          WordItem(
                              isFound: obtainedWords.contains(w),
                              word: w,
                              isDarkMode: isDarkMode,
                              lookupState: lookupState)).toList()
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
  }
}

class WordItem extends StatelessWidget {
  final bool isFound;
  final String word;
  final bool isDarkMode;
  final DefinitionLookupState lookupState;

  const WordItem({super.key, required this.isFound, required this.word, required this.isDarkMode, required this.lookupState});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 2, 2, 6),
        child: Align(
          alignment: Alignment.centerLeft,
          child: InkWell(
            onTap: () => lookupState.loadDefinition(word),
            //titleAlignment: ListTileTitleAlignment.top,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Icon(
                  isFound
                      ? CupertinoIcons.checkmark_seal_fill
                      : CupertinoIcons.xmark_seal_fill,
                  color: isFound ? Colors.green : isDarkMode
                      ? Colors.white30
                      : Colors.black38,
                ),
                Padding(
                    padding: const EdgeInsets.only(left:8),
                    child: Text(word, textAlign: TextAlign.start)
                )],
            ),
          ),
        ),
      ),
    );
  }
}
