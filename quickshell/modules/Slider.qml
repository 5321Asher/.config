import QtQuick

// Horizontal 0-1 slider. Drag, click or scroll. Emits moved(value) on user input.
Item {
    id: root

    property real value: 0
    property color color: Theme.accent
    property real step: 0.05
    readonly property bool active: mouse.containsMouse || mouse.pressed

    signal moved(real value)

    function set(v) {
        moved(Math.max(0, Math.min(1, v)));
    }

    implicitHeight: 20

    Rectangle {
        id: track

        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: root.active ? 8 : 6
        radius: 0
        color: Theme.hover

        Behavior on height { NumberAnimation { duration: 120 } }

        Rectangle {
            width: Math.max(parent.height, parent.width * Math.min(1, root.value))
            height: parent.height
            radius: 0
            color: root.color
        }
    }

    Rectangle {
        x: Math.min(1, root.value) * (root.width - width)
        anchors.verticalCenter: parent.verticalCenter
        width: 14
        height: 14
        radius: 0
        color: Theme.fg
        scale: root.active ? 1 : 0

        Behavior on scale { NumberAnimation { duration: 120 } }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: e => root.set(e.x / width)
        onPositionChanged: e => { if (pressed) root.set(e.x / width); }
        onWheel: e => root.set(root.value + (e.angleDelta.y > 0 ? root.step : -root.step))
    }
}
