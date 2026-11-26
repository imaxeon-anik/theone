import QtQuick 2.6
import Nemo.Configuration 1.0

// Where learned words live between restarts (dconf). Loaded by Keyboard.qml through
// a Loader so the keyboard still runs where Nemo.Configuration is missing.
Item {
    property alias value: cfg.value
    property alias ambience: amb.value   // "off", "accent" or "full"
    property alias debug: dbg.value      // log what the keyboard sees (theone-keyboard debug on)
    ConfigurationValue {
        id: dbg
        key: "/apps/theone-keyboard/debug"
        defaultValue: false
    }
    ConfigurationValue {
        id: amb
        key: "/apps/theone-keyboard/ambience"
        defaultValue: "off"
    }
    ConfigurationValue {
        id: cfg
        key: "/apps/theone-keyboard/learned"
        defaultValue: ""
    }
}
