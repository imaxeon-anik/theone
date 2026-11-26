// Desktop preview: renders keyboard states to PNG files and quits.
//   QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software qmlscene -I ../qml preview.qml
// Output goes to /tmp/theone-preview/<state>.png (618 px wide, the reference size).
import QtQuick 2.6
import org.theone.keyboard 1.0

Item {
    id: root
    width: 618
    height: 495

    property var states: [
        { name: "letters-shift", page: "letters", shift: 1, popup: -1, accent: -1 },
        { name: "letters", page: "letters", shift: 0, popup: -1, accent: -1 },
        { name: "capslock", page: "letters", shift: 2, popup: -1, accent: -1 },
        { name: "popup-g", page: "letters", shift: 0, popup: 14, accent: -1 },
        { name: "popup-q", page: "letters", shift: 1, popup: 0, accent: -1 },
        { name: "accents-e", page: "letters", shift: 0, popup: -1, accent: 2 },
        { name: "numbers", page: "numbers", shift: 0, popup: -1, accent: -1 },
        { name: "symbols", page: "symbols", shift: 0, popup: -1, accent: -1 },
        { name: "emoji", page: "emoji", shift: 0, popup: -1, accent: -1 }
    ]
    property int current: 0

    Keyboard {
        id: kb
        width: root.width
    }

    function apply(s) {
        kb.page = s.page
        kb.shiftState = s.shift
        kb.popupKey = s.popup >= 0 ? kb.keys[s.popup] : null
        kb.accentKey = s.accent >= 0 ? kb.keys[s.accent] : null
        kb.accentIndex = 1
    }

    Timer {
        id: tick
        interval: 400
        running: true
        onTriggered: {
            var s = root.states[root.current]
            kb.grabToImage(function (result) {
                result.saveToFile("/tmp/theone-preview/" + s.name + ".png")
                root.current += 1
                if (root.current >= root.states.length) {
                    Qt.quit()
                    return
                }
                root.apply(root.states[root.current])
                tick.restart()
            })
        }
    }

    Component.onCompleted: apply(states[0])
}
