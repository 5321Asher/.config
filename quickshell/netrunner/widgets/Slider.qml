import QtQuick
import "../theme"

// A level: a row of thin blocks lit up to the value (the last lit one brighter, every eighth a notch
// taller); drag, click or scroll to set it.
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
                readonly property bool lit: (index + 0.5) / root.blocks <= root.value
                readonly property bool head: lit && (index + 1.5) / root.blocks > root.value
                anchors.bottom: parent.bottom
                width: (root.width - (root.blocks - 1) * 2) / root.blocks
                height: index % 8 === 7 ? root.height : root.height - 4
                color: head ? Qt.lighter(root.color, 1.5) : lit ? Theme.alpha(root.color, 0.55 + 0.45 * index / root.blocks) : Theme.alpha(Theme.dim, 0.22)
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
