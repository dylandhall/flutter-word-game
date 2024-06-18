import 'dart:convert';
import 'package:async/async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class DefinitionLookupState extends ChangeNotifier {
  String? word;
  bool isLoading = false;
  String? definition;
  CancelableOperation<String>? _operation;
  bool get isRunning => _operation != null && !_operation!.isCanceled && !_operation!.isCompleted;

  @override
  void dispose() {
    if (isRunning){
      _operation!.cancel();
    }
    _operation = null;
    super.dispose();
  }

  void loadDefinition(String word) {
    this.word = word;
    isLoading = true;
    notifyListeners();
    WidgetsBinding.instance.addPostFrameCallback((v) { getDefinition(); });
  }


  Future<void> _openInNewTab(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)){
      final res = await launchUrl(uri, webOnlyWindowName: '_blank',);
      if (!res){
        print('problem launching url $url');
      }
    }
    dismissDefinition();
  }

  Future<void> getDefinition() async {
    if (word == null) {
      if (isLoading) {
        isLoading = false;
        notifyListeners();
      }
      return;
    }

    if (kIsWeb){
      await _openInNewTab(_getWebUrl(word!));
      return;
    }

    if (isRunning) {
      _operation!.cancel();
    }

    _operation = CancelableOperation.fromFuture(_getDefinition(word!));

    definition = await _operation!.value;
    isLoading = false;
    _operation = null;
    notifyListeners();
  }

  Future<String> _getDefinition(String word) async {
    final url = Uri.parse(_getUrl(word));
    var response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final pages = data['query']['pages'];
      final page = pages.first;

      if (page.containsKey('extract') && page['extract'].isNotEmpty) {
        return page['extract'];
      } else {
        return 'No definition found.';
      }
    } else {
      return 'Error fetching definition.';
    }
  }

  static String _getUrl(String word) => 'https://en.wiktionary.org/w/api.php?action=query&format=json&prop=extracts&titles=$word&formatversion=latest&exchars=1000&explaintext=1';
  // using mobile view as it's much cleaner, even on desktop
  static String _getWebUrl(String word) => 'https://en.m.wiktionary.org/wiki/$word';

  void dismissDefinition() {
    if (isRunning) {
      _operation!.cancel();
    }
    _operation = null;
    isLoading = false;
    word = null;
    definition = null;
    notifyListeners();
  }

  @override
  String toString() {
    if (word == null) return '';

    if (definition == null) {
      if (isLoading) {
        return '\n\n$word - loading..\n\n';
      }
      return word!;
    }

    return '$word\n\n$definition';
  }
}