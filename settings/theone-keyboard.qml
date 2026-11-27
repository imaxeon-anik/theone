import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0
import Nemo.DBus 2.0

// Settings -> System -> theOne keyboard
Page {
    id: page

    property bool active: false
    property bool switching: false
    readonly property var modes: ["off", "silica"]
    readonly property int learnedCount: {
        try {
            return Object.keys(JSON.parse(String(learned.value)).w || {}).length
        } catch (e) {
            return 0
        }
    }

    // theOne is on when Maliit's config names it as the active plugin.
    function readActive() {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE)
                page.active = /active=theone\.qml/.test(xhr.responseText || "")
        }
        xhr.open("GET", "file://" + StandardPaths.home + "/.config/maliit.org/server.conf")
        xhr.send()
    }

    function setActive(on) {
        switching = true
        active = on
        // theone-keyboard@on.service / @off.service run `theone-keyboard on|off`.
        systemd.call("StartUnit", ["theone-keyboard@" + (on ? "on" : "off") + ".service", "replace"])
        recheck.restart()
    }

    Component.onCompleted: readActive()
    onStatusChanged: if (status === PageStatus.Activating) readActive()

    DBusInterface {
        id: systemd
        bus: DBus.SessionBus
        service: "org.freedesktop.systemd1"
        path: "/org/freedesktop/systemd1"
        iface: "org.freedesktop.systemd1.Manager"
    }

    Timer {
        id: recheck
        interval: 1500
        onTriggered: { page.switching = false; page.readActive() }
    }

    ConfigurationValue {
        id: ambience
        key: "/apps/theone-keyboard/ambience"
        defaultValue: "off"
    }

    ConfigurationValue {
        id: themeFont
        key: "/apps/theone-keyboard/sailfish-font"
        defaultValue: true
    }

    ConfigurationValue {
        id: wideKeys
        key: "/apps/theone-keyboard/wide-keys"
        defaultValue: false
    }

    ConfigurationValue {
        id: swipe
        key: "/apps/theone-keyboard/swipe"
        defaultValue: false
    }

    ConfigurationValue {
        id: learned
        key: "/apps/theone-keyboard/learned"
        defaultValue: ""
    }

    RemorsePopup { id: remorse }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        Column {
            id: column
            width: parent.width

            PageHeader {
                title: "theOne keyboard"
                // @VERSION@ is filled in when the package is built.
                description: "Version @VERSION@"
            }

            TextSwitch {
                text: "Use theOne keyboard"
                description: page.active
                             ? "theOne is your keyboard. Turn off to go back to the Sailfish keyboard."
                             : "The Sailfish keyboard is in use. Turn on to use theOne."
                automaticCheck: false
                checked: page.active
                busy: page.switching
                onClicked: if (!page.switching) page.setActive(!page.active)
            }

            SectionHeader { text: "Look" }

            ComboBox {
                id: modeBox
                label: "Style"
                currentIndex: Math.max(0, page.modes.indexOf(String(ambience.value)))
                description: [
                    "Dark rounded keys on a solid background.",
                    "Sailfish look: see-through glass keys over your ambience, in its own colours and font."
                ][currentIndex]
                menu: ContextMenu {
                    MenuItem { text: "theOne Classic"; onClicked: ambience.value = "off" }
                    MenuItem { text: "Sailfish"; onClicked: ambience.value = "silica" }
                }
            }

            TextSwitch {
                visible: String(ambience.value) === "silica"
                text: "Sailfish font"
                description: checked ? "Letters use Sailfish's own font."
                                     : "Letters keep theOne's own font (Inter)."
                automaticCheck: false
                checked: themeFont.value !== false
                onClicked: themeFont.value = !checked
            }

            ComboBox {
                label: "Key size"
                currentIndex: wideKeys.value === true ? 1 : 0
                description: currentIndex === 1
                             ? "Keys look a little bigger, with narrower gaps. Each key still responds to the same area."
                             : "Keys and gaps as designed."
                menu: ContextMenu {
                    MenuItem { text: "Standard"; onClicked: wideKeys.value = false }
                    MenuItem { text: "Wide"; onClicked: wideKeys.value = true }
                }
            }

            SectionHeader { text: "Typing" }

            TextSwitch {
                text: "Swipe typing"
                description: checked
                             ? "Slide your finger from letter to letter without lifting it, and theOne writes the word. Other guesses appear in the suggestion bar; backspace right after a swipe removes the word."
                             : "Type by tapping keys only. Turn on to also write words by sliding across the letters."
                automaticCheck: false
                checked: swipe.value === true
                onClicked: swipe.value = !checked
            }

            SectionHeader { text: "Suggestions" }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeSmall
                text: page.learnedCount === 0
                      ? "theOne hasn't learned any words yet. It learns the words you type so it stops correcting them and suggests them."
                      : (page.learnedCount === 1 ? "1 learned word." : page.learnedCount + " learned words.")
                        + " These are words you type that theOne suggests and won't correct."
            }

            Item { width: 1; height: Theme.paddingLarge }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Forget learned words"
                enabled: page.learnedCount > 0
                onClicked: remorse.execute("Forgetting learned words", function() { learned.value = "" })
            }
        }

        VerticalScrollDecorator {}
    }
}
