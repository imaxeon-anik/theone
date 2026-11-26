// theOne: Maliit input method plugin entry point.
// Installed to %{_libdir}/maliit/plugins/theone.qml; the keyboard itself lives in the
// org.theone.keyboard QML module under /usr/share/maliit/plugins.
import QtQuick 2.6
import com.meego.maliitquick 1.0
import org.theone.keyboard 1.0

Item {
    id: root

    width: MInputMethodQuick.screenWidth
    height: MInputMethodQuick.screenHeight

    readonly property int angle: MInputMethodQuick.appOrientation
    readonly property bool landscape: angle === 90 || angle === 270

    Item {
        id: canvas
        width: root.landscape ? root.height : root.width
        height: root.landscape ? root.width : root.height
        anchors.centerIn: parent
        rotation: root.angle

        Keyboard {
            id: keyboard
            width: parent.width
            maxHeight: canvas.height * (root.landscape ? 0.6 : 0.42)
            y: MInputMethodQuick.active ? canvas.height - height : canvas.height
            visible: MInputMethodQuick.active || slide.running
            Behavior on y { NumberAnimation { id: slide; duration: 180; easing.type: Easing.OutQuad } }

            actionLabel: MInputMethodQuick.actionKeyOverride ? MInputMethodQuick.actionKeyOverride.label : ""
            actionHighlighted: MInputMethodQuick.actionKeyOverride ? MInputMethodQuick.actionKeyOverride.highlighted : false
            actionEnabled: MInputMethodQuick.actionKeyOverride ? MInputMethodQuick.actionKeyOverride.enabled : true
            // No suggestions or autocorrect in passwords, URLs, e-mail and number fields.
            predictions: !MInputMethodQuick.hiddenText
                         && MInputMethodQuick.contentType === Maliit.FreeTextContentType
                         && MInputMethodQuick.predictionEnabled !== false

            onCommit: MInputMethodQuick.sendCommit(text, replaceStart, replaceLength)
            onBackspace: MInputMethodQuick.sendKey(Qt.Key_Backspace, 0, "\b", Maliit.KeyClick)
            onActionKey: MInputMethodQuick.activateActionKey()
            onCursorStep: MInputMethodQuick.sendKey(direction < 0 ? Qt.Key_Left : Qt.Key_Right,
                                                    0, "", Maliit.KeyClick)
            onContextWanted: root.syncContext(true)
            onHeightChanged: root.updateRegion()
        }
    }

    function updateRegion() {
        var r = Qt.rect(0, 0, 0, 0)
        if (MInputMethodQuick.active)
            r = canvas.mapToItem(root, 0, canvas.height - keyboard.height, canvas.width, keyboard.height)
        MInputMethodQuick.setInputMethodArea(r)
        MInputMethodQuick.setScreenRegion(r)
    }

    function updateAutoCaps() {
        var allowed = MInputMethodQuick.autoCapitalizationEnabled
                && !MInputMethodQuick.hiddenText
                && MInputMethodQuick.contentType === Maliit.FreeTextContentType
        var start = false
        if (allowed) {
            if (MInputMethodQuick.surroundingTextValid) {
                var before = MInputMethodQuick.surroundingText.substring(0, MInputMethodQuick.cursorPosition)
                start = /^\s*$/.test(before) || /[.!?]\s+$/.test(before) || /\n\s*$/.test(before)
            } else {
                start = keyboard.recent === "" || /[.!?]\s$/.test(keyboard.recent)
            }
        }
        keyboard.applyAutoCaps(start)
    }

    function syncContext(force) {
        if (!MInputMethodQuick.surroundingTextValid)
            return
        var text = MInputMethodQuick.surroundingText, pos = MInputMethodQuick.cursorPosition
        keyboard.syncContext(text.substring(0, pos), text.substring(pos), force)
    }

    function pageForContent() {
        var t = MInputMethodQuick.contentType
        return (t === Maliit.NumberContentType || t === Maliit.PhoneNumberContentType) ? "numbers" : "letters"
    }

    Connections {
        target: MInputMethodQuick
        onActiveChanged: {
            if (MInputMethodQuick.active) {
                keyboard.reset()
                keyboard.page = root.pageForContent()
                root.syncContext(true)
                root.updateAutoCaps()
            } else {
                keyboard.endAllTouches()
                keyboard.flush()
            }
            root.updateRegion()
        }
        onAppOrientationChanged: root.updateRegion()
        onContentTypeChanged: keyboard.page = root.pageForContent()
        onInputMethodReset: {
            keyboard.recent = ""
            keyboard.resetWord()
            root.syncContext(true)
        }
        onSurroundingTextChanged: { root.syncContext(false); root.updateAutoCaps() }
        onCursorPositionChanged: { root.syncContext(false); root.updateAutoCaps() }
        onAutoCapitalizationChanged: root.updateAutoCaps()
    }

    onWidthChanged: updateRegion()
    onHeightChanged: updateRegion()
    Component.onCompleted: updateRegion()
}
