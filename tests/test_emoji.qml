// Checks emoji search (Layouts.js searchEmoji, words from EmojiNames.js).
//   QT_QPA_PLATFORM=offscreen qmlscene test_emoji.qml
import QtQuick 2.6
import "../qml/org/theone/keyboard/Layouts.js" as L

Item {
    property int failures: 0

    function check(name, ok, detail) {
        console.log((ok ? "PASS " : "FAIL ") + name + (ok ? "" : "  -> " + detail))
        if (!ok) failures++
    }
    function first(q) { return L.searchEmoji(q, 60)[0] }
    function inTop(q, e, n) { return L.searchEmoji(q, 60).slice(0, n).indexOf(e) >= 0 }

    Timer { running: true; interval: 10; onTriggered: run() }

    function run() {
        var t0 = Date.now()
        L.searchEmoji("a", 60)
        console.log("first search ms (builds the index)", Date.now() - t0)

        var all = L.emojiList().all
        check("every emoji on the page can be found by name",
              L.emojiSearchIndex().length === all.length, L.emojiSearchIndex().length + "/" + all.length)

        check("pizza", first("pizza") === "🍕", L.searchEmoji("pizza", 5))
        check("upper case works", first("PIZZA") === "🍕", L.searchEmoji("PIZZA", 5))
        check("thumbs up", first("thumbs up") === "👍", L.searchEmoji("thumbs up", 5))
        check("two words in any order", first("up thumbs") === "👍", L.searchEmoji("up thumbs", 5))
        check("red heart", first("red heart") === "❤️", L.searchEmoji("red heart", 5))
        check("heart gives the red heart first", first("heart") === "❤️", L.searchEmoji("heart", 8))
        check("dog", inTop("dog", "🐶", 2) && inTop("dog", "🐕", 2), L.searchEmoji("dog", 5))
        check("a word start is enough", inTop("piz", "🍕", 1), L.searchEmoji("piz", 5))
        check("keywords count: laugh finds tears of joy", inTop("laugh", "😂", 12), L.searchEmoji("laugh", 12))
        check("keywords count: love finds the red heart", inTop("love", "❤️", 12), L.searchEmoji("love", 12))
        check("cat", inTop("cat", "🐱", 2), L.searchEmoji("cat", 5))
        check("fire", first("fire") === "🔥", L.searchEmoji("fire", 5))
        check("party", inTop("party", "🥳", 3), L.searchEmoji("party", 5))
        check("accents in keywords: pina finds the coconut (piña)", inTop("pina", "🥥", 3), L.searchEmoji("pina", 5))
        check("an accented search finds plain words too", first("pízza") === "🍕", L.searchEmoji("pízza", 5))
        check("apostrophes: im and i'm both find the skull", inTop("im", "💀", 60) && inTop("i'm", "💀", 60),
              L.searchEmoji("i'm", 5))
        check("a trailing space is fine", first("pizza ") === "🍕", L.searchEmoji("pizza ", 5))
        check("nothing for an empty search", L.searchEmoji("", 60).length === 0 && L.searchEmoji("   ", 60).length === 0, "")
        check("nothing for nonsense", L.searchEmoji("xqzzy", 60).length === 0, L.searchEmoji("xqzzy", 5))
        check("the result count is capped", L.searchEmoji("face", 10).length === 10, L.searchEmoji("face", 60).length)

        t0 = Date.now()
        var qs = ["a", "he", "hea", "heart", "s", "sm", "smile", "c", "ca", "cat", "f", "fo", "food"]
        for (var r = 0; r < 10; ++r)
            for (var i = 0; i < qs.length; ++i)
                L.searchEmoji(qs[i], 60)
        var per = (Date.now() - t0) / (10 * qs.length)
        console.log("search ms per key", per.toFixed(2))
        check("search is fast enough to run on every key", per < 15, per)

        console.log(failures === 0 ? "ALL TESTS PASSED" : failures + " TEST(S) FAILED")
        Qt.quit()
    }
}
