import QtQuick 2.6
import Sailfish.Silica 1.0

// The current Sailfish ambience, as Keyboard.qml needs it. Loaded through a Loader
// so the keyboard still runs where Silica is missing (desktop preview).
Item {
    readonly property color highlight: Theme.highlightColor
    readonly property bool light: Theme.colorScheme === Theme.DarkOnLight
    // For the "silica" style.
    readonly property color primary: Theme.primaryColor
    readonly property color dimmer: Theme.highlightDimmerColor
    readonly property string fontFamily: Theme.fontFamily
}
