# Word list data

`en_50k.txt` is the English 50k frequency list from
[hermitdave/FrequencyWords](https://github.com/hermitdave/FrequencyWords)
(`content/2018/en/en_50k.txt`, built from OpenSubtitles 2018), by Hermit Dave.
Licensed under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).

`scripts/build_words.py` turns it into `qml/org/theone/keyboard/Words.js` (rejoined
contractions, fragments removed, `blocklist.txt` words kept out of suggestions).
`Words.js` is an adaptation and is shared under the same licence.
