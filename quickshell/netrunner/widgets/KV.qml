import QtQuick
import "../theme"

// A key / value line: "SHIELD ............ UFW", the value in `color`. Clickable when onClicked is used.
Item {
    id: root
    property string key: ""
    property string value: ""
    property color color: Theme.fg
    signal clicked()
    width: parent ? parent.width : 300
    height: 18
    Label { text: root.key }
    Label { anchors.right: parent.right; text: root.value; color: root.color; strong: true; width: Math.min(implicitWidth, root.width - 140); elide: Text.ElideLeft; horizontalAlignment: Text.AlignRight }
    MouseArea { anchors.fill: parent; onClicked: root.clicked() }
}
