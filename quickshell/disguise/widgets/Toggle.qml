import QtQuick
import "../theme"

// A toggle switch: a 40 x 20 pill, the knob slides across; the accent when on. Optional label at
// the left ("On" / "Off" by default, as Settings shows).
Item {
    id: root

    property bool checked: false
    property bool showState: true
    signal toggled()

    implicitWidth: pill.width + (showState ? label.implicitWidth + 12 : 0)
    implicitHeight: 20
    opacity: enabled ? 1 : 0.45

    Txt {
        id: label
        visible: root.showState
        anchors.verticalCenter: parent.verticalCenter
        text: root.checked ? "On" : "Off"
    }
    Rectangle {
        id: pill
        anchors.right: parent.right
        width: 40; height: 20
        radius: 10
        color: root.checked ? (mouse.containsMouse ? Theme.accentHover : Theme.accent) : (mouse.containsMouse ? Theme.subtle : "transparent")
        border.width: root.checked ? 0 : 1
        border.color: Theme.strong
        Behavior on color { ColorAnimation { duration: Theme.fast } }
        Rectangle {
            readonly property int size: mouse.pressed ? 14 : mouse.containsMouse ? 14 : 12
            width: mouse.pressed ? 17 : size
            height: size
            radius: size / 2
            anchors.verticalCenter: parent.verticalCenter
            x: root.checked ? parent.width - width - 4 : 4
            color: root.checked ? Theme.accentText : Theme.text2
            Behavior on x { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: Theme.fast } }
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.toggled()
    }
}
