#!/usr/bin/env python3
"""Download colour pictures for every emoji on theOne's emoji page.

Qt 5.6 on Sailfish cannot draw colour emoji fonts, so theOne shows pictures
instead. They come from Google's Noto Emoji (Apache License 2.0):
https://github.com/googlefonts/noto-emoji (3D/png/72).

    python3 scripts/fetch_emoji.py

Writes qml/org/theone/keyboard/emoji/<codepoints>.png, named the way
Keyboard.qml looks them up (see emojiFile() in Layouts.js).
"""
import os
import re
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LAYOUTS = os.path.join(ROOT, "qml", "org", "theone", "keyboard", "Layouts.js")
OUT = os.path.join(ROOT, "qml", "org", "theone", "keyboard", "emoji")
URL = "https://raw.githubusercontent.com/googlefonts/noto-emoji/main/3D/png/72/emoji_u%s.png"


def name(e):
    # Same rule as emojiFile() in Layouts.js: code points in hex, no FE0F, joined by "_".
    return "_".join("%04x" % ord(c) for c in e if ord(c) != 0xFE0F)


src = open(LAYOUTS, encoding="utf-8").read()
emoji = []
for block in re.findall(r'(?:icon|list): "([^"]*)"', src):
    for e in block.split(" "):
        if e and e not in emoji:
            emoji.append(e)

os.makedirs(OUT, exist_ok=True)
opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
missing = []
for e in emoji:
    n = name(e)
    path = os.path.join(OUT, n + ".png")
    if os.path.exists(path):
        continue
    try:
        data = opener.open(URL % n, timeout=30).read()
    except Exception:
        missing.append(e)
        continue
    with open(path, "wb") as f:
        f.write(data)

print("%d emoji, %d missing: %s" % (len(emoji), len(missing), " ".join(missing)))
sys.exit(1 if missing else 0)
