import QtQuick
import "../theme"

// A two-state switch drawn as a tiny segmented readout: [ ON ] lit in red, [ OFF ] dim.
Item {
    id: root

    property bool checked: false
    signal toggled()

    implicitWidth: 56
    implicitHeight: 20
    opacity: enabled ? 1 : 0.4

    Chamfer {
        anchors.fill: parent
        cut: 5
        corners: "tl br"
        fill: root.checked ? Theme.alpha(Theme.red, 0.18) : "transparent"
        stroke: root.checked ? Theme.red : Theme.line
    }
    Rectangle {
        x: root.checked ? parent.width - width - 4 : 4
        anchors.verticalCenter: parent.verticalCenter
        width: 8
        height: parent.height - 8
        color: root.checked ? Theme.red : Theme.dim
        Behavior on x { NumberAnimation { duration: Theme.fast; easing.type: Theme.easing } }
    }
    Label {
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? 8 : parent.width - width - 8
        text: root.checked ? "on" : "off"
        color: root.checked ? Theme.red : Theme.dim
        font.pixelSize: Theme.label - 1
    }
    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
