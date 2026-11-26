import QtQuick 2.6
import "Layouts.js" as L

// theOne keyboard surface. Knows nothing about Maliit: it emits signals and the
// plugin entry file (theone.qml) forwards them to the input method server.
Rectangle {
    id: kb

    // --- sizing ---------------------------------------------------------------------
    property real maxHeight: 1e6
    readonly property real sx: width / L.REF_W
    readonly property real sy: Math.min(sx, maxHeight / L.REF_H)
    readonly property real unit: Math.min(sx, sy)
    height: Math.round(L.REF_H * sy)

    // --- look -----------------------------------------------------------------------
    color: "#1f1f1f"
    readonly property color keyColor: "#434343"
    readonly property color keyPressedColor: "#6b6b6b"
    readonly property color textColor: "#ffffff"
    readonly property color accentColor: "#0a84ff"
    readonly property string fontFamily: inter.status === FontLoader.Ready ? inter.name : ""
    FontLoader { id: inter; source: "fonts/Inter-Regular.ttf" }

    // --- state ----------------------------------------------------------------------
    property string page: "letters"        // letters | numbers | symbols | emoji
    property int shiftState: 0             // 0 off, 1 next letter, 2 caps lock
    property bool autoShifted: false
    property bool trackpad: false
    property string actionLabel: ""
    property bool actionHighlighted: false
    property bool actionEnabled: true

    readonly property var keys: L.keysFor(page === "emoji" ? "letters" : page)
    property var pressedIndexes: []
    property var popupKey: null
    property var accentKey: null
    property int accentIndex: 0

    // --- output ---------------------------------------------------------------------
    signal commit(string text, int replaceStart, int replaceLength)
    signal backspace()
    signal actionKey()
    signal cursorStep(int direction)

    // Local memory of what was just typed, for double-space and auto-capitals when the
    // editor does not report its text.
    property string recent: ""
    property double lastSpaceTime: 0
    property double lastShiftTime: 0

    function reset() {
        page = "letters"
        shiftState = 0
        autoShifted = false
        recent = ""
        trackpad = false
        endAllTouches()
    }

    // Called by the plugin when the editor's text/cursor changes.
    function applyAutoCaps(atSentenceStart) {
        if (shiftState === 2)
            return
        if (atSentenceStart && shiftState === 0) {
            shiftState = 1
            autoShifted = true
        } else if (!atSentenceStart && shiftState === 1 && autoShifted) {
            shiftState = 0
            autoShifted = false
        }
    }

    function labelFor(k) {
        if (k.type !== "char")
            return ""
        return (page === "letters" && shiftState > 0) ? k.ch.toUpperCase() : k.ch
    }

    function typeText(t) {
        commit(t, 0, 0)
        recent = (recent + t).slice(-4)
        if (shiftState === 1) {
            shiftState = 0
            autoShifted = false
        }
    }

    function typeSpace() {
        var now = Date.now()
        if (/[^\s.!?]\s$/.test(recent) && now - lastSpaceTime < 700) {
            commit(". ", -1, 1)          // replace the space just typed
            recent = (recent.slice(0, -1) + ". ").slice(-4)
            lastSpaceTime = 0
        } else {
            commit(" ", 0, 0)
            recent = (recent + " ").slice(-4)
            lastSpaceTime = now
        }
        if (page !== "letters" && page !== "emoji")
            page = "letters"
    }

    function pressShift() {
        var now = Date.now()
        if (shiftState === 1 && now - lastShiftTime < 350)
            shiftState = 2
        else
            shiftState = shiftState === 0 ? 1 : 0
        autoShifted = false
        lastShiftTime = now
    }

    function doBackspace() {
        backspace()
        recent = recent.slice(0, -1)
    }

    // --- key drawing ----------------------------------------------------------------
    Repeater {
        model: kb.page === "emoji" ? [] : kb.keys
        delegate: Rectangle {
            readonly property var k: modelData
            readonly property bool down: kb.pressedIndexes.indexOf(k.index) >= 0
            x: k.x * kb.sx
            y: k.y * kb.sy
            width: k.w * kb.sx
            height: k.h * kb.sy
            radius: 10 * kb.unit
            color: k.bare ? "transparent"
                 : (k.type === "return" && kb.actionHighlighted) ? kb.accentColor
                 : (down && k.type !== "char") ? kb.keyPressedColor
                 : kb.keyColor

            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: (k.type === "char" ? -1.6 : k.type === "mode" ? -0.8 : 0) * kb.unit
                anchors.horizontalCenterOffset: (k.type === "mode" ? 1 : k.type === "char" ? -1.5 : 0) * kb.unit
                // Inter is a little wider than the iOS system font; narrow letters to match.
                transform: Scale { origin.x: width / 2; xScale: k.type === "char" ? 0.92 : 1 }
                visible: !kb.trackpad
                text: k.type === "char" ? kb.labelFor(k)
                    : k.type === "mode" ? k.label
                    : (k.type === "return" && kb.actionLabel !== "") ? kb.actionLabel
                    : ""
                color: kb.textColor
                opacity: (k.type === "return" && !kb.actionEnabled) ? 0.4 : 1
                font.family: kb.fontFamily
                font.pixelSize: (k.type === "char" ? 30 : 26) * kb.unit
            }

            Icon {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: (k.type === "return" ? -0.6 : 0.8) * kb.unit
                visible: name !== "" && !kb.trackpad
                scaleFactor: kb.unit
                color: kb.textColor
                cutout: kb.color
                name: k.type === "shift" ? (kb.shiftState === 2 ? "capsLock" : kb.shiftState === 1 ? "shiftOn" : "shift")
                    : k.type === "backspace" ? "backspace"
                    : (k.type === "return" && kb.actionLabel === "") ? "return"
                    : ""
            }

            Icon {
                visible: k.type === "emoji"
                x: (L.STRIP_ICON.cx - k.x) * kb.sx - width / 2
                y: (L.STRIP_ICON.cy - k.y) * kb.sy - height / 2
                scaleFactor: kb.unit
                color: kb.textColor
                cutout: kb.color
                name: "emoji"
            }
        }
    }

    // --- touch handling -------------------------------------------------------------
    property var touches: ({})    // pointId -> { key, startX, lastX, done, mode }

    function keyAt(px, py) {
        return L.hitTest(keys, px / sx, py / sy)
    }

    function setPressed(list) { pressedIndexes = list }

    function refreshPressed() {
        var list = []
        for (var id in touches)
            if (touches[id].key && !touches[id].done)
                list.push(touches[id].key.index)
        setPressed(list)
    }

    function showPopupFor(k) {
        popupKey = (k && k.type === "char") ? k : null
    }

    function startTouch(id, px, py) {
        var k = keyAt(px, py)
        // Rollover typing: a new finger commits the letter under the previous finger.
        for (var other in touches) {
            var t = touches[other]
            if (!t.done && t.key && t.key.type === "char" && t.mode === "") {
                typeText(labelFor(t.key))
                t.done = true
            }
        }
        touches[id] = { key: k, startX: px, lastX: px, done: false, mode: "" }
        if (!k) {
            refreshPressed()
            return
        }
        if (k.type === "char")
            showPopupFor(k)
        if (k.type === "shift") {
            pressShift()
        } else if (k.type === "backspace") {
            doBackspace()
            repeatTimer.interval = 450
            repeatTimer.restart()
        }
        holdTimer.pointId = id
        holdTimer.restart()
        refreshPressed()
    }

    function moveTouch(id, px, py) {
        var t = touches[id]
        if (!t || t.done)
            return
        if (t.mode === "accent") {
            var cellW = accentPopup.cellW
            var i = Math.floor((px - accentPopup.x) / cellW)
            accentIndex = Math.max(0, Math.min(accentKey.accents.length - 1, i))
            return
        }
        if (t.mode === "trackpad") {
            var step = 13 * sx
            while (px - t.lastX > step) { cursorStep(1); t.lastX += step }
            while (t.lastX - px > step) { cursorStep(-1); t.lastX -= step }
            return
        }
        var k = keyAt(px, py)
        if (t.key && t.key.type === "char" && k && k.type === "char" && k !== t.key) {
            t.key = k             // slide to a neighbouring letter, like iOS
            showPopupFor(k)
            holdTimer.restart()
            refreshPressed()
        } else if (t.key && t.key.type === "space" && Math.abs(px - t.startX) > 20 * sx) {
            enterTrackpad(id)
        }
    }

    function endTouch(id, px, py, cancelled) {
        var t = touches[id]
        delete touches[id]
        if (holdTimer.pointId === id)
            holdTimer.stop()
        if (!t)
            return
        if (t.key && t.key.type === "backspace")
            repeatTimer.stop()
        if (t.mode === "accent") {
            if (!cancelled)
                typeText(accentKey.accents[accentIndex])
            accentKey = null
        } else if (t.mode === "trackpad") {
            trackpad = false
        } else if (!t.done && t.key && !cancelled) {
            var k = t.key
            if (k.type === "char") {
                typeText(labelFor(k))
                if (page !== "letters" && k.ch === "'")
                    page = "letters"
            } else if (k.type === "space") {
                typeSpace()
            } else if (k.type === "return") {
                if (actionEnabled)
                    actionKey()
                recent = ""
            } else if (k.type === "mode") {
                page = k.target
            } else if (k.type === "emoji") {
                page = "emoji"
            }
        }
        if (popupKey && t.key === popupKey)
            showPopupFor(null)
        refreshPressed()
    }

    function endAllTouches() {
        touches = ({})
        holdTimer.stop()
        repeatTimer.stop()
        popupKey = null
        accentKey = null
        setPressed([])
    }

    function enterTrackpad(id) {
        var t = touches[id]
        if (!t || t.done)
            return
        t.mode = "trackpad"
        trackpad = true
        refreshPressed()
    }

    Timer {
        id: holdTimer
        property var pointId: -1
        interval: 420
        onTriggered: {
            var t = kb.touches[pointId]
            if (!t || t.done || !t.key)
                return
            if (t.key.type === "char" && t.key.accents !== "") {
                t.mode = "accent"
                kb.accentIndex = 0
                kb.accentKey = t.key
                kb.showPopupFor(null)
            } else if (t.key.type === "space") {
                kb.enterTrackpad(pointId)
            }
        }
    }

    Timer {
        id: repeatTimer
        repeat: true
        onTriggered: {
            kb.doBackspace()
            interval = 90
        }
    }

    MultiPointTouchArea {
        anchors.fill: parent
        enabled: kb.page !== "emoji"
        mouseEnabled: true
        maximumTouchPoints: 5
        onPressed: {
            for (var i = 0; i < touchPoints.length; ++i)
                kb.startTouch(touchPoints[i].pointId, touchPoints[i].x, touchPoints[i].y)
        }
        onUpdated: {
            for (var i = 0; i < touchPoints.length; ++i)
                kb.moveTouch(touchPoints[i].pointId, touchPoints[i].x, touchPoints[i].y)
        }
        onReleased: {
            for (var i = 0; i < touchPoints.length; ++i)
                kb.endTouch(touchPoints[i].pointId, touchPoints[i].x, touchPoints[i].y, false)
        }
        onCanceled: kb.endAllTouches()
    }

    // --- popups ---------------------------------------------------------------------
    KeyPopup {
        anchors.fill: parent
        visible: kb.popupKey !== null
        kx: kb.popupKey ? kb.popupKey.x * kb.sx : 0
        ky: kb.popupKey ? kb.popupKey.y * kb.sy : 0
        kw: kb.popupKey ? kb.popupKey.w * kb.sx : 0
        kh: kb.popupKey ? kb.popupKey.h * kb.sy : 0
        text: kb.popupKey ? kb.labelFor(kb.popupKey) : ""
        color: kb.keyColor
        textColor: kb.textColor
        fontFamily: kb.fontFamily
        unit: kb.unit
    }

    Rectangle {
        id: accentPopup
        readonly property real cellW: L.KEY_W * kb.sx
        readonly property int count: kb.accentKey ? kb.accentKey.accents.length : 0
        visible: kb.accentKey !== null
        width: count * cellW + 2 * 6 * kb.unit
        height: L.KEY_H * kb.sy * 1.05
        radius: 10 * kb.unit
        color: kb.keyColor
        border.color: "#2a2a2a"
        border.width: 1
        x: kb.accentKey ? Math.max(4 * kb.unit, Math.min(kb.width - width - 4 * kb.unit,
                                                         kb.accentKey.x * kb.sx - 6 * kb.unit)) : 0
        y: kb.accentKey ? kb.accentKey.y * kb.sy - height - 8 * kb.sy : 0

        Row {
            x: 6 * kb.unit
            anchors.verticalCenter: parent.verticalCenter
            Repeater {
                model: kb.accentKey ? kb.accentKey.accents.split("") : []
                delegate: Rectangle {
                    width: accentPopup.cellW
                    height: accentPopup.height - 12 * kb.unit
                    radius: 8 * kb.unit
                    color: index === kb.accentIndex ? kb.accentColor : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: kb.shiftState > 0 ? modelData.toUpperCase() : modelData
                        color: kb.textColor
                        font.family: kb.fontFamily
                        font.pixelSize: 32 * kb.unit
                    }
                }
            }
        }
    }

    // --- emoji page -----------------------------------------------------------------
    Item {
        id: emojiPage
        anchors.fill: parent
        visible: kb.page === "emoji"
        readonly property var emojiData: L.emojiList()

        GridView {
            id: emojiGrid
            x: 6 * kb.sx
            y: 70 * kb.sy
            width: parent.width - 12 * kb.sx
            height: 316 * kb.sy
            flow: GridView.FlowTopToBottom
            cellHeight: height / 5
            cellWidth: cellHeight * 1.0
            clip: true
            model: kb.page === "emoji" ? emojiPage.emojiData.all : []
            delegate: Item {
                width: emojiGrid.cellWidth
                height: emojiGrid.cellHeight
                Text {
                    anchors.centerIn: parent
                    text: modelData
                    font.pixelSize: 40 * kb.unit
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: kb.typeText(modelData)
                }
            }
        }

        Text {
            id: abcKey
            x: 20 * kb.sx
            y: 412 * kb.sy
            height: 50 * kb.sy
            verticalAlignment: Text.AlignVCenter
            text: "ABC"
            color: kb.textColor
            font.family: kb.fontFamily
            font.pixelSize: 22 * kb.unit
            MouseArea {
                anchors.fill: parent
                anchors.margins: -12 * kb.unit
                onClicked: kb.page = "letters"
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 416 * kb.sy
            spacing: 14 * kb.sx
            Repeater {
                model: L.EMOJI.length
                delegate: Text {
                    text: L.EMOJI[index].icon
                    font.pixelSize: 26 * kb.unit
                    opacity: 0.75
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6 * kb.unit
                        onClicked: emojiGrid.positionViewAtIndex(emojiPage.emojiData.starts[index],
                                                                 GridView.Beginning)
                    }
                }
            }
        }

        Icon {
            x: 550 * kb.sx
            y: 422 * kb.sy
            name: "backspace"
            scaleFactor: kb.unit
            color: kb.textColor
            MouseArea {
                anchors.fill: parent
                anchors.margins: -14 * kb.unit
                onPressed: kb.doBackspace()
            }
        }
    }
}
