import QtQuick
import "../theme"

// A section of a rig page: "LEVELS // 音量" with a hairline under it and optional text at the
// right end; children stack below.
Column {
    id: root

    property string title: ""
    property string jp: ""
    property string trailing: ""
    property color trailingColor: Theme.dim
    default property alias content: body.data

    width: parent ? parent.width : 400
    spacing: 8

    Item {
        width: parent.width
        height: 18
        Row {
            spacing: 8
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 6; height: 6; color: Theme.red }
            Label { anchors.verticalCenter: parent.verticalCenter; text: root.title; strong: true; color: Theme.bright }
            Jp { anchors.verticalCenter: parent.verticalCenter; visible: text !== ""; text: root.jp }
        }
        Label { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: root.trailing; color: root.trailingColor }
    }
    Rectangle { width: parent.width; height: 1; color: Theme.line }
    Column {
        id: body
        width: parent.width
        spacing: 8
    }
}
