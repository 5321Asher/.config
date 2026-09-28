import QtQuick
import "../theme"

// A list row on a page: an icon, a title with a line in italic under it, things on the right. The
// active row gets a red ink mark in the margin and a wash of gold; hovering, a lighter wash.
Item {
    id: root

    property string glyph: ""
    property string title: ""
    property string subtitle: ""
    property string trailing: ""
    property color trailingColor: Theme.inkDim
    property bool active: false
    default property alias extra: right.data
    signal clicked()

    width: parent ? parent.width : 300
    height: subtitle ? 46 : 34

    Rectangle {
        anchors.fill: parent
        radius: 3
        color: root.active ? Theme.alpha(Theme.gold, 0.2) : mouse.containsMouse ? Theme.alpha(Theme.gold, 0.1) : "transparent"
    }
    Text {
        visible: root.active
        x: -14
        anchors.verticalCenter: parent.verticalCenter
        text: "❧"
        color: Theme.rubric
        font.family: Theme.symbols
        font.pixelSize: 12
    }
    Glyph {
        id: g
        x: 8
        anchors.verticalCenter: parent.verticalCenter
        width: 20
        text: root.glyph
        color: root.active ? Theme.rubric : Theme.inkDim
    }
    Column {
        x: g.x + g.width + 8
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - x - right.width - 16
        Body { width: parent.width; elide: Text.ElideRight; text: root.title; strong: root.active; font.pixelSize: Theme.text }
        Body { visible: root.subtitle !== ""; width: parent.width; elide: Text.ElideRight; text: root.subtitle; italic: true
               color: Theme.inkDim; font.pixelSize: Theme.small + 1 }
    }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.clicked() }
    Row {
        id: right
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
        Body { anchors.verticalCenter: parent.verticalCenter; visible: root.trailing !== ""; text: root.trailing; italic: true
               color: root.trailingColor; font.pixelSize: Theme.small + 1 }
    }
}
