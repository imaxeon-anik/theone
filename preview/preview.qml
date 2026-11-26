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
        { name: "emoji", page: "emoji", shift: 0, popup: -1, accent: -1 },
        { name: "suggest-teh", page: "letters", shift: 0, popup: -1, accent: -1, word: "Teh" },
        { name: "suggest-hel", page: "letters", shift: 0, popup: -1, accent: -1, word: "hel" },
        { name: "predict-start", page: "letters", shift: 1, popup: -1, accent: -1, word: "" },
        // Silica style over a sample ambience wallpaper (see backdrop below).
        { name: "silica-purple", page: "letters", shift: 0, popup: -1, accent: -1, word: "Teh", wall: 0,
          amb: { mode: "silica", light: false, highlight: "#c680ff", dimmer: "#1c0b2e" } },
        { name: "silica-purple-popup", page: "letters", shift: 1, popup: 14, accent: -1, word: "", wall: 0,
          amb: { mode: "silica", light: false, highlight: "#c680ff", dimmer: "#1c0b2e" } },
        { name: "silica-orange-numbers", page: "numbers", shift: 0, popup: -1, accent: -1, word: "", wall: 1,
          amb: { mode: "silica", light: false, highlight: "#ff8c2e", dimmer: "#2b1300" } },
        { name: "wide-iphone", page: "letters", shift: 0, popup: 14, accent: -1, word: "Teh",
          amb: { mode: "off", light: false, highlight: "#0a84ff", wide: true } },
        { name: "wide-silica", page: "letters", shift: 0, popup: -1, accent: -1, word: "Teh", wall: 0,
          amb: { mode: "silica", light: false, highlight: "#c680ff", dimmer: "#1c0b2e", wide: true } },
        { name: "silica-light-accents", page: "letters", shift: 0, popup: -1, accent: 2, word: "hel", wall: 2,
          amb: { mode: "silica", light: true, highlight: "#1f6fd6", dimmer: "#e6eefa", primary: "#000000" } }
    ]
    property int current: 0
    property int wall: -1

    // A stand-in ambience wallpaper, so the see-through Silica style has something behind it.
    Rectangle {
        anchors.fill: parent
        visible: root.wall >= 0
        gradient: Gradient {
            GradientStop { position: 0; color: ["#6a2fb0", "#c2410c", "#9cc3f5"][Math.max(0, root.wall)] }
            GradientStop { position: 0.55; color: ["#1e3a8a", "#7c2d12", "#f7d6e6"][Math.max(0, root.wall)] }
            GradientStop { position: 1; color: ["#0f172a", "#1c1917", "#ffffff"][Math.max(0, root.wall)] }
        }
        Rectangle {
            x: parent.width * 0.55; y: parent.height * 0.18
            width: parent.width * 0.5; height: width; radius: width / 2
            color: ["#e879f9", "#fbbf24", "#60a5fa"][Math.max(0, root.wall)]
            opacity: 0.55
        }
        Rectangle {
            x: -parent.width * 0.12; y: parent.height * 0.5
            width: parent.width * 0.42; height: width; radius: width / 2
            color: ["#22d3ee", "#f97316", "#f472b6"][Math.max(0, root.wall)]
            opacity: 0.5
        }
    }

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
        kb.previewAmbience = s.amb || null
        root.wall = s.wall !== undefined ? s.wall : -1
        kb.actionLabel = s.go ? "Go" : ""
        kb.actionHighlighted = !!s.go
        kb.word = s.word || ""
        kb.updateBar()
    }

    Timer {
        id: tick
        interval: 400
        running: true
        onTriggered: {
            var s = root.states[root.current]
            root.grabToImage(function (result) {
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
