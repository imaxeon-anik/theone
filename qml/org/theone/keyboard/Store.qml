import QtQuick 2.6
import Nemo.Configuration 1.0

// Where learned words live between restarts (dconf). Loaded by Keyboard.qml through
// a Loader so the keyboard still runs where Nemo.Configuration is missing.
Item {
    property alias value: cfg.value
    ConfigurationValue {
        id: cfg
        key: "/apps/theone-keyboard/learned"
        defaultValue: ""
    }
}
