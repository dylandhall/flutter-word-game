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

Later on I found the google 10000 most common words actually includes a lot of proper nouns and porn sites, so I created a list of words that would be removed, so I could whitelist them:

```
var veryCommon = @"C:\code\wordgame\asset_generation\google-10000-english.txt";

var allOtherWords = new string[] {
  @"C:\code\wordgame\asset_generation\popular.txt",
  @"C:\code\wordgame\asset_generation\english2.txt",
  @"C:\code\wordgame\asset_generation\usa.txt",
  @"C:\code\wordgame\asset_generation\english3.txt",
  @"C:\code\wordgame\asset_generation\engmix.txt",
  @"C:\code\wordgame\asset_generation\ukenglish.txt",
  @"C:\code\wordgame\asset_generation\usa2.txt"
};

var allLines = await File.ReadAllLinesAsync(veryCommon);

var googleWords = allLines
	.Where(w => w.Length > 3 && !nonAlpha.IsMatch(w))
	.Select(w => w.ToLower())
	.OrderBy(w => w)
	.ToList();

var commonWordsSet = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

foreach (var list in allOtherWords)
{
	commonWordsSet.UnionWith(await File.ReadAllLinesAsync(list));
}

var nonAlpha = new Regex(@"[^\w]");

var validOtherWords = commonWordsSet
	.Where(w => w.Length > 3 && !nonAlpha.IsMatch(w))
	.Select(w => w.ToLower())
	.OrderBy(w => w)
	.ToList();


var invalidGoogleWords = googleWords.Except(validOtherWords, StringComparer.OrdinalIgnoreCase).ToList();

await File.WriteAllLinesAsync(@"C:\code\wordgame\asset_generation\whitelisted-google-words.txt", invalidGoogleWords);
await File.WriteAllLinesAsync(@"C:\code\wordgame\asset_generation\invalid-google-words.txt", invalidGoogleWords);
```

Then I went through and deleted all the ones I didn't want to keep in the whitelist file, leaving the ones I'd be annoyed if I found but weren't "real words". 

The main one that convinced me I needed to do this was "inbox" - I know, it's supposed to be hyphenated, but in the year 2024 it's such a common term it just seems wrong to not give credit. Same for things like screensaver.

Then I used those lists to remove the garbage from the main common word files, and additionally add a very common word file, which will be used to ensure randomly generating a game includes a certain number of familiar words:

```
var commonWordsFilename = @"C:\code\wordgame\assets\common-long-words.txt";

var existingCommonWordFile = await File.ReadAllLinesAsync(commonWordsFilename);
var google10KFile = await File.ReadAllLinesAsync(@"C:\code\wordgame\asset_generation\google-10000-english.txt");

var whitelistedFile = await File.ReadAllLinesAsync(@"C:\code\wordgame\asset_generation\whitelisted-google-words.txt");
var toRemoveFile = await File.ReadAllLinesAsync(@"C:\code\wordgame\asset_generation\invalid-google-words.txt");

toRemoveFile = toRemoveFile.Except(whitelistedFile, StringComparer.OrdinalIgnoreCase).ToArray();

var nonAlpha = new Regex(@"[^\w]");

var updatedCommonWords = existingCommonWordFile.Except(toRemoveFile, StringComparer.OrdinalIgnoreCase)
	.OrderBy(w => w)
	.ToList();

var googleWords = google10KFile
	.Where(w => w.Length > 3 && !nonAlpha.IsMatch(w))
	.Select(w => w.ToLower())
	.Except(toRemoveFile, StringComparer.OrdinalIgnoreCase)
	.OrderBy(w => w)
	.ToList();

await File.WriteAllLinesAsync(@"C:\code\wordgame\assets\very-common-long-words.txt", googleWords);

await File.WriteAllLinesAsync(commonWordsFilename, updatedCommonWords);
```