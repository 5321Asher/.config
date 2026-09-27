import QtQuick
import "../theme"

// An on/off switch: a brass bead in a slot. Emits toggled() on click.
Item {
    id: root

    property bool checked: false
    signal toggled()

    implicitWidth: 36
    implicitHeight: 18
    opacity: enabled ? 1 : 0.4

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.alpha(Theme.brassMuted, 0.9) : Theme.alpha(Theme.bgDark, 0.9)
        border.width: 1
        border.color: root.checked ? Theme.brass : Theme.border
        Behavior on color { ColorAnimation { duration: Theme.fast } }
    }
    Rectangle {
        width: parent.height - 6
        height: width
        radius: width / 2
        y: 3
        x: root.checked ? parent.width - width - 3 : 3
        color: root.checked ? Theme.brassBright : Theme.dim
        Behavior on x { NumberAnimation { duration: Theme.fast; easing.type: Theme.easing } }
    }
    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.enabled) root.toggled()
    }
}
