import QtQuick
import "../theme"

// A check box (or, radio: true, a radio button) with its label: 20 px, the accent when on.
Item {
    id: root

    property bool checked: false
    property bool radio: false
    property string text: ""
    signal toggled()

    implicitWidth: box.width + (text ? label.implicitWidth + 8 : 0)
    implicitHeight: 32
    opacity: enabled ? 1 : 0.45

    Rectangle {
        id: box
        width: 20; height: 20
        anchors.verticalCenter: parent.verticalCenter
        radius: root.radio ? 10 : Theme.radius
        color: root.checked ? (root.radio ? "transparent" : mouse.containsMouse ? Theme.accentHover : Theme.accent)
             : mouse.containsMouse ? Theme.subtle : Qt.alpha(Theme.text, 0.03)
        border.width: root.checked ? (root.radio ? 5 : 0) : 1
        border.color: root.checked ? Theme.accent : Theme.strong
        Rectangle {
            visible: root.radio && root.checked
            anchors.centerIn: parent
            readonly property int size: mouse.containsMouse ? 12 : 10
            width: size; height: size; radius: size / 2
            color: Theme.accentText
        }
        Glyph {
            visible: !root.radio && root.checked
            anchors.centerIn: parent
            g: ""
            size: 12
            color: Theme.accentText
        }
    }
    Txt {
        id: label
        x: box.width + 8
        height: parent.height
        text: root.text
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.toggled()
    }
}
