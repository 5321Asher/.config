import QtQuick
import "../theme"

// A WinUI slider: a 4 px rail, the accent up to a round thumb whose accent heart grows when you
// point at it. value is 0..1; moved(v) while dragging (and on the wheel).
Item {
    id: root

    property real value: 0
    property real step: 0.02
    signal moved(real v)

    implicitHeight: 32
    implicitWidth: 200
    opacity: enabled ? 1 : 0.45

    readonly property real v: Math.max(0, Math.min(1, drag.pressed ? drag.live : value))

    Rectangle {
        id: rail
        anchors.verticalCenter: parent.verticalCenter
        x: 10; width: parent.width - 20; height: 4; radius: 2
        color: Theme.strong
        Rectangle { width: parent.width * root.v; height: parent.height; radius: 2; color: Theme.accent }
    }
    Rectangle {
        id: thumb
        width: 20; height: 20; radius: 10
        anchors.verticalCenter: parent.verticalCenter
        x: rail.x + rail.width * root.v - 10
        color: Theme.dark ? "#454545" : "#ffffff"
        border.width: 1
        border.color: Theme.controlStroke
        Rectangle {
            anchors.centerIn: parent
            readonly property int size: drag.pressed ? 10 : drag.containsMouse ? 14 : 12
            width: size; height: size; radius: size / 2
            color: drag.pressed ? Theme.accentPressed : Theme.accent
            Behavior on width { NumberAnimation { duration: Theme.fast } }
            Behavior on height { NumberAnimation { duration: Theme.fast } }
        }
    }
    MouseArea {
        id: drag
        anchors.fill: parent
        hoverEnabled: true
        property real live: 0
        function at(x) { return Math.max(0, Math.min(1, (x - rail.x) / rail.width)); }
        onPressed: e => { live = at(e.x); root.moved(live); }
        onPositionChanged: e => { if (pressed) { live = at(e.x); root.moved(live); } }
        onWheel: e => root.moved(Math.max(0, Math.min(1, root.value + (e.angleDelta.y > 0 ? root.step : -root.step) * 2.5)))
    }
}
