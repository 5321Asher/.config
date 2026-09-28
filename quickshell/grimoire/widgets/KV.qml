import QtQuick
import "../theme"

// A key and its value with a dotted leader between, like a table of contents:
//   Temperature · · · · · · · · 54°
Item {
    id: root

    property string key: ""
    property string value: ""
    property color color: Theme.ink
    signal clicked()

    width: parent ? parent.width : 300
    height: 22

    Body { id: k; anchors.verticalCenter: parent.verticalCenter; text: root.key; italic: true; color: Theme.inkDim }
    Text {
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 3
        x: k.width + 6
        width: Math.max(0, v.x - x - 6)
        clip: true
        text: "· ".repeat(80)
        color: Theme.alpha(Theme.inkDim, 0.5)
        font.family: Theme.body
        font.pixelSize: Theme.small
    }
    Body {
        id: v
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, root.width - k.width - 30)
        elide: Text.ElideLeft
        horizontalAlignment: Text.AlignRight
        text: root.value
        strong: true
        color: root.color
    }
    MouseArea { anchors.fill: parent; onClicked: root.clicked() }
}
