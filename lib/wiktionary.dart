import 'dart:convert';
import 'package:http/http.dart' as http;

class WiktionaryApi {
  static Future<String> getDefinition(String word) async {
    final url = Uri.parse('https://en.wiktionary.org/w/api.php?action=query&format=json&prop=extracts&titles=$word&formatversion=latest&exchars=500&explaintext=1');
    print(url);
    final response = await http.get(url);

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

}
