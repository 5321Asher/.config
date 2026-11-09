import QtQuick
import "../theme"

// A key (label) and its value (Space Grotesk) on one line.
Item {
    id: root
    property string key: ""
    property string value: ""
    property color color: Theme.fg
    signal clicked()
    width: parent ? parent.width : 300
    height: 24
    Lb { anchors.verticalCenter: parent.verticalCenter; text: root.key }
    Text {
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        width: Math.min(implicitWidth, root.width - 150)
        elide: Text.ElideLeft
        horizontalAlignment: Text.AlignRight
        text: root.value
        color: root.color
        font { family: Theme.ui; pixelSize: 15 }
    }
    MouseArea { anchors.fill: parent; onClicked: root.clicked() }
}
