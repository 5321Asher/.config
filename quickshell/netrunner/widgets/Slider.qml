import QtQuick
import "../theme"

// A level: a row of thin blocks, lit up to the value; drag, click or scroll to set it.
// moved(v) with v in 0..1.
Item {
    id: root

    property real value: 0
    property color color: Theme.cyan
    property int blocks: 32
    signal moved(real v)

    implicitWidth: 240
    implicitHeight: 16
    opacity: enabled ? 1 : 0.4

    Row {
        anchors.fill: parent
        spacing: 2
        Repeater {
            model: root.blocks
            Rectangle {
                required property int index
                width: (root.width - (root.blocks - 1) * 2) / root.blocks
                height: root.height
                color: (index + 0.5) / root.blocks <= root.value ? root.color : Theme.alpha(Theme.dim, 0.25)
            }
        }
    }
    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        function at(x) { root.moved(Math.max(0, Math.min(1, x / width))); }
        onPressed: e => at(e.x)
        onPositionChanged: e => { if (pressed) at(e.x); }
        onWheel: e => root.moved(Math.max(0, Math.min(1, root.value + (e.angleDelta.y > 0 ? 0.03 : -0.03))))
    }
}
