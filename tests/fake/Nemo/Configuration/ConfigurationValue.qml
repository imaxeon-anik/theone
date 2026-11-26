import QtQuick 2.6
// Stand-in for Nemo.Configuration: keeps the value in memory.
QtObject {
    property string key
    property var defaultValue
    property var value: defaultValue
}
