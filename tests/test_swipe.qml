// Checks the swipe decoder with drawn paths: a word's letters joined by curved,
// wobbly lines that start and stop a little off the key centres, like a finger.
//   QT_QPA_PLATFORM=offscreen qmlscene test_swipe.qml
import QtQuick 2.6
import "../qml/org/theone/keyboard/Predict.js" as P
import "../qml/org/theone/keyboard/Swipe.js" as S

Item {
    property int failures: 0
    property int seed: 7

    function check(name, ok, detail) {
        console.log((ok ? "PASS " : "FAIL ") + name + (ok ? "" : "  -> " + detail))
        if (!ok) failures++
    }

    function rand() {            // repeatable noise
        seed = (seed * 1103515245 + 12345) % 2147483648
        return seed / 2147483648
    }

    // A finger's path through the word's letters. sloppy: how far off centre (units).
    function draw(word, sloppy) {
        var c = S.centres(), pts = []
        var keys = S.keysOf(word)
        for (var i = 0; i < keys.length; ++i) {
            var p = c[keys.charAt(i)]
            var q = { x: p.x + (rand() - 0.5) * 2 * sloppy, y: p.y + (rand() - 0.5) * 2 * sloppy }
            if (i > 0) {
                var a = pts[pts.length - 1], bend = (rand() - 0.5) * sloppy
                for (var s = 1; s <= 6; ++s) {
                    var t = s / 6, arc = Math.sin(Math.PI * t) * bend
                    var dx = q.x - a.x, dy = q.y - a.y, l = Math.sqrt(dx * dx + dy * dy) || 1
                    pts.push({ x: a.x + dx * t - dy / l * arc, y: a.y + dy * t + dx / l * arc })
                }
            } else {
                pts.push(q)
            }
        }
        return pts
    }

    readonly property var words: [
        "hello", "the", "you", "what", "thanks", "going", "keyboard", "tomorrow", "because",
        "people", "really", "love", "time", "good", "morning", "night", "where", "about",
        "with", "would", "sailfish", "phone", "great", "think", "message", "today", "work",
        "home", "just", "know", "can't", "it's", "please", "sorry", "yes", "okay", "this",
        "that", "have", "from", "they", "were", "there", "here", "some", "want"
    ]

    Timer { running: true; interval: 10; onTriggered: run() }

    function run() {
        P.init()
        var t0 = Date.now()
        S.decode(draw("hello", 0), "", 3)
        console.log("first swipe ms (builds the index)", Date.now() - t0)

        var exact = 0, top3 = 0, total = 0, misses = []
        t0 = Date.now()
        for (var r = 0; r < 3; ++r)
            for (var i = 0; i < words.length; ++i) {
                var w = words[i]
                var res = S.decode(draw(w, 14), "", 3)
                var got = res.map(function (x) { return x.w })
                ++total
                if (got[0] === w) ++exact
                else misses.push(w + "->" + got.join("/"))
                if (got.indexOf(w) >= 0) ++top3
            }
        var per = (Date.now() - t0) / total
        console.log("swipe ms per word", per.toFixed(1))
        console.log("first choice " + exact + "/" + total + ", in top 3 " + top3 + "/" + total)
        if (misses.length)
            console.log("misses: " + misses.join(", "))
        check("most swipes give the word first", exact >= 0.85 * total, exact + "/" + total)
        check("nearly all swipes have the word in the bar", top3 >= 0.95 * total, top3 + "/" + total)
        check("swipe is fast enough", per < 80, per)

        check("a dot is not a word", S.decode([{ x: 100, y: 100 }], "", 3).length === 0, "")
        check("apostrophe words come back with the apostrophe",
              S.decode(draw("don't", 0), "", 3)[0].w === "don't", JSON.stringify(S.decode(draw("don't", 0), "", 3)))

        var over = draw("down", 0)
        over.push({ x: over[over.length - 1].x, y: over[over.length - 1].y + 80 })   // n -> onto the space bar
        var ov = S.decode(over, "", 3).map(function (x) { return x.w })
        check("a swipe that runs off the letters onto the space bar still counts", ov[0] === "down", ov)

        P.learn("sailmate", "", true)
        P.learn("sailmate", "", true)
        var sm = S.decode(draw("sailmate", 6), "", 3).map(function (x) { return x.w })
        check("learned words can be swiped", sm.indexOf("sailmate") >= 0, sm)

        console.log(failures === 0 ? "ALL TESTS PASSED" : failures + " TEST(S) FAILED")
        Qt.quit()
    }
}
