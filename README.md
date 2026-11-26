# theOne

An iOS-style on-screen keyboard for Sailfish OS, built as a Maliit input method plugin.
Dark look matched to an iPhone keyboard screenshot (`preview/reference.png`).

- Solid rounded keys, magnified letter balloon while pressing
- Shift: tap for one capital, double-tap for caps lock; automatic capitals at sentence start
- Double space types ". "
- Long-press a letter for accents; long-press or drag the space bar to move the cursor
- English suggestion bar like iOS: the typed word in quotes, the autocorrection
  highlighted, and next-word predictions after a space
- Autocorrect on space, punctuation and return; backspace right after a correction
  undoes it, and the keyboard then keeps that word
- Learns your words and which word tends to follow which (kept in dconf at
  `/apps/theone-keyboard/learned`)
- No suggestions or autocorrect in password, URL, e-mail and number fields
- Number (`123`), symbol (`#+=`) and emoji pages
- No haptics, no voice input, no swipe typing

Tested on: the desktop preview and a fake-Maliit test harness. Not yet tested on a device.

## Build

The RPM is built on the `sfbuild` VM (Sailfish SDK, target SailfishOS-5.1.0.11):

```bash
scripts/build-rpm.sh
```

The RPM is written to `RPMS/`.

## Install and turn on

On the phone (developer mode on):

```bash
devel-su pkcon install-local theone-keyboard-0.2.0-1.aarch64.rpm
```

Then, as your normal user (not root):

```bash
theone-keyboard on
```

Back to the stock keyboard:

```bash
theone-keyboard off
```

If the keyboard ever fails to appear, run `theone-keyboard off` over SSH or from a
terminal with a hardware keyboard. Uninstalling the RPM also restores the stock keyboard.

## Develop

- `scripts/preview.sh` renders every keyboard state to `preview/out/` on the VM.
- `python3 scripts/compare.py` compares the letter page with the reference screenshot.
- `python3 scripts/build_words.py` regenerates `Words.js` from `data/en_50k.txt`.
- `tests/test_predict.qml` checks suggestions and autocorrect against common typos.
- `tests/test_plugin.qml` drives `plugin/theone.qml` against a fake Maliit server:

```bash
ssh sfbuild 'cd ~/src/theone/tests && QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software qmlscene -I fake -I ../qml test_plugin.qml'
ssh sfbuild 'cd ~/src/theone/tests && QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software qmlscene test_predict.qml'
```

## Layout

| Path | What |
|---|---|
| `plugin/theone.qml` | Maliit entry point, installed to `/usr/lib64/maliit/plugins/` |
| `qml/org/theone/keyboard/` | The keyboard module, installed to `/usr/share/maliit/plugins/` |
| `qml/org/theone/keyboard/Predict.js` | Suggestions, autocorrect and learning |
| `qml/org/theone/keyboard/Words.js` | Generated English word list (do not edit) |
| `scripts/theone-keyboard` | On/off switch (edits `~/.config/maliit.org/server.conf`) |
| `rpm/theone-keyboard.spec` | Package spec |

Inter font: SIL Open Font License 1.1 (`qml/org/theone/keyboard/fonts/Inter-LICENSE.txt`).

English word list: [FrequencyWords](https://github.com/hermitdave/FrequencyWords) by
Hermit Dave, built from OpenSubtitles 2018, licensed CC BY-SA 4.0. `data/en_50k.txt` is
the original file; `Words.js` is derived from it and carries the same licence.
