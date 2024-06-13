import 'package:flutter/services.dart' show rootBundle;
import 'package:hive/hive.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:word_flower/played_game.dart';
import 'dart:math';
import 'package:word_flower/rng.dart';

class GameState {
  final List<String> extraLetters;
  final String centerLetter;
  final List<String> validWords;
  final List<String> commonWords;
  final PlayedGame playedGame;
  final int seed;
  bool isReviewed = false;
  final bool isPractice;

  List<String> lettersToShow = List.empty();

  final List<String> obtainedWords = List.empty(growable: true);

  setAsReviewed(){
    isReviewed = true;
    if (!playedGame.reviewed && playedGame.isInBox){
      playedGame.reviewed = true;
      playedGame.save();
    }
  }

  get score => obtainedWords.isNotEmpty
    ? obtainedWords.map((w) => w.length).reduce((acc,v) => acc+v)
    : 0;
  get possibleScore => commonWords.isNotEmpty
    ? commonWords.map((w) => w.length).reduce((acc,v) => acc+v)
    : 0;

  void shuffleAndSetLetters(){
    var r = Random();
    var a = extraLetters.map((l) => (l:l, v: r.nextDouble())).toList();
    a.sort((a,b) => a.v.compareTo(b.v));
    lettersToShow = a.map((l) => l.l).toList();
  }

  GameState.name(this.extraLetters, this.centerLetter, this.validWords, this.commonWords, this.playedGame, this.isPractice, this.seed);

  bool checkLetters(String letters) {
    if (!letters.contains(centerLetter)) return false;
    if (validWords.contains(letters) && !obtainedWords.contains(letters)){
      obtainedWords.add(letters);
      playedGame.obtainedWords = obtainedWords;
      playedGame.save();
      return true;
    }
    return false;
  }

  static Future<GameState> createGame(int seed, Box<PlayedGame>? box, bool isPractice) async {
    var largeDictionaryFuture = StoredDictionary.createDictionary('assets/uncommon-long-words.txt');
    var commonDictionary = await StoredDictionary.createDictionary('assets/common-long-words.txt');

    const practiceGameKey = 101;

    if (box?.isNotEmpty??false) {
      // clean out old games so we don't have too many
      if (box!.length>10){
        var cutoff = DateTime.now().subtract(const Duration(days: 7));
        for (final oldGame in box.values) {
          if (oldGame.reviewed && (oldGame.datePlayed == null || cutoff.millisecondsSinceEpoch > oldGame.datePlayed!.millisecondsSinceEpoch)) {
            oldGame.delete();
          }
        }
      }

      var existingPg = isPractice
          ? box.get(practiceGameKey)
          : box.get(seed);

      if (existingPg != null && ((isPractice && !existingPg.reviewed) || existingPg.seed == seed)) {
        var largeDictionary = await largeDictionaryFuture;

        var commonWords = getMatchingWords(commonDictionary.words, existingPg.extraLetters, existingPg.centerLetter);
        var validWords = getMatchingWords(largeDictionary.words, existingPg.extraLetters, existingPg.centerLetter);

        Set<String> allWords = Set.from(validWords);
        allWords.addAll(commonWords);
        validWords = allWords.toList();

        var gameState = GameState.name(existingPg.extraLetters, existingPg.centerLetter, validWords, commonWords, existingPg, isPractice, seed);
        gameState.shuffleAndSetLetters();
        gameState.obtainedWords.addAll(existingPg.obtainedWords);
        gameState.isReviewed = existingPg.reviewed;

        return gameState;
      }
    }

    var r = LinearCongruentialGenerator(seed);


    var letters = List.generate(26, (i) => String.fromCharCode('a'.codeUnitAt(0) + i));

    var vowels = ['a', 'e', 'i', 'o', 'u'];

    var letterCounts = {for (var l in letters) l: commonDictionary.words.expand((c) => c.split('')).where((c) => c == l).length};

    var orderedLetters = letterCounts.entries.toList();

    orderedLetters.sort((a, b) => b.value.compareTo(a.value));

    var centerLetter = '';
    var otherLetters = List.filled(6, 'a');
    var includedCommonWords = List<String>.empty();
    do {
      centerLetter = orderedLetters[((r.nextDouble() - 0.5).abs() * 26)
          .toInt()].key;

      otherLetters = List.filled(6, 'a');

      int index = 0;
      if (!vowels.contains(centerLetter)) {
        otherLetters[index++] =
        vowels[(r.nextDouble() * (vowels.length - 1)).round()];
      }

      for (; index < 6; index++) {
        var prevLetters = otherLetters.take(index).toList();
        do {
          otherLetters[index] = letters[(r.nextDouble() * 25).round()];
        } while (otherLetters[index] == centerLetter || (index > 0 && prevLetters.contains(otherLetters[index])));
      }
      includedCommonWords = getMatchingWords(commonDictionary.words, otherLetters, centerLetter);
    } while (includedCommonWords.length < 8
      //|| otherLetters.any((l) => !includedCommonWords.any((w) => w.contains(l))) // all letters used
      || !includedCommonWords.any((w) => w.contains(centerLetter) && !otherLetters.any((l) => !w.contains(l))) // at least one word with all letters
    );

    var largeDictionary = await largeDictionaryFuture;

    var validWords = getMatchingWords(largeDictionary.words, otherLetters, centerLetter);

    Set<String> allWords = Set.from(validWords);
    allWords.addAll(includedCommonWords);
    validWords = allWords.toList();

    var pg = PlayedGame(seed: seed, reviewed: false, obtainedWords: List<String>.empty(), centerLetter: centerLetter, extraLetters: otherLetters, datePlayed: DateTime.now().toUtc());
    box?.put(isPractice ? practiceGameKey : seed, pg);

    if (pg.isInBox) pg.save();

    var gameState = GameState.name(otherLetters, centerLetter, validWords, includedCommonWords, pg, isPractice, seed);
    gameState.shuffleAndSetLetters();

    return gameState;
  }

  static List<String> getMatchingWords(List<String> wordList, List<String> extraLetters, String centerLetter){
    centerLetter = centerLetter.toLowerCase();
    extraLetters = extraLetters.map((l) => l.toLowerCase()).toList();
    return wordList
        .map((w) => w.toLowerCase())
        .where((w) => w.contains(centerLetter) &&
                      w.split('').every((c) => c == centerLetter || extraLetters.contains(c)))
        .toList();
  }
}

class StoredDictionary {
  late final List<String> words;

  StoredDictionary(String data) {
    words = data.replaceAll('\r', '').split('\n');
  }

  static Future<StoredDictionary> createDictionary(String filename) async {
    String data = await rootBundle.loadString(filename);
    return StoredDictionary(data);
  }
}

