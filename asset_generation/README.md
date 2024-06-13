## Dictionary files

I likely won't use all of these but while I'm still preparing the final lists I want to keep track of where they came from.

* [Google 10000 English](https://github.com/first20hours/google-10000-english)
* [Dolph's dictionary files](https://github.com/dolph/dictionary)
* [gwicks.net - just words!](http://www.gwicks.net/dictionaries.htm)

These lists either had no licensing information or explicitly stated they are free to use.

The lists in the `assets` folder are created from combining these lists into two lists, one of more common words, one of less common words, so I can support uncommon words (there are still plenty I know) without making the top score unobtainable. I figured also supporting both UK and US spelling would be fine, no one minds getting words twice for free.  

I used this C# program to produce the final word lists:

```
var commonWords = new string[] {
  @"C:\code\wordgame\asset_generation\google-10000-english.txt",
  @"C:\code\wordgame\asset_generation\popular.txt",
  @"C:\code\wordgame\asset_generation\english2.txt",
  @"C:\code\wordgame\asset_generation\usa.txt"
};

var lessCommonWords = new [] {
  @"C:\code\wordgame\asset_generation\english3.txt", 
  @"C:\code\wordgame\asset_generation\engmix.txt",
  @"C:\code\wordgame\asset_generation\ukenglish.txt", 
  @"C:\code\wordgame\asset_generation\usa2.txt"
};

var commonWordsSet = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
var uncommonWordsSet = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

foreach (var list in commonWords)
{
  commonWordsSet.UnionWith(await File.ReadAllLinesAsync(list));
}

foreach (var list in lessCommonWords)
{
  uncommonWordsSet.UnionWith(await File.ReadAllLinesAsync(list));
}

var nonAlpha = new Regex(@"[^\w]");

var finalCommonWords = commonWordsSet
	.Where(w => w.Length > 3 && !nonAlpha.IsMatch(w))
	.Select(w => w.ToLower())
	.OrderBy(w => w)
	.ToList();

var finalUncommonWords = uncommonWordsSet
	.Where(w => w.Length > 3 && !nonAlpha.IsMatch(w))
	.Except(commonWordsSet, StringComparer.OrdinalIgnoreCase)
	.Select(w => w.ToLower())
	.OrderBy(w => w)
	.ToList();

await File.WriteAllLinesAsync(@"C:\code\wordgame\assets\common-long-words.txt", finalCommonWords);
await File.WriteAllLinesAsync(@"C:\code\wordgame\assets\uncommon-long-words.txt", finalUncommonWords);
```