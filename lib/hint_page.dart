import 'package:flutter/material.dart';

import 'game_state_manager.dart';

class HintPage extends StatefulWidget {

  final ValueNotifier<ThemeMode> themeNotifier;
  final GameStateManager gameStateManager;
  final ValueNotifier<int> hintLevelNotifier;

  const HintPage({super.key, required this.themeNotifier, required this.gameStateManager, required this.hintLevelNotifier});

  @override
  State<HintPage> createState() => _HintPage();
}

class _HintPage extends State<HintPage> {

  Iterable<Widget> getHints() sync* {

    const bold = TextStyle(fontWeight: FontWeight.bold);

    var lettersWithCounts = widget.gameStateManager.lettersToShow
        .map((l) => (count: widget.gameStateManager.validWords.where((w) => w[0] == l).length, letter:l, isCenter: false))
        .toList();

    lettersWithCounts.add((count:widget.gameStateManager.validWords
        .where((w) => w[0] == widget.gameStateManager.centerLetter)
        .length, letter: widget.gameStateManager.centerLetter, isCenter: true));

    lettersWithCounts.sort((a, b) => b.count - a.count);

    yield getLettersWithCountsTable('Starting letter frequency:', lettersWithCounts, bold);

    var letters = lettersWithCounts.map((l) => l.letter).toList();

    var gridData = List.generate(letters.length, (i) => List<int>.filled(letters.length, 0));

    for (int i = 0; i < letters.length; i++) {
      for (int j = 0; j < letters.length; j++) {
        gridData[i][j] = widget.gameStateManager.validWords
            .where((w) => w.startsWith('${letters[i]}${letters[j]}'))
            .length;
      }
    }

    yield getWordStartFrequencyTable('Word Start Combinations:', letters, bold, gridData);


    lettersWithCounts = widget.gameStateManager.lettersToShow
        .map((l) => (count: widget.gameStateManager.validWords.where((w) => w[0] == l && !widget.gameStateManager.obtainedWords.contains(w)).length, letter:l, isCenter: false))
        .toList();

    lettersWithCounts.add((count:widget.gameStateManager.validWords
        .where((w) => w[0] == widget.gameStateManager.centerLetter && !widget.gameStateManager.obtainedWords.contains(w))
        .length, letter: widget.gameStateManager.centerLetter, isCenter: true));

    lettersWithCounts.sort((a, b) => b.count - a.count);


    yield getLettersWithCountsTable('Starting letter frequency in remaining words:', lettersWithCounts, bold);

    gridData = List.generate(letters.length, (i) => List<int>.filled(letters.length, 0));

    for (int i = 0; i < letters.length; i++) {
      for (int j = 0; j < letters.length; j++) {
        gridData[i][j] = widget.gameStateManager.validWords
            .where((w) => w.startsWith('${letters[i]}${letters[j]}') && !widget.gameStateManager.obtainedWords.contains(w))
            .length;
      }
    }

    yield getWordStartFrequencyTable('Word Start Combinations in remaining words:', letters, bold, gridData);
  }

  Center getWordStartFrequencyTable(String tableTitle, List<String> letters, TextStyle bold, List<List<int>> gridData) {
    return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(tableTitle)
        ),
        Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          children: [
            TableRow(
              children: [
                const SizedBox(), // Empty top-left cell
                ...letters.map((l) => Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.withOpacity(0.3)), // Faint grid lines
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child:Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Center(child: Text(l.toUpperCase(), style: bold)),
                    )
                  )
                ),
              ],
            ),
            for (int i = 0; i < letters.length; i++)
              TableRow(
                children: [
                  Container(
                    decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.withOpacity(0.3)), // Faint grid lines
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child:
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Center(child: Text(letters[i].toUpperCase(), style: bold,)), // Row header
                    )),
                  ...List.generate(letters.length, (j) =>
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.withOpacity(0.3)), // Faint grid lines
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Center(child: Text(gridData[i][j].toString())),
                       ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    ),
  );
  }

  static Center getLettersWithCountsTable(String tableTitle, List<({int count, bool isCenter, String letter})> lettersWithCounts, TextStyle bold) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(tableTitle)
          ),
          Table(
            columnWidths: const {
              0: IntrinsicColumnWidth(),
              1: IntrinsicColumnWidth(),
              2: IntrinsicColumnWidth(),
            },
            children: lettersWithCounts.map((v) =>
                TableRow(
                  children: [
                    TableCell(
                      child: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text('Letter', style: v.isCenter ? bold : null,),
                      ),
                    ),
                    TableCell(
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(v.letter.toUpperCase(), style: v.isCenter ? bold : null),
                      ),
                    ),
                    TableCell(
                      child: Container(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(v.count.toString(), style: v.isCenter ? bold : null),
                      ),
                    ),
                  ],
                )).toList(growable: false),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return
      ValueListenableBuilder(valueListenable: widget.hintLevelNotifier,
        builder: (context, value, child) => Column(children: getHints().take(value).toList()));
  }

}