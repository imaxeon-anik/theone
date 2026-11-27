import QtQuick 2.6
import Nemo.Configuration 1.0

// Where learned words live between restarts (dconf). Loaded by Keyboard.qml through
// a Loader so the keyboard still runs where Nemo.Configuration is missing.
Item {
    property alias value: cfg.value
    property alias ambience: amb.value   // "off", "accent" or "full"
    property alias themeFont: tf.value   // Sailfish style: Sailfish's font (true) or Inter
    ConfigurationValue {
        id: tf
        key: "/apps/theone-keyboard/sailfish-font"
        defaultValue: true
    }
    property alias wideKeys: wk.value    // key size: false = standard, true = wide
    ConfigurationValue {
        id: wk
        key: "/apps/theone-keyboard/wide-keys"
        defaultValue: false
    }
    property alias swipe: sw.value       // swipe typing on (true) or off
    ConfigurationValue {
        id: sw
        key: "/apps/theone-keyboard/swipe"
        defaultValue: false
    }
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
