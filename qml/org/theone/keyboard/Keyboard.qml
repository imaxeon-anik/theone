import QtQuick 2.6
import "Layouts.js" as L
import "Predict.js" as P
import "Swipe.js" as S

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
    // Style: "off" is the iOS look as is (dark); "silica" draws the same keys the Sailfish
    // way, in the ambience's colours and font over a see-through, dimmed panel.
    // Shapes and sizes never change.
    property var previewAmbience: null   // { mode, light, highlight, dimmer, primary } for the desktop preview
    readonly property string ambienceMode: previewAmbience ? previewAmbience.mode
                                         : store.item ? String(store.item.ambience) : "off"
    readonly property color ambienceColor: previewAmbience ? previewAmbience.highlight
                                         : sailfish.item ? sailfish.item.highlight : "#0a84ff"
    readonly property bool silica: ambienceMode === "silica"
    property alias storeLoader: store   // settings (tests)
    // Key size "wide": every key is drawn 1.5 units bigger on each side (gaps 9 -> 6).
    // Only the drawing changes; touches still go to the nearest key, so the boundary
    // between two keys stays in the middle of the gap.
    readonly property bool wideKeys: previewAmbience && previewAmbience.wide !== undefined ? previewAmbience.wide
                                   : store.item ? store.item.wideKeys === true : false
    readonly property real grow: wideKeys ? 1.5 : 0
    // Swipe typing (Settings -> theOne keyboard -> Swipe typing). Off by default.
    readonly property bool swipeEnabled: previewAmbience && previewAmbience.swipe !== undefined ? previewAmbience.swipe
                                       : store.item ? store.item.swipe === true : false
    readonly property bool themeLight: previewAmbience ? previewAmbience.light
                                     : sailfish.item ? sailfish.item.light : false
    readonly property bool light: silica && themeLight
    readonly property color themePrimary: previewAmbience ? (previewAmbience.primary || (themeLight ? "#000000" : "#ffffff"))
                                        : sailfish.item ? sailfish.item.primary : "#ffffff"
    readonly property color themeDimmer: previewAmbience ? (previewAmbience.dimmer || "#000000")
                                       : sailfish.item ? sailfish.item.dimmer : "#000000"

    function mix(base, c, amount) {
        return Qt.tint(base, Qt.rgba(c.r, c.g, c.b, amount))
    }
    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a)
    }
    function luma(c) {
        return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
    }

    color: silica ? alpha(themeDimmer, light ? 0.72 : 0.82) : "#1f1f1f"
    // An opaque version of the background, for things drawn on top (emoji icon details).
    readonly property color solidColor: silica ? mix(themeDimmer, themePrimary, 0.12) : color
    readonly property color keyColor: silica ? alpha(themePrimary, light ? 0.16 : 0.14) : "#434343"
    readonly property color keyPressedColor: silica ? alpha(ambienceColor, 0.45) : "#6b6b6b"
    readonly property color textColor: silica ? themePrimary : "#ffffff"
    readonly property color accentColor: silica ? ambienceColor : "#0a84ff"
    readonly property color accentTextColor: luma(accentColor) > 0.62 ? "#000000" : "#ffffff"
    readonly property color barHighlightColor: silica ? alpha(ambienceColor, 0.4) : keyColor
    readonly property color barHighlightTextColor: silica ? (light ? themePrimary : ambienceColor) : textColor
    readonly property color separatorColor: silica ? alpha(themePrimary, 0.25) : "#4f4f4f"
    readonly property color popupBorderColor: silica ? alpha(ambienceColor, 0.8) : "#2a2a2a"
    // The letter balloon has to be solid to cover the keys under it.
    readonly property color popupColor: silica ? mix(themeDimmer, ambienceColor, light ? 0.25 : 0.35) : keyColor
    readonly property string themeFont: previewAmbience ? (previewAmbience.font || "")
                                      : sailfish.item ? sailfish.item.fontFamily : ""
    // Settings -> "Sailfish font": off keeps Inter in the Sailfish style too.
    readonly property bool useThemeFont: previewAmbience ? previewAmbience.font !== undefined
                                       : store.item ? store.item.themeFont !== false : true
    readonly property string fontFamily: silica && useThemeFont && themeFont !== "" ? themeFont
                                       : inter.status === FontLoader.Ready ? inter.name : ""
    FontLoader { id: inter; source: "fonts/Inter-Regular.ttf" }

    // --- state ----------------------------------------------------------------------
    property string page: "letters"        // letters | numbers | symbols | emoji
    // Emoji search: the letter keys type into searchText (not the app) and the
    // suggestion bar shows the search field and the matching emoji.
    property bool emojiSearch: false
    property string searchText: ""
    readonly property var searchResults: emojiSearch ? L.searchEmoji(searchText, 60) : []
    onPageChanged: if (page === "emoji") emojiSearch = false
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
    signal contextWanted()          // asks the plugin to call syncContext() with fresh text

    // --- suggestions ----------------------------------------------------------------
    property bool predictions: true
    property string word: ""          // letters of the word being typed
    property string prevWord: ""      // the word before it, for next-word predictions
    property bool brokenWord: false   // cursor sits in a token we don't predict (abc1|, mid-word)
    property bool sentenceStart: true
    property string rejected: ""      // a word the user undid the correction of
    property var lastCorrection: null // { original, corrected, sep, prev } until the next key
    property double lastEditTime: 0
    property var bar: []              // [{ text, quoted, auto }]
    property int barPressed: -1
    readonly property bool barVisible: predictions && page !== "emoji" && !emojiSearch
    // Swiping needs the word list, so not in password, URL, e-mail or number fields.
    readonly property bool canSwipe: swipeEnabled && predictions && page === "letters" && !emojiSearch
    property var swiped: null         // { text, items } the word a swipe just wrote, until it is finished
    property bool swiping: false
    readonly property real barHeight: L.BAND[0][0] * sy

    onWordChanged: barTimer.restart()
    onSwipeEnabledChanged: if (swipeEnabled) indexTimer.restart()
    Timer { id: indexTimer; interval: 300; onTriggered: S.buildIndex() }
    onPrevWordChanged: barTimer.restart()
    onBrokenWordChanged: barTimer.restart()
    onPredictionsChanged: barTimer.restart()
    onSentenceStartChanged: barTimer.restart()

    // Local memory of what was just typed, for double-space and auto-capitals when the
    // editor does not report its text.
    property string recent: ""
    property double lastSpaceTime: 0
    property double lastShiftTime: 0

    function reset() {
        page = "letters"
        emojiSearch = false
        searchText = ""
        shiftState = 0
        autoShifted = false
        recent = ""
        trackpad = false
        resetWord()
        prevWord = ""
        endAllTouches()
    }

    function resetWord() {
        swiped = null
        word = ""
        brokenWord = false
        rejected = ""
        lastCorrection = null
    }

    function isLetter(c) {
        return c.length === 1 && c.toLowerCase() !== c.toUpperCase()
    }

    // The plugin reports the text around the cursor. Our own typing is tracked locally,
    // because the editor's echo can lag behind fast typing; we only adopt the editor's
    // view when we have not typed for a moment (or when asked to, force).
    function syncContext(before, after, force) {
        if (!force && Date.now() - lastEditTime < 400) {
            syncTimer.restart()
            return
        }
        var run = /\S*$/.exec(before)[0]
        var tok = /[A-Za-z\u00C0-\u024F']*$/.exec(run)[0].replace(/^'+/, "")
        var glued = tok.length < run.length
                && /[0-9A-Za-z\u00C0-\u024F@#_&$%*+=<>\\\/]/.test(run.charAt(run.length - tok.length - 1))
        var broken = glued || /^[0-9A-Za-z\u00C0-\u024F]/.test(after || "")
        recent = before.slice(-4)
        var newWord = broken ? "" : tok
        if (newWord === word && broken === brokenWord)
            return
        word = newWord
        brokenWord = broken
        rejected = ""
        lastCorrection = null
        swiped = null
        var pm = /([A-Za-z\u00C0-\u024F']+)[\s,;:]*$/.exec(before.slice(0, before.length - run.length))
        prevWord = pm ? pm[1] : ""
    }

    function updateBar() {
        if (!predictions) {
            bar = []
            return
        }
        P.init()
        var items = []
        if (brokenWord) {
            items = []
        } else if (swiped && word === swiped.text) {
            // After a swipe: the word it wrote (highlighted) and the next best guesses.
            for (var a = 0; a < swiped.items.length && a < 3; ++a)
                items.push({ text: swiped.items[a], quoted: false, auto: a === 0 })
        } else if (word !== "") {
            var s = P.suggest(word)
            var auto = word === rejected ? "" : s.auto
            items.push({ text: word, quoted: true, auto: false })
            for (var i = 0; i < s.items.length && items.length < 3; ++i)
                items.push({ text: s.items[i], quoted: false, auto: auto !== "" && s.items[i] === auto })
        } else {
            var n = P.next(prevWord, sentenceStart)
            for (var j = 0; j < n.length; ++j)
                items.push({ text: n[j], quoted: false, auto: false })
        }
        bar = items
        if (debug)
            log("bar " + JSON.stringify(items.map(function (it) { return it.text })))
    }

    // Finish the current word with sep (" ", ".", "" for return), applying autocorrect.
    function endWord(sep) {
        lastEditTime = Date.now()
        syncTimer.restart()
        var typed = brokenWord ? "" : word
        var result = typed
        var wasSwiped = swiped !== null && typed === swiped.text
        swiped = null
        var auto = (predictions && typed !== "" && typed !== rejected && !wasSwiped) ? P.suggest(typed).auto : ""
        if (auto !== "" && auto !== typed) {
            commit(auto + sep, -typed.length, typed.length)
            lastCorrection = { original: typed, corrected: auto, sep: sep, prev: prevWord }
            result = auto
        } else {
            if (sep !== "")
                commit(sep, 0, 0)
            lastCorrection = null
        }
        if (predictions && typed !== "") {
            P.learn(result, prevWord, typed === rejected)
            saveTimer.restart()
        }
        recent = (recent.slice(0, Math.max(0, recent.length - typed.length)) + result + sep).slice(-4)
        if (typed !== "")
            prevWord = result
        if (/[.!?]/.test(sep))
            prevWord = ""
        word = ""
        rejected = ""
        brokenWord = false
    }

    function pickSuggestion(i) {
        var it = bar[i]
        if (!it)
            return
        lastEditTime = Date.now()
        syncTimer.restart()
        var typed = brokenWord ? "" : word
        var lead = (typed === "" && recent !== "" && !/\s$/.test(recent)) ? " " : ""
        commit(lead + it.text + " ", -typed.length, typed.length)
        if (predictions) {
            P.learn(it.text, prevWord, it.quoted)
            saveTimer.restart()
        }
        prevWord = it.text
        swiped = null
        word = ""
        rejected = ""
        brokenWord = false
        lastCorrection = null
        recent = (it.text + " ").slice(-4)
        lastSpaceTime = 0
        if (shiftState === 1) {
            shiftState = 0
            autoShifted = false
        }
    }

    // What theOne last wrote to dconf, to tell its own saves from outside changes
    // (Settings -> theOne keyboard -> Forget learned words).
    property string savedLearned: ""

    // Diagnostics, off unless `theone-keyboard debug on`. Shows up in the journal.
    readonly property bool debug: store.item ? store.item.debug === true : false
    function log(msg) {
        if (debug)
            console.warn("theOne: " + msg)
    }

    function flush() {
        if (store.item && P.dirty) {
            savedLearned = P.dump()
            store.item.value = savedLearned
        }
    }

    // Called by the plugin when the editor's text/cursor changes.
    function applyAutoCaps(atSentenceStart) {
        if (shiftState === 2)
            return
        sentenceStart = atSentenceStart
        if (atSentenceStart && shiftState === 0) {
            shiftState = 1
            autoShifted = true
        } else if (!atSentenceStart && shiftState === 1 && autoShifted) {
            shiftState = 0
            autoShifted = false
        }
    }

    // Write the word a swipe drew. points: the finger's path in reference units.
    function swipeWord(points) {
        lastEditTime = Date.now()
        syncTimer.restart()
        if (word !== "" && !brokenWord)
            endWord(" ")              // the word before it (typed or swiped) is finished
        var res = S.decode(points, prevWord, 4)
        log("swipe " + points.length + " points -> " + JSON.stringify(res.map(function (r) { return r.w })))
        if (res.length === 0)
            return
        // Upper case with caps lock, a capital after shift or at a sentence start.
        var cap = shiftState === 2 ? "AA" : shiftState === 1 ? "A" : ""
        var items = res.map(function (r) { return P.display(r.w, cap) })
        var lead = /[0-9A-Za-z\u00C0-\u024F.,!?;:)]$/.test(recent) ? " " : ""
        commit(lead + items[0], 0, 0)
        lastCorrection = null
        rejected = ""
        brokenWord = false
        swiped = { text: items[0], items: items.slice(0, 3) }
        word = items[0]
        recent = (recent + lead + items[0]).slice(-4)
        lastSpaceTime = 0
        if (shiftState === 1) {
            shiftState = 0
            autoShifted = false
        }
        updateBar()
    }

    function labelFor(k) {
        if (k.type !== "char")
            return ""
        return (page === "letters" && shiftState > 0 && !emojiSearch) ? k.ch.toUpperCase() : k.ch
    }

    function startEmojiSearch() {
        searchText = ""
        page = "letters"
        emojiSearch = true
    }

    // Leave the search: Done goes on to typing, the emoji key back to the emoji page.
    function endEmojiSearch(toPage) {
        emojiSearch = false
        searchText = ""
        page = toPage
    }

    // direct: write t to the app even while searching (a picked emoji).
    function typeText(t, direct) {
        if (emojiSearch && !direct) {
            searchText = (searchText + t.toLowerCase()).slice(0, 40)
            return
        }
        lastEditTime = Date.now()
        syncTimer.restart()
        lastCorrection = null
        // Punctuation finishes a swiped word (endWord); anything else makes it the user's own.
        if (swiped && !/^[.,!?;:)"]$/.test(t))
            swiped = null
        if (isLetter(t) || (t === "'" && word !== "")) {
            if (word === "" && /[0-9A-Za-z\u00C0-\u024F]$/.test(recent))
                brokenWord = true
            commit(t, 0, 0)
            if (!brokenWord)
                word += t
        } else if (/^[.,!?;:)"]$/.test(t) && word !== "") {
            endWord(t)
            recent = recent.slice(0, -1)    // endWord already added t
        } else {
            commit(t, 0, 0)
            word = ""
            rejected = ""
            brokenWord = /[0-9@#_&$%*+=<>\\\/]/.test(t)
            if (/[.!?]/.test(t))
                prevWord = ""
        }
        recent = (recent + t).slice(-4)
        if (shiftState === 1) {
            shiftState = 0
            autoShifted = false
        }
    }

    function typeSpace() {
        if (emojiSearch) {
            if (searchText !== "" && !/ $/.test(searchText))
                searchText += " "
            return
        }
        var now = Date.now()
        if (word === "" && /[^\s.!?]\s$/.test(recent) && now - lastSpaceTime < 700) {
            lastEditTime = now
            syncTimer.restart()
            commit(". ", -1, 1)          // replace the space just typed
            recent = (recent.slice(0, -1) + ". ").slice(-4)
            lastSpaceTime = 0
            lastCorrection = null
            prevWord = ""
        } else {
            endWord(" ")
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
        if (emojiSearch) {
            searchText = searchText.slice(0, -1)
            return
        }
        lastEditTime = Date.now()
        syncTimer.restart()
        if (swiped && word === swiped.text) {
            // Right after a swipe, backspace takes the whole word away.
            var n = word.length
            commit("", -n, n)
            recent = recent.slice(0, Math.max(0, recent.length - n))
            swiped = null
            word = ""
            rejected = ""
            return
        }
        var c = lastCorrection
        if (c) {
            // Undo the autocorrection that was just made, and keep the typed word.
            var len = c.corrected.length + c.sep.length
            commit(c.original, -len, len)
            lastCorrection = null
            word = c.original
            rejected = c.original
            prevWord = c.prev
            brokenWord = false
            recent = (recent.slice(0, Math.max(0, recent.length - len)) + c.original).slice(-4)
            return
        }
        backspace()
        recent = recent.slice(0, -1)
        if (word !== "")
            word = word.slice(0, -1)
        rejected = ""
    }

    // --- key drawing ----------------------------------------------------------------
    Repeater {
        model: kb.page === "emoji" ? [] : kb.keys
        delegate: Rectangle {
            readonly property var k: modelData
            readonly property bool down: kb.pressedIndexes.indexOf(k.index) >= 0
            x: (k.x - (k.bare ? 0 : kb.grow)) * kb.sx
            y: k.y * kb.sy
            width: (k.w + (k.bare ? 0 : 2 * kb.grow)) * kb.sx
            height: k.h * kb.sy
            radius: 10 * kb.unit
            // iOS colours the return key only for Go/Send; the Sailfish style always does.
            readonly property bool lit: k.type === "return" && (kb.actionHighlighted || kb.silica)
            color: k.bare ? "transparent"
                 : lit ? kb.accentColor
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
                    : (k.type === "return" && kb.emojiSearch) ? "Done"
                    : (k.type === "return" && kb.actionLabel !== "") ? kb.actionLabel
                    : ""
                color: parent.lit ? kb.accentTextColor : kb.textColor
                opacity: (k.type === "return" && !kb.actionEnabled && !kb.emojiSearch) ? 0.4 : 1
                font.family: kb.fontFamily
                font.pixelSize: (k.type === "char" ? 30 : 26) * kb.unit
            }

            Icon {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: (k.type === "return" ? -0.6 : 0.8) * kb.unit
                visible: name !== "" && !kb.trackpad
                scaleFactor: kb.unit
                color: parent.lit ? kb.accentTextColor : kb.textColor
                cutout: kb.solidColor
                // The search is always lower case, so shift shows off there.
                name: k.type === "shift" ? (kb.emojiSearch ? "shift" : kb.shiftState === 2 ? "capsLock" : kb.shiftState === 1 ? "shiftOn" : "shift")
                    : k.type === "backspace" ? "backspace"
                    : (k.type === "return" && kb.actionLabel === "" && !kb.emojiSearch) ? "return"
                    : ""
            }

            Icon {
                visible: k.type === "emoji"
                x: (L.STRIP_ICON.cx - k.x) * kb.sx - width / 2
                y: (L.STRIP_ICON.cy - k.y) * kb.sy - height / 2
                scaleFactor: kb.unit
                color: kb.textColor
                cutout: kb.solidColor
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
            if (touches[id].key && !touches[id].done && touches[id].mode !== "swipe")
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
        if (barVisible && py < barHeight) {
            touches[id] = { key: null, bar: Math.floor(px / (width / 3)), startX: px, lastX: px, done: false, mode: "" }
            barPressed = bar[touches[id].bar] ? touches[id].bar : -1
            return
        }
        touches[id] = { key: k, startX: px, startY: py, lastX: px, done: false, mode: "",
                        path: (canSwipe && k && k.type === "char") ? [{ x: px / sx, y: py / sy }] : null }
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
        if (t.path) {
            t.path.push({ x: px / sx, y: py / sy })
            if (t.mode === "swipe") {
                trail.add(px, py)
                return
            }
            // Moving further than about one key from where the finger landed starts a swipe;
            // shorter slides still just move to the neighbouring letter.
            var dx = (px - t.startX) / sx, dy = (py - t.startY) / sy
            if (t.mode === "" && dx * dx + dy * dy > 1.21 * L.PITCH * L.PITCH && onlyTouch(id)) {
                startSwipe(id)
                return
            }
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
        if (t.mode === "swipe") {
            swiping = false
            trail.clear()
            if (!cancelled)
                swipeWord(t.path)
            refreshPressed()
            return
        }
        if (t.bar !== undefined) {
            barPressed = -1
            if (!cancelled && py < barHeight && Math.floor(px / (width / 3)) === t.bar)
                pickSuggestion(t.bar)
            return
        }
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
            } else if (k.type === "return" && emojiSearch) {
                endEmojiSearch("letters")
            } else if (k.type === "return") {
                if (word !== "")
                    endWord("")
                lastCorrection = null
                prevWord = ""
                if (actionEnabled)
                    actionKey()
                recent = ""
            } else if (k.type === "mode") {
                page = k.target
            } else if (k.type === "emoji") {
                if (emojiSearch)
                    endEmojiSearch("emoji")
                page = "emoji"
            }
        }
        if (popupKey && t.key === popupKey)
            showPopupFor(null)
        refreshPressed()
    }

    function onlyTouch(id) {
        for (var other in touches)
            if (other != id && !touches[other].done)
                return false
        return true
    }

    function startSwipe(id) {
        var t = touches[id]
        t.mode = "swipe"
        swiping = true
        holdTimer.stop()
        showPopupFor(null)
        trail.clear()
        for (var i = 0; i < t.path.length; ++i)
            trail.add(t.path[i].x * sx, t.path[i].y * sy)
        refreshPressed()
    }

    function endAllTouches() {
        swiping = false
        trail.clear()
        touches = ({})
        holdTimer.stop()
        repeatTimer.stop()
        popupKey = null
        accentKey = null
        barPressed = -1
        setPressed([])
    }

    function enterTrackpad(id) {
        var t = touches[id]
        if (!t || t.done || emojiSearch)
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

    Timer {
        id: barTimer
        interval: 1
        onTriggered: kb.updateBar()
    }

    Timer {
        id: syncTimer
        interval: 450
        onTriggered: kb.contextWanted()
    }

    // Learned words are kept in dconf (Nemo.Configuration). Without it (desktop
    // preview), learning still works but is forgotten on restart.
    // Ambience colours from Silica's Theme (missing on the desktop preview).
    Loader {
        id: sailfish
        source: "Ambience.qml"
    }
    readonly property string themeStatus: sailfish.status === Loader.Ready ? "loaded"
                                        : sailfish.status === Loader.Error ? "failed" : "loading"

    Loader {
        id: store
        source: "Store.qml"
        onLoaded: {
            kb.savedLearned = String(item.value)
            P.load(item.value)
            barTimer.restart()
        }
    }

    Connections {
        target: store.item
        onValueChanged: {
            var v = String(store.item.value)
            if (v !== kb.savedLearned) {
                kb.savedLearned = v
                P.load(v)
                kb.updateBar()
            }
        }
    }

    Timer {
        id: saveTimer
        interval: 4000
        onTriggered: kb.flush()
    }

    // Load the dictionary shortly after start, not on the first key press.
    Timer {
        running: true
        interval: 300
        onTriggered: { P.init(); kb.updateBar(); if (kb.swipeEnabled) S.buildIndex() }
    }

    // --- suggestion bar -------------------------------------------------------------
    Item {
        id: barView
        visible: kb.barVisible && !kb.trackpad
        width: kb.width
        height: kb.barHeight
        readonly property real slotW: width / 3

        Repeater {
            model: 3
            delegate: Item {
                readonly property var item: kb.bar.length > index ? kb.bar[index] : null
                readonly property bool lit: item !== null && (kb.barPressed === index || item.auto)
                x: index * barView.slotW
                width: barView.slotW
                height: barView.height

                Rectangle {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 1 * kb.sy
                    width: parent.width - 10 * kb.unit
                    height: 48 * kb.sy
                    radius: 9 * kb.unit
                    visible: parent.lit
                    color: kb.barPressed === index ? kb.keyPressedColor : kb.barHighlightColor
                }
                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 1 * kb.sy
                    width: parent.width - 24 * kb.unit
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideMiddle
                    text: parent.item ? (parent.item.quoted ? "\u201C" + parent.item.text + "\u201D" : parent.item.text) : ""
                    color: parent.lit && kb.barPressed !== index && kb.silica ? kb.barHighlightTextColor : kb.textColor
                    font.family: kb.fontFamily
                    font.pixelSize: 24 * kb.unit
                }
            }
        }

        Repeater {
            model: 2
            delegate: Rectangle {
                readonly property var leftItem: kb.bar.length > index ? kb.bar[index] : null
                readonly property var rightItem: kb.bar.length > index + 1 ? kb.bar[index + 1] : null
                x: (index + 1) * barView.slotW - width / 2
                y: 19 * kb.sy
                width: Math.max(1, 1.5 * kb.unit)
                height: 30 * kb.sy
                color: kb.separatorColor
                visible: leftItem !== null && rightItem !== null && !leftItem.auto && !rightItem.auto
                         && kb.barPressed !== index && kb.barPressed !== index + 1
            }
        }
    }

    // The line a swipe draws. Only the last stretch is kept, so it trails the finger.
    Canvas {
        id: trail
        anchors.fill: parent
        visible: kb.swiping
        property var pts: []
        function add(x, y) {
            pts.push({ x: x, y: y })
            if (pts.length > 40)
                pts.shift()
            requestPaint()
        }
        function clear() {
            pts = []
            requestPaint()
        }
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            if (pts.length < 2)
                return
            ctx.lineCap = "round"
            ctx.lineJoin = "round"
            ctx.lineWidth = 9 * kb.unit
            ctx.strokeStyle = kb.alpha(kb.accentColor, 0.6)
            ctx.beginPath()
            ctx.moveTo(pts[0].x, pts[0].y)
            for (var i = 1; i < pts.length; ++i)
                ctx.lineTo(pts[i].x, pts[i].y)
            ctx.stroke()
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

    // --- emoji search row (in place of the suggestion bar) ---------------------------
    Item {
        id: searchRow
        visible: kb.emojiSearch && kb.page !== "emoji"
        width: kb.width
        height: kb.barHeight

        MouseArea { anchors.fill: parent }     // the row's touches never reach the keys

        Rectangle {
            id: searchField
            x: 9 * kb.sx
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 1 * kb.sy
            width: 200 * kb.sx
            height: 44 * kb.sy
            radius: height / 2
            color: kb.keyColor

            Icon {
                id: searchIcon
                x: 12 * kb.unit
                anchors.verticalCenter: parent.verticalCenter
                name: "search"
                scaleFactor: kb.unit
                color: kb.textColor
                opacity: 0.6
            }
            Text {
                id: searchLabel
                anchors.left: searchIcon.right
                anchors.leftMargin: 6 * kb.unit
                anchors.right: parent.right
                anchors.rightMargin: 14 * kb.unit
                anchors.verticalCenter: parent.verticalCenter
                // A no-break space at the end, so the cursor moves past a typed space.
                text: kb.searchText !== "" ? kb.searchText.replace(/ $/, "\u00a0") : "Search Emoji"
                color: kb.textColor
                opacity: kb.searchText !== "" ? 1 : 0.55
                elide: Text.ElideLeft
                font.family: kb.fontFamily
                font.pixelSize: 21 * kb.unit
            }
            Rectangle {
                // text cursor
                x: searchLabel.x + (kb.searchText !== "" ? Math.min(searchLabel.contentWidth, searchLabel.width) : 0) + 1 * kb.unit
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(1, 2 * kb.unit)
                height: 24 * kb.sy
                color: kb.accentColor
                SequentialAnimation on opacity {
                    running: searchRow.visible
                    loops: Animation.Infinite
                    NumberAnimation { to: 0; duration: 500; easing.type: Easing.InQuad }
                    NumberAnimation { to: 1; duration: 500; easing.type: Easing.OutQuad }
                }
            }
        }

        ListView {
            id: searchList
            anchors.left: searchField.right
            anchors.leftMargin: 6 * kb.sx
            anchors.right: parent.right
            height: parent.height
            orientation: ListView.Horizontal
            clip: true
            model: kb.searchResults
            delegate: Item {
                width: 58 * kb.unit
                height: searchList.height
                Image {
                    id: found
                    anchors.centerIn: parent
                    width: 40 * kb.unit
                    height: width
                    sourceSize.width: 72
                    sourceSize.height: 72
                    asynchronous: true
                    smooth: true
                    source: L.emojiFile(modelData)
                }
                Text {
                    visible: found.status === Image.Error
                    anchors.centerIn: parent
                    text: modelData
                    font.pixelSize: 36 * kb.unit
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: kb.typeText(modelData, true)
                }
            }
            onModelChanged: positionViewAtBeginning()
        }

        Text {
            anchors.left: searchList.left
            anchors.leftMargin: 10 * kb.unit
            anchors.verticalCenter: parent.verticalCenter
            visible: kb.searchText.replace(/ /g, "") !== "" && kb.searchResults.length === 0
            text: "No emoji found"
            color: kb.textColor
            opacity: 0.55
            font.family: kb.fontFamily
            font.pixelSize: 20 * kb.unit
        }
    }

    // --- popups ---------------------------------------------------------------------
    KeyPopup {
        anchors.fill: parent
        visible: kb.popupKey !== null
        kx: kb.popupKey ? (kb.popupKey.x - kb.grow) * kb.sx : 0
        ky: kb.popupKey ? kb.popupKey.y * kb.sy : 0
        kw: kb.popupKey ? (kb.popupKey.w + 2 * kb.grow) * kb.sx : 0
        kh: kb.popupKey ? kb.popupKey.h * kb.sy : 0
        text: kb.popupKey ? kb.labelFor(kb.popupKey) : ""
        color: kb.popupColor
        textColor: kb.textColor
        edgeColor: kb.silica ? kb.popupBorderColor : "transparent"
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
        color: kb.popupColor
        border.color: kb.popupBorderColor
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
                        color: index === kb.accentIndex ? kb.accentTextColor : kb.textColor
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

        Rectangle {
            id: searchPill
            x: 12 * kb.sx
            y: 14 * kb.sy
            width: parent.width - 24 * kb.sx
            height: 44 * kb.sy
            radius: height / 2
            color: kb.keyColor
            Icon {
                id: pillIcon
                x: 14 * kb.unit
                anchors.verticalCenter: parent.verticalCenter
                name: "search"
                scaleFactor: kb.unit
                color: kb.textColor
                opacity: 0.6
            }
            Text {
                anchors.left: pillIcon.right
                anchors.leftMargin: 8 * kb.unit
                anchors.verticalCenter: parent.verticalCenter
                text: "Search Emoji"
                color: kb.textColor
                opacity: 0.55
                font.family: kb.fontFamily
                font.pixelSize: 21 * kb.unit
            }
            MouseArea {
                anchors.fill: parent
                onClicked: kb.startEmojiSearch()
            }
        }

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
                Image {
                    id: pic
                    anchors.centerIn: parent
                    width: 44 * kb.unit
                    height: width
                    sourceSize.width: 72
                    sourceSize.height: 72
                    asynchronous: true
                    smooth: true
                    source: L.emojiFile(modelData)
                }
                Text {
                    // Only when there is no picture for it.
                    visible: pic.status === Image.Error
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
                delegate: Image {
                    width: 28 * kb.unit
                    height: width
                    sourceSize.width: 72
                    sourceSize.height: 72
                    smooth: true
                    source: L.emojiFile(L.EMOJI[index].icon)
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
