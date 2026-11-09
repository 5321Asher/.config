import QtQuick
import "../theme"

// A pill button: a tracked label (and a glyph) on a dark pill; `on` makes it the white pill.
// `primary` is the one to press (white outline); `danger` lights the label red.
Item {
    id: root

    property string text: ""
    property string glyph: ""
    property bool primary: false
    property bool on: false
    property bool danger: false
    property alias hovered: mouse.containsMouse
    signal clicked()
    signal rightClicked()

    implicitWidth: row.implicitWidth + 36
    implicitHeight: 40
    opacity: enabled ? 1 : 0.4

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.on ? Theme.fg : mouse.containsMouse ? Theme.s3 : Theme.s2
        border { width: 1; color: root.primary && !root.on ? Theme.fg : "transparent" }
        Behavior on color { ColorAnimation { duration: Theme.fast } }
    }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8
        Icon {
            visible: root.glyph !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.glyph
            font.pixelSize: 16
            color: lab.color
        }
        Lb {
            id: lab
            anchors.verticalCenter: parent.verticalCenter
            visible: root.text !== ""
            text: root.text
            px: 11
            color: root.on ? Theme.ink : root.danger ? Theme.red : Theme.fg
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
