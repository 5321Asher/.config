import QtQuick
import "../theme"

// A graduated slider, 0-1: a brass scale with a tick every 10%, the reading traced in phosphor,
// and a brass pointer. Drag, click or scroll. Emits moved(value) on user input only.
Item {
    id: root

    property real value: 0
    property color ink: Theme.phosphor
    signal moved(real v)

    implicitHeight: 22
    opacity: enabled ? 1 : 0.4

    readonly property real v: Math.max(0, Math.min(1, value))

    Canvas {
        id: scale
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = width, y = height / 2;
            ctx.strokeStyle = Theme.alpha(Theme.brassDeep, 0.9);
            ctx.lineWidth = 1;
            ctx.beginPath(); ctx.moveTo(0, y + 0.5); ctx.lineTo(w, y + 0.5); ctx.stroke();
            for (let i = 0; i <= 10; i++) {
                const x = Math.round(i / 10 * (w - 1)) + 0.5, big = i % 5 === 0;
                ctx.strokeStyle = Theme.alpha(Theme.brass, big ? 0.7 : 0.35);
                ctx.beginPath(); ctx.moveTo(x, y + 3); ctx.lineTo(x, y + (big ? 8 : 6)); ctx.stroke();
            }
        }
        onWidthChanged: requestPaint()
    }
    Rectangle {
        y: parent.height / 2 - 1
        height: 2.5
        width: root.v * parent.width
        radius: 1
        color: root.ink
    }
    // pointer
    Rectangle {
        x: root.v * (parent.width - width)
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 0.5
        width: 12; height: 12; radius: 6
        color: mouse.pressed ? Theme.brassBright : Theme.brass
        border.width: 1
        border.color: Theme.bgDark
        Rectangle { anchors.centerIn: parent; width: 3; height: 3; radius: 1.5; color: Theme.bgDark }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.topMargin: -4
        anchors.bottomMargin: -4
        cursorShape: Qt.PointingHandCursor
        function set(x) { root.moved(Math.max(0, Math.min(1, x / width))); }
        onPressed: m => set(m.x)
        onPositionChanged: m => { if (pressed) set(m.x); }
        onWheel: w => root.moved(Math.max(0, Math.min(1, root.v + (w.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}
