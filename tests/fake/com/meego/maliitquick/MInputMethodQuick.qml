pragma Singleton
import QtQuick 2.6
// Stand-in for the Maliit server object: keeps a text buffer and logs every call.
QtObject {
    property int screenWidth: 1080
    property int screenHeight: 2520
    property int appOrientation: 0
    property bool active: false
    property bool autoCapitalizationEnabled: true
    property bool hiddenText: false
    property bool predictionEnabled: true
    property int contentType: 0
    property bool surroundingTextValid: true
    property string surroundingText: ""
    property int cursorPosition: 0
    property var actionKeyOverride: null
    property var log: []
    signal autoCapitalizationChanged()
    signal inputMethodReset()
    property var area: null

    function sendCommit(text, replaceStart, replaceLength) {
        var c = cursorPosition, s = surroundingText
        var a = c + (replaceStart || 0), b = a + (replaceLength || 0)
        surroundingText = s.slice(0, a) + text + s.slice(b)
        cursorPosition = a + text.length
        log.push("commit:" + JSON.stringify(text))
    }
    function sendKey(key, mods, text, type) {
        if (key === Qt.Key_Backspace && cursorPosition > 0) {
            surroundingText = surroundingText.slice(0, cursorPosition - 1) + surroundingText.slice(cursorPosition)
            cursorPosition -= 1
        } else if (key === Qt.Key_Left) cursorPosition = Math.max(0, cursorPosition - 1)
        else if (key === Qt.Key_Right) cursorPosition = Math.min(surroundingText.length, cursorPosition + 1)
        log.push("key:" + key)
    }
    function activateActionKey() { log.push("action") }
    function setInputMethodArea(r) { area = r }
    function setScreenRegion(r) {}
}
