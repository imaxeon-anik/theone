pragma Singleton
import QtQuick 2.6
// Stand-in for Silica's Theme with a changeable ambience.
QtObject {
    enum ColorScheme { LightOnDark, DarkOnLight }
    property color highlightColor: "#ff8c2e"
    property int colorScheme: 0
}
