import QtQuick
import "../theme"

// A list row (networks, devices, drives, messages): a round glyph, a title and a label under it,
// things on the right. Active rows are the white pill (as the selected clipboard entry).
Item {
    id: root

    property string glyph: ""
    property string title: ""
    property string subtitle: ""
    property string trailing: ""
    property color trailingColor: Theme.grey
    property bool active: false
    default property alias extra: right.data
    signal clicked()

    width: parent ? parent.width : 300
    height: 64

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.active ? Theme.fg : mouse.containsMouse ? Theme.s2 : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.fast } }
    }
    Rectangle {
        id: disc
        x: 8
        anchors.verticalCenter: parent.verticalCenter
        width: 48
        height: 48
        radius: 24
        color: root.active ? Theme.ink : Theme.s2
        Icon { anchors.centerIn: parent; text: root.glyph; font.pixelSize: 20; color: root.active ? Theme.fg : Theme.fg }
    }
    Column {
        anchors { left: disc.right; leftMargin: 16; right: right.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
        spacing: 3
        Text {
            width: parent.width
            elide: Text.ElideRight
            text: root.title
            color: root.active ? Theme.ink : Theme.fg
            font { family: Theme.ui; pixelSize: 16 }
        }
        Lb { visible: root.subtitle !== ""; width: parent.width; elide: Text.ElideRight; text: root.subtitle; px: 10; color: root.active ? Theme.ink : Theme.grey; opacity: root.active ? 0.7 : 1 }
    }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
    Row {
        id: right
        anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
        spacing: 8
        Lb { anchors.verticalCenter: parent.verticalCenter; visible: root.trailing !== ""; text: root.trailing; color: root.active ? Theme.ink : root.trailingColor; px: 10 }
    }
}
