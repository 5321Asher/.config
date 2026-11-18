import QtQuick
import "../theme"

// A two-state switch as a pair of tabs, ON | OFF, the live one lit (cyan) and the light sliding
// across when it changes.
Item {
    id: root

    property bool checked: false
    signal toggled()

    implicitWidth: 72
    implicitHeight: 22
    opacity: enabled ? 1 : 0.4

    Chamfer { anchors.fill: parent; cut: 5; corners: "tl br"; fill: Theme.alpha(Theme.bgDark, 0.6); stroke: root.checked ? Theme.alpha(Theme.cyan, 0.8) : Theme.line }
    Rectangle {           // the light
        x: root.checked ? 2 : parent.width / 2
        y: 2
        width: parent.width / 2 - 2
        height: parent.height - 4
        color: root.checked ? Theme.alpha(Theme.cyan, 0.85) : Theme.alpha(Theme.dim, 0.35)
        Behavior on x { NumberAnimation { duration: Theme.fast; easing.type: Theme.easing } }
    }
    Text {
        x: 0; width: parent.width / 2; anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: Text.AlignHCenter
        text: "ON"; color: root.checked ? Theme.bgDark : Theme.dim
        font.family: Theme.mono; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 1
    }
    Text {
        x: parent.width / 2; width: parent.width / 2; anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: Text.AlignHCenter
        text: "OFF"; color: root.checked ? Theme.dim : Theme.fg
        font.family: Theme.mono; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 1
    }
    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
