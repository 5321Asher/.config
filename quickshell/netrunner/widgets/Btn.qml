import QtQuick
import "../theme"

// A button: an outlined box with a tracked uppercase label ("EDIT", "SWEEP"); hover fills it
// faintly, `primary` outlines it in red, `on` fills it solid (a toggle that's on).
Item {
    id: root

    property string text: ""
    property string glyph: ""               // a Nerd Font glyph before the label
    property bool primary: false
    property bool on: false
    property color tint: primary || on ? Theme.red : Theme.line
    property alias hovered: mouse.containsMouse
    signal clicked()
    signal rightClicked()

    implicitWidth: row.implicitWidth + 24
    implicitHeight: 26
    opacity: enabled ? 1 : 0.4

    Chamfer {
        anchors.fill: parent
        cut: Theme.chamferSmall
        corners: "br"
        fill: root.on ? Theme.alpha(root.tint, 0.85) : mouse.containsMouse ? Theme.alpha(root.tint, 0.14) : "transparent"
        stroke: mouse.containsMouse || root.primary || root.on ? root.tint : Theme.line
    }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Text {
            visible: root.glyph !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.glyph
            color: label.color
            font.family: Theme.mono
            font.pixelSize: Theme.data
        }
        Label {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            visible: root.text !== ""
            text: root.text
            strong: true
            color: root.on ? Theme.onRed : root.primary ? Theme.red : Theme.fg
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: e => e.button === Qt.RightButton ? root.rightClicked() : root.clicked()
    }
}
