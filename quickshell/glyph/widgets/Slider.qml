import QtQuick
import "../theme"

// A level: the filled part is a white pill, the rest a row of dots; a glyph rides at the left and
// the number at the right. Click / drag / wheel to set.
Item {
    id: root

    property real value: 0
    property string glyph: ""
    property bool showValue: true
    property color color: Theme.fg
    property int blocks: 0                  // (old API; unused)
    signal moved(real v)

    implicitWidth: 300
    implicitHeight: 56
    opacity: enabled ? 1 : 0.4
    readonly property real v: Math.max(0, Math.min(1, value))

    Rectangle { anchors.fill: parent; radius: height / 2; color: Theme.s2 }
    // the dots for the empty part
    Row {
        anchors { right: parent.right; rightMargin: root.showValue ? 54 : root.height / 2; verticalCenter: parent.verticalCenter }
        spacing: 8
        Repeater {
            model: Math.max(0, Math.floor((root.width - (root.showValue ? 54 : root.height / 2) - fill.width - 12) / 11))
            Rectangle { width: 3; height: 3; radius: 1.5; color: Theme.mute; anchors.verticalCenter: parent.verticalCenter }
        }
    }
    Rectangle {
        id: fill
        width: Math.max(root.height, root.width * root.v)
        height: parent.height
        radius: height / 2
        color: root.color
        Behavior on width { NumberAnimation { duration: 90 } }
    }
    Icon {
        visible: root.glyph !== ""
        x: root.height / 2 - width / 2
        anchors.verticalCenter: parent.verticalCenter
        text: root.glyph
        font.pixelSize: Math.min(22, root.height * 0.45)
        color: Theme.ink
    }
    Rectangle {
        visible: root.showValue && root.height >= 30
        anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
        width: 46
        height: Math.min(30, root.height - 12)
        radius: height / 2
        color: fill.width > root.width - 60 ? Theme.s2 : "transparent"
        Lb { anchors.centerIn: parent; text: Math.round(root.v * 100); px: 11; color: Theme.fg }
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
