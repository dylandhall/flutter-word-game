# Word flower

## Try it, compiled for web!

Click [here](https://dylandhall.github.io/flutter-word-game/) to play the game. It's actually super fun.

### Introduction

A new Flutter project. I'm just testing the framework out, this is a small game for my partner, based off an old puzzle book she had. I've added scoring to make it more fun.

Note, I understand Hive is superseded but I have very basic requirements - if you're using this as an example however, I'd use [Isar](https://pub.dev/packages/isar) instead.

In the `asset_generation` folder you'll find the word databases I used to produce my lists and links to the sources.

### Rules

Pretty simple, you just make as many words as you can with the letters provided. They need to be four or more letters, and the center letter MUST be used.

You get a point per letter - the max score is based on common words, but you can score points with uncommon words as well, they're just not in the stated maximum score. I didn't want people to be discouraged if they couldn't get close to the maximum score and some of the words in the larger dictionaries are esoteric to say the least.

There is at least one word that has every letter.

Good luck!

### Features

There is a new daily game in UTC time. It's not hosted on a server but I use a deterministic random number generator seeded with the UTC date to generate the game, so it'll be the same for everyone on a day.

It will remember your progress, and you can review it. Once reviewed you can't keep playing, but you can make a practice game. It'll remember the practice game you're doing and save your progress, once you've reviewed it you can make another one.

Eventually you'll be able to review previous days, the data is there but I haven't added it yet.
 
