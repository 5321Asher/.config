import QtQuick
import "../theme"

// A card: a dark rounded tile with a hairline, a label at the top (title · trailing).
Item {
    id: root

    property string title: ""
    property string trailing: ""
    property color trailingColor: Theme.grey
    property real r: 40
    property bool round: false
    property string jp: ""                  // (old API; unused)
    property bool big: false
    property bool brackets: false
    default property alias content: body.data
    readonly property alias body: body

    Rectangle {
        anchors.fill: parent
        radius: root.round ? Math.min(width, height) / 2 : root.r
        color: Theme.s1
        border { width: 1; color: Theme.s2 }
    }
    Lb { id: head; x: 26; y: 24; visible: root.title !== ""; text: root.title }
    Lb { anchors { right: parent.right; rightMargin: 26 } y: 24; visible: text !== ""; text: root.trailing; color: root.trailingColor }
    Item {
        id: body
        x: 26
        y: root.title !== "" ? 56 : 24
        width: root.width - 52
        height: root.height - y - 24
    }
}
