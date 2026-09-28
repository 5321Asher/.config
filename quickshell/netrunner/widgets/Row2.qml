import QtQuick
import "../theme"

// A list row: a glyph, a title with a line under it, something on the right; selected / active
// rows light red. Used for networks, devices, drives, players, messages.
Item {
    id: root

    property string glyph: ""
    property string title: ""
    property string subtitle: ""
    property string trailing: ""
    property color trailingColor: Theme.dim
    property bool active: false
    default property alias extra: right.data
    signal clicked()

    width: parent ? parent.width : 300
    height: subtitle ? 44 : 32

    Rectangle {
        anchors.fill: parent
        color: root.active ? Theme.alpha(Theme.red, 0.1) : mouse.containsMouse ? Theme.alpha(Theme.fg, 0.04) : "transparent"
        Rectangle { visible: root.active; width: 2; height: parent.height; color: Theme.red }
    }
    Text {
        id: g
        x: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 20
        text: root.glyph
        color: root.active ? Theme.red : Theme.dim
        font.family: Theme.mono
        font.pixelSize: 15
    }
    Column {
        x: g.x + g.width + 8
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - x - right.width - 20
        Text {
            width: parent.width
            elide: Text.ElideRight
            text: root.title
            color: root.active ? Theme.bright : Theme.fg
            font.family: Theme.sans
            font.pixelSize: Theme.data + 1
            font.weight: Font.Medium
        }
        Label { visible: root.subtitle !== ""; width: parent.width; elide: Text.ElideRight; text: root.subtitle; font.pixelSize: Theme.label - 1 }
    }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.clicked() }
    Row {
        id: right
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        Label { anchors.verticalCenter: parent.verticalCenter; visible: root.trailing !== ""; text: root.trailing; color: root.trailingColor }
    }
}
