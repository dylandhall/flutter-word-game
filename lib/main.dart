import 'package:flutter/material.dart';

import 'package:word_flower/game_state_manager.dart';
import 'package:word_flower/main_game_page.dart';


void main() {
  runApp(MyApp());
}


class MyApp extends StatelessWidget {
  final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
  late final GameStateManager gameStateManager;
  MyApp({super.key}){
    gameStateManager = GameStateManager(themeNotifier: themeNotifier);
  }

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
          home: MainGamePage(title: 'Word Finder 3000', themeNotifier: themeNotifier, gameStateManager: gameStateManager,),
      )
    );
  }
}