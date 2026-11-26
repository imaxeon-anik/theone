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
    function tapChar(c) { tap(keyFor(function (k) { return k.type === "char" && k.ch === c })) }
    function tapType(ty) { tap(keyFor(function (k) { return k.type === ty })) }
    function text() { return MInputMethodQuick.surroundingText }

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
