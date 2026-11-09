import QtQuick
import "../theme"

// A block of a page: a grey label on the left (title · subtitle), something on the right, then the
// content. No rules or boxes: Nothing separates with space.
Column {
    id: root

    property string title: ""
    property string sub: ""
    property string jp: ""                  // (old API; unused)
    property string trailing: ""
    property color trailingColor: Theme.grey
    default property alias content: body.data

    width: parent ? parent.width : 400
    spacing: 14

    Item {
        width: parent.width
        height: 16
        visible: root.title !== ""
        Lb { anchors.verticalCenter: parent.verticalCenter; text: root.title + (root.sub ? "  ·  " + root.sub : "") }
        Lb { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: root.trailing; color: root.trailingColor }
    }
    Column {
        id: body
        width: parent.width
        spacing: 10
    }
}
