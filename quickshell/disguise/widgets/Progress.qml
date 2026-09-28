import QtQuick
import "../theme"

// A WinUI progress bar: a 1 px rail, a 3 px accent bar. value 0..1 (color overrides the accent)
Item {
    property real value: 0
    property color color: Theme.accent
    implicitHeight: 4
    implicitWidth: 200
    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 1; color: Theme.strong }
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, Math.min(1, parent.value)) * parent.width
        height: 3; radius: 1.5
        color: parent.color
        Behavior on width { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
    }
}
