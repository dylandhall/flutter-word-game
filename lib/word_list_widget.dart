
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class WordListWidget extends StatelessWidget {
  final List<String> words;
  final ValueNotifier<String?> incorrectWordNotifier;

  const WordListWidget(this.words, this.incorrectWordNotifier, {super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(children: getWordsWithSpacers().toList());
  }

  Iterable<Widget> getWordsWithSpacers() sync* {
    bool first = true;
    for(final w in words){
      if (!first) yield const Text(' ⇨ ');
      yield WordEntry(incorrectWordNotifier: incorrectWordNotifier, word: w);
      first = false;
    }
  }
}

class WordEntry extends StatefulWidget {
  const WordEntry({super.key, required this.incorrectWordNotifier, required this.word});

  final ValueNotifier<String?> incorrectWordNotifier;
  final String word;

  @override
  State<StatefulWidget> createState() => _WordEntry();
}

class _WordEntry extends State<WordEntry> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  void startAnimation(){
    if (widget.word != widget.incorrectWordNotifier.value) return;
    _controller.forward();
  }

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _animation = Tween<double>(begin: 1, end: 2.5).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    )..addStatusListener(statusListener);

    widget.incorrectWordNotifier.addListener(startAnimation);
  }

  void statusListener(AnimationStatus status) {
    if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
      if (status == AnimationStatus.dismissed) {
        widget.incorrectWordNotifier.value = null;
        _controller.stop();
        return;
      }
      _controller.reverse();
    }
  }
  @override
  void dispose() {
    _controller.dispose();
    widget.incorrectWordNotifier.removeListener(startAnimation);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    const wordsStyle = TextStyle(fontSize: 16);
    return AnimatedBuilder(
        animation: _animation,
        child: Text(widget.word, style: wordsStyle,),
        builder: (context, child) {
          return Transform.scale(
            scale: _animation.value,
            child: child,);
        });
  }
}
