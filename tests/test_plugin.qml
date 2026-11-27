// End-to-end test of plugin/theone.qml against a fake Maliit server.
//   QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software qmlscene -I fake -I ../qml test_plugin.qml
// Prints PASS/FAIL lines and quits.
import QtQuick 2.6
import com.meego.maliitquick 1.0

Item {
    id: t
    width: 1080
    height: 2520

    Loader { id: loader; source: "../plugin/theone.qml" }
    readonly property var kb: loader.item ? loader.item.children[0].children[0] : null
    property int failures: 0
    property int step: 0

    function check(name, ok, detail) {
        console.log((ok ? "PASS " : "FAIL ") + name + (ok ? "" : "  -> " + detail))
        if (!ok) failures++
    }
    function keyFor(pred) {
        for (var i = 0; i < kb.keys.length; ++i) if (pred(kb.keys[i])) return kb.keys[i]
        return null
    }
    function press(k, id) {
        kb.startTouch(id || 1, (k.x + k.w / 2) * kb.sx, (k.y + k.h / 2) * kb.sy)
    }
    function release(k, id) {
        kb.endTouch(id || 1, (k.x + k.w / 2) * kb.sx, (k.y + k.h / 2) * kb.sy, false)
    }
    function tap(k) { press(k); release(k) }
    // Slide one finger through the word's letters.
    function swipe(word) {
        var pts = []
        for (var i = 0; i < word.length; ++i) {
            var c = word.charAt(i)
            var k = keyFor(function (kk) { return kk.type === "char" && kk.ch === c })
            pts.push({ x: (k.x + k.w / 2) * kb.sx, y: (k.y + k.h / 2) * kb.sy })
        }
        kb.startTouch(9, pts[0].x, pts[0].y)
        for (var j = 1; j < pts.length; ++j)
            for (var s = 1; s <= 5; ++s)
                kb.moveTouch(9, pts[j - 1].x + (pts[j].x - pts[j - 1].x) * s / 5,
                             pts[j - 1].y + (pts[j].y - pts[j - 1].y) * s / 5)
        var last = pts[pts.length - 1]
        kb.endTouch(9, last.x, last.y, false)
    }
    function tapChar(c) { tap(keyFor(function (k) { return k.type === "char" && k.ch === c })) }
    function tapType(ty) { tap(keyFor(function (k) { return k.type === ty })) }
    function text() { return MInputMethodQuick.surroundingText }
    function tapBar(i) {
        var x = (i + 0.5) * kb.width / 3, y = 30 * kb.sy
        kb.startTouch(7, x, y)
        kb.endTouch(7, x, y, false)
    }
    function clearText() {
        MInputMethodQuick.surroundingText = ""
        MInputMethodQuick.cursorPosition = 0
        kb.reset()
        loader.item.syncContext(true)
        loader.item.updateAutoCaps()
    }

    // Each step runs after a short delay so bindings and timers settle.
    property var steps: [
        function () { MInputMethodQuick.active = true },
        function () {
            var a = MInputMethodQuick.area
            check("input area covers the bottom of the screen",
                  a && Math.round(a.x) === 0 && Math.round(a.width) === 1080
                    && Math.round(a.y + a.height) === 2520 && Math.round(a.height) === Math.round(495 * 1080 / 618),
                  JSON.stringify(a))
            check("auto-capital at start of empty field", kb.shiftState === 1, kb.shiftState)
            check("ambience is read but off by default",
                  kb.ambienceMode === "off" && Qt.colorEqual(kb.ambienceColor, "#ff8c2e")
                    && Qt.colorEqual(kb.color, "#1f1f1f") && Qt.colorEqual(kb.accentColor, "#0a84ff"),
                  kb.ambienceMode + " " + kb.ambienceColor + " " + kb.color)
            kb.previewAmbience = { mode: "silica", light: false, highlight: "#c680ff", dimmer: "#1c0b2e" }
            check("Sailfish style: see-through panel, glass keys, solid balloon",
                  kb.silica && kb.color.a < 1 && kb.color.a > 0.5 && kb.keyColor.a < 0.3
                    && kb.popupColor.a === 1 && Qt.colorEqual(kb.textColor, "#ffffff"),
                  kb.color + " " + kb.keyColor + " " + kb.popupColor)
            kb.previewAmbience = null
            // The Sailfish style uses Sailfish's font unless "Sailfish font" is off in Settings.
            kb.storeLoader.item.ambience = "silica"
            check("Sailfish style uses the Sailfish font", kb.fontFamily === "Sail Sans Test", kb.fontFamily)
            kb.storeLoader.item.themeFont = false
            check("Sailfish font switch off keeps Inter", kb.fontFamily !== "Sail Sans Test" && kb.fontFamily !== "",
                  kb.fontFamily)
            kb.storeLoader.item.themeFont = true
            // Wide keys: drawn bigger, but each key answers to exactly the same area.
            kb.storeLoader.item.ambience = "off"
            var q = keyFor(function (k) { return k.ch === "q" }), w = keyFor(function (k) { return k.ch === "w" })
            var edge = (q.x + q.w + w.x) / 2, y = (q.y + q.h / 2) * kb.sy
            var before = MInputMethodQuick.surroundingText
            kb.storeLoader.item.wideKeys = true
            check("wide keys grow by 1.5 units each side", kb.grow === 1.5, kb.grow)
            kb.startTouch(3, (edge - 0.3) * kb.sx, y); kb.endTouch(3, (edge - 0.3) * kb.sx, y, false)
            kb.startTouch(3, (edge + 0.3) * kb.sx, y); kb.endTouch(3, (edge + 0.3) * kb.sx, y, false)
            check("wide keys keep the boundary between q and w in the middle of the gap",
                  /qw$/i.test(MInputMethodQuick.surroundingText), JSON.stringify(MInputMethodQuick.surroundingText))
            kb.storeLoader.item.wideKeys = false
            MInputMethodQuick.surroundingText = before
            MInputMethodQuick.cursorPosition = before.length
            kb.reset()
            loader.item.syncContext(true)
            loader.item.updateAutoCaps()
            kb.storeLoader.item.ambience = "off"
            check("theOne Classic always uses Inter", kb.fontFamily !== "Sail Sans Test", kb.fontFamily)
            tapChar("h"); tapChar("i")
            check("first letter capital, then lower case", text() === "Hi", text())
        },
        function () {
            tapType("space")
            tapType("space")
            check("double space types a full stop", text() === "Hi. ", JSON.stringify(text()))
        },
        function () {
            check("auto-capital after full stop", kb.shiftState === 1, kb.shiftState)
            tapChar("o"); tapChar("k")
            tapType("backspace")
            check("backspace removes last letter", text() === "Hi. O", text())
            tapType("mode")
            check("123 opens numbers", kb.page === "numbers", kb.page)
            tapChar("1")
            tapChar("'")
            check("apostrophe on numbers returns to letters", kb.page === "letters" && text() === "Hi. O1'", kb.page + " " + text())
        },
        function () {
            tapType("shift"); tapType("shift")
            check("double-tap shift is caps lock", kb.shiftState === 2, kb.shiftState)
            tapChar("a"); tapChar("b")
            check("caps lock stays on", text() === "Hi. O1'AB" && kb.shiftState === 2, text() + " " + kb.shiftState)
            tapType("shift")
            check("shift turns caps lock off", kb.shiftState === 0, kb.shiftState)
            // Rollover: second finger lands before the first lifts.
            var x = keyFor(function (k) { return k.ch === "x" }), y = keyFor(function (k) { return k.ch === "y" })
            press(x, 1); press(y, 2); release(x, 1); release(y, 2)
            check("rollover typing keeps order", text() === "Hi. O1'ABxy", text())
            // Long press on e for accents.
            press(keyFor(function (k) { return k.ch === "e" }), 3)
        },
        function () {
            check("long press opens accents", kb.accentKey !== null && kb.accentKey.ch === "e", kb.accentKey)
            var e = keyFor(function (k) { return k.ch === "e" })
            kb.moveTouch(3, (e.x + e.w / 2 + 61) * kb.sx, (e.y + e.h / 2) * kb.sy - 80)
            kb.endTouch(3, 0, 0, false)
            check("slide to second accent types é", text() === "Hi. O1'ABxyé", text())
            tapType("return")
            check("return activates the action key", MInputMethodQuick.log.indexOf("action") >= 0, MInputMethodQuick.log)
            clearText()
            tapChar("t"); tapChar("e"); tapChar("h")
        },
        function () {
            var b = kb.bar
            check("bar shows the typed word and the correction",
                  b.length === 3 && b[0].quoted && b[0].text === "Teh" && b[1].text === "The" && b[1].auto,
                  JSON.stringify(b))
            tapType("space")
            check("space autocorrects", text() === "The ", JSON.stringify(text()))
            tapType("backspace")
            check("backspace undoes the correction", text() === "Teh", JSON.stringify(text()))
            tapType("space")
            check("undone word is kept", text() === "Teh ", JSON.stringify(text()))
            tapChar("d"); tapChar("o"); tapChar("n"); tapChar("t")
            kb.typeText(".")
            tapType("space")
            check("punctuation autocorrects too", text() === "Teh don't. ", JSON.stringify(text()))
        },
        function () {
            var b = kb.bar
            check("sentence start predictions", b.length === 3 && b[0].text === "I", JSON.stringify(b))
            tapBar(0)
            check("tapping a prediction types it with a space", text() === "Teh don't. I ", JSON.stringify(text()))
            tapChar("h"); tapChar("e"); tapChar("l"); tapChar("o")
        },
        function () {
            check("bar offers hello for helo", kb.bar.length > 1 && kb.bar[1].text === "hello", JSON.stringify(kb.bar))
            tapBar(1)
            check("tapping a suggestion replaces the word", text() === "Teh don't. I hello ", JSON.stringify(text()))
            tapBar(0)
            check("next-word predictions type at the cursor", /hello \S+ $/.test(text()), JSON.stringify(text()))
            clearText()
            MInputMethodQuick.hiddenText = true
        },
        function () {
            MInputMethodQuick.hiddenText = false
            clearText()
            swipe("hello")
            check("swipe typing is off by default: a slide just moves to the last letter",
                  text() === "O" && !kb.swiping, JSON.stringify(text()))
            kb.storeLoader.item.swipe = true     // builds the word index before the next step
        },
        function () {
            clearText()
            swipe("hello")
            check("swipe writes the word, with a capital at the start", text() === "Hello", JSON.stringify(text()))
            check("the swiped word is highlighted in the bar", kb.bar.length > 1 && kb.bar[0].text === "Hello" && kb.bar[0].auto,
                  JSON.stringify(kb.bar))
            swipe("world")
            check("the next swipe adds the space", text() === "Hello world", JSON.stringify(text()))
            tapType("backspace")
            check("backspace after a swipe removes the whole word", text() === "Hello ", JSON.stringify(text()))
            swipe("there")
            tapType("space")
            check("no double space and no autocorrect after a swipe", text() === "Hello there ", JSON.stringify(text()))
            swipe("were")
            var alt = kb.bar.length > 1 ? kb.bar[1].text : "?"
            tapBar(1)
            check("tapping another guess replaces the swiped word", text() === "Hello there " + alt + " ",
                  JSON.stringify(text()))
            // A short slide to the next key is still a correction, not a swipe.
            var q = keyFor(function (k) { return k.ch === "q" }), w = keyFor(function (k) { return k.ch === "w" })
            press(q, 4)
            kb.moveTouch(4, (w.x + w.w / 2) * kb.sx, (w.y + w.h / 2) * kb.sy)
            release(w, 4)
            check("short slide still moves to the neighbouring letter", /w$/.test(text()) && !kb.swiping,
                  JSON.stringify(text()))
            clearText()
            MInputMethodQuick.hiddenText = true
        },
        function () {
            swipe("hello")
            check("no swipe in password fields", text() === "o", JSON.stringify(text()))
            clearText()
        },
        function () {
            tapChar("t"); tapChar("e"); tapChar("h"); tapType("space")
            check("no autocorrect or auto-capital in password fields", text() === "teh " && kb.bar.length === 0,
                  JSON.stringify(text()) + " " + JSON.stringify(kb.bar))
            MInputMethodQuick.hiddenText = false
            clearText()
            MInputMethodQuick.surroundingText = "abc1"
            MInputMethodQuick.cursorPosition = 4
            loader.item.syncContext(true)
            tapChar("x"); tapType("space")
            check("no correction inside glued tokens", text() === "abc1x ", JSON.stringify(text()))
        },
        function () {
            // Emoji search: the search field takes the letters, the app gets only the emoji.
            clearText()
            tapType("emoji")
            check("emoji key opens the emoji page", kb.page === "emoji", kb.page)
            kb.startEmojiSearch()
            check("search shows the letters and hides the suggestion bar",
                  kb.emojiSearch && kb.page === "letters" && !kb.barVisible && !kb.canSwipe,
                  kb.emojiSearch + " " + kb.page + " " + kb.barVisible)
            kb.pressShift()
            check("shift shows off while searching", kb.labelFor(keyFor(function (k) { return k.type === "char" })) === "q", "")
            tapChar("p"); tapChar("i"); tapChar("z"); tapChar("z"); tapChar("a")
            check("letters go to the search, in lower case", kb.searchText === "pizza", JSON.stringify(kb.searchText))
            check("nothing is typed into the app while searching", text() === "", JSON.stringify(text()))
            check("pizza finds the pizza", kb.searchResults[0] === "\ud83c\udf55", JSON.stringify(kb.searchResults))
            kb.typeText(kb.searchResults[0], true)
            check("a picked emoji is typed into the app", text() === "\ud83c\udf55", JSON.stringify(text()))
            check("the search stays open after picking", kb.emojiSearch && kb.searchText === "pizza", kb.emojiSearch)
            tapType("backspace")
            check("backspace edits the search, not the app",
                  kb.searchText === "pizz" && text() === "\ud83c\udf55", JSON.stringify(kb.searchText) + " " + JSON.stringify(text()))
            tapType("backspace"); tapType("backspace"); tapType("backspace"); tapType("backspace"); tapType("backspace")
            tapType("space")
            check("no leading space in the search", kb.searchText === "", JSON.stringify(kb.searchText))
            tapChar("x"); tapChar("q"); tapChar("z")
            check("no matches gives an empty row", kb.searchResults.length === 0, JSON.stringify(kb.searchResults))
            tapType("return")
            check("Done leaves the search for normal typing",
                  !kb.emojiSearch && kb.page === "letters" && kb.searchText === "" && text() === "\ud83c\udf55",
                  kb.emojiSearch + " " + kb.page + " " + JSON.stringify(text()))
            tapChar("h"); tapChar("i")
            check("after the search the letters go to the app again", text().toLowerCase() === "\ud83c\udf55hi", JSON.stringify(text()))
            kb.startEmojiSearch()
            tapChar("c")
            tapType("emoji")
            check("the emoji key goes back to the emoji page", kb.page === "emoji" && !kb.emojiSearch,
                  kb.page + " " + kb.emojiSearch)
            kb.startEmojiSearch()
            kb.reset()
            check("reset ends the search", !kb.emojiSearch && kb.searchText === "", kb.emojiSearch)
        },
        function () {
            MInputMethodQuick.appOrientation = 90
        },
        function () {
            var a = MInputMethodQuick.area
            check("landscape area is a side strip of the portrait screen",
                  a && Math.round(a.height) === 2520 && a.width < 1080 * 0.65 && a.width > 300,
                  JSON.stringify(a))
            MInputMethodQuick.appOrientation = 0
            MInputMethodQuick.active = false
        },
        function () {
            var a = MInputMethodQuick.area
            check("hidden keyboard frees the screen", a && a.width === 0 && a.height === 0, JSON.stringify(a))
            // Sailfish: the keyboard opens with the previous field's type (a URL field here),
            // and the real one arrives just after.
            MInputMethodQuick.surroundingText = ""
            MInputMethodQuick.cursorPosition = 0
            MInputMethodQuick.contentType = Maliit.UrlContentType
            MInputMethodQuick.active = true
        },
        function () {
            check("no auto-capital in a URL field", kb.shiftState === 0, kb.shiftState)
            MInputMethodQuick.contentType = Maliit.FreeTextContentType
        },
        function () {
            check("auto-capital once the field turns out to be text", kb.shiftState === 1, kb.shiftState)
            check("suggestions once the field turns out to be text", kb.predictions && kb.bar.length > 0,
                  kb.predictions + " " + JSON.stringify(kb.bar))
            // A passing "auto-capitals off" while the field still allows suggestions.
            kb.shiftState = 0
            MInputMethodQuick.autoCapitalizationEnabled = false
            MInputMethodQuick.autoCapitalizationChanged()
            check("auto-capital survives a passing capitals-off flag", kb.shiftState === 1, kb.shiftState)
            // A field that wants neither (user names, keys) stays lower case.
            MInputMethodQuick.predictionEnabled = false
            MInputMethodQuick.autoCapitalizationChanged()
            check("no auto-capital where the field turns off capitals and suggestions", kb.shiftState === 0, kb.shiftState)
            MInputMethodQuick.predictionEnabled = true
            MInputMethodQuick.autoCapitalizationEnabled = true
            MInputMethodQuick.active = false
            console.log(failures === 0 ? "ALL TESTS PASSED" : failures + " TEST(S) FAILED")
            Qt.quit()
        }
    ]

    Timer {
        interval: 600
        repeat: true
        running: true
        onTriggered: {
            if (!t.kb) { console.log("FAIL plugin did not load"); Qt.quit(); return }
            t.steps[t.step++]()
        }
    }
}
