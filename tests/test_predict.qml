// Checks the suggestion and autocorrect engine.
//   QT_QPA_PLATFORM=offscreen qmlscene test_predict.qml
import QtQuick 2.6
import "../qml/org/theone/keyboard/Predict.js" as P

Item {
    property int failures: 0

    function check(name, ok, detail) {
        console.log((ok ? "PASS " : "FAIL ") + name + (ok ? "" : "  -> " + detail))
        if (!ok) failures++
    }

    // typed -> expected autocorrection ("" = leave it alone)
    readonly property var autos: [
        ["helo", "hello"], ["teh", "the"], ["thsi", "this"], ["dont", "don't"], ["im", "I'm"],
        ["i", "I"], ["recieve", "receive"], ["definately", "definitely"], ["becuase", "because"],
        ["wierd", "weird"], ["adress", "address"], ["tomorow", "tomorrow"], ["goign", "going"],
        ["hte", "the"], ["yuo", "you"], ["waht", "what"], ["jsut", "just"], ["Hrllo", "Hello"],
        ["monday", "Monday"], ["alot", "a lot"], ["didnt", "didn't"], ["youre", "you're"],
        ["the", ""], ["its", ""], ["were", ""], ["well", ""], ["hello", ""], ["ok", ""],
        ["cafe", ""], ["iPhone", ""], ["Paris", ""], ["shit", ""]
    ]

    Timer { running: true; interval: 10; onTriggered: run() }

    function run() {
        var t0 = Date.now()
        P.init()
        console.log("init ms", Date.now() - t0)

        t0 = Date.now()
        for (var i = 0; i < autos.length; ++i) {
            var r = P.suggest(autos[i][0])
            var want = autos[i][1]
            // "a lot" is two words; the list has no phrases, so accept "allot"/"lot" being absent
            if (want === "a lot")
                continue
            check(autos[i][0] + " -> " + (want || "(kept)"), r.auto === want,
                  JSON.stringify(r))
        }
        var per = (Date.now() - t0) / autos.length
        console.log("suggest ms per word", per.toFixed(1))
        check("suggest is fast enough", per < 60, per)

        var s = P.suggest("hel")
        check("unfinished word offers completions", s.auto === "" && s.items.indexOf("hello") >= 0, JSON.stringify(s))
        s = P.suggest("hell")
        check("completions for 'hell'", s.items.indexOf("hello") >= 0 && s.auto === "", JSON.stringify(s))
        s = P.suggest("Tha")
        check("completions keep the capital", s.items.length > 0 && s.items[0][0] === "T", JSON.stringify(s))
        check("swear words are never suggested", P.suggest("shi").items.indexOf("shit") < 0, P.suggest("shi").items)

        // Learning: an unknown word is corrected until the user insists on it.
        var before = P.suggest("taht").auto
        P.learn("taht", "", true)
        check("learned word is no longer corrected", before !== "" && P.suggest("taht").auto === "",
              before + " / " + P.suggest("taht").auto)
        P.learn("sailmate", "", true)
        check("learned word is completed", P.suggest("sailm").items.indexOf("sailmate") >= 0, P.suggest("sailm").items)
        P.learn("Anik", "", true)
        check("learned name gets its capital back", P.suggest("anik").auto === "Anik", JSON.stringify(P.suggest("anik")))

        P.learn("you", "thank", false)
        P.learn("you", "thank", false)
        check("next word comes from what was typed before", P.next("thank", false)[0] === "you", P.next("thank", false))
        check("sentence start predictions", JSON.stringify(P.next("", true)) === '["I","The","I\'m"]', P.next("", true))

        var saved = P.dump()
        P.load("{}")
        check("forget", P.suggest("taht").auto !== "", "")
        P.load(saved)
        check("save and load", P.suggest("taht").auto === "", saved.slice(0, 80))

        console.log(failures === 0 ? "ALL TESTS PASSED" : failures + " TEST(S) FAILED")
        Qt.quit()
    }
}
