import QtQuick
import "../theme"

// A 98 slider ("trackbar"): a thin sunken groove, a raised thumb with a point, tick marks under it.
// value 0..1; moved(v) while dragging, scrolling or with the arrow keys. vertical: the Volume
// Control faders (top = loud).
Item {
    id: root

    property real value: 0
    property bool vertical: false
    property int ticks: 11              // 0 = none
    property real step: 0.02
    signal moved(real v)

    readonly property int thumbLong: 22     // along the thumb's point
    readonly property int thumbShort: 12    // across the groove
    readonly property int len: vertical ? height : width

    implicitWidth: vertical ? 40 : 200
    implicitHeight: vertical ? 160 : 34
    activeFocusOnTab: true

    function setAt(pos) {
        const span = len - thumbShort;
        let v = Math.max(0, Math.min(1, (pos - thumbShort / 2) / span));
        if (vertical) v = 1 - v;
        moved(v);
    }
    Keys.onPressed: e => {
        const up = e.key === Qt.Key_Right || e.key === Qt.Key_Up, down = e.key === Qt.Key_Left || e.key === Qt.Key_Down;
        if (up || down) { moved(Math.max(0, Math.min(1, value + (up ? step * 5 : -step * 5)))); e.accepted = true; }
    }

    // groove
    Bevel {
        kind: "sunken"
        fill: Theme.face
        x: root.vertical ? 8 : root.thumbShort / 2 - 2
        y: root.vertical ? root.thumbShort / 2 - 2 : 6
        width: root.vertical ? 4 : root.width - root.thumbShort + 4
        height: root.vertical ? root.height - root.thumbShort + 4 : 4
    }

    // ticks
    Repeater {
        model: root.ticks
        Rectangle {
            required property int index
            readonly property real at: root.thumbShort / 2 + index / Math.max(1, root.ticks - 1) * (root.len - root.thumbShort)
            x: root.vertical ? 30 : Math.round(at)
            y: root.vertical ? Math.round(at) : 28
            width: root.vertical ? (index === 0 || index === root.ticks - 1 ? 5 : 3) : 1
            height: root.vertical ? 1 : (index === 0 || index === root.ticks - 1 ? 5 : 3)
            color: Theme.windowText
        }
    }

    // thumb: a raised pentagon pointing down (or right)
    Canvas {
        id: thumb
        readonly property real pos: (root.vertical ? 1 - root.value : root.value) * (root.len - root.thumbShort)
        x: root.vertical ? 0 : Math.round(pos)
        y: root.vertical ? Math.round(pos) : 0
        width: root.vertical ? root.thumbLong : root.thumbShort
        height: root.vertical ? root.thumbShort : root.thumbLong
        readonly property bool held: drag.pressed
        onHeldChanged: requestPaint()
        Connections { target: Theme; function onPaletteChanged() { thumb.requestPaint(); } }
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = width, h = height, pt = 6;
            ctx.save();
            if (root.vertical) { ctx.translate(w, 0); ctx.rotate(Math.PI / 2); }
            const W = root.vertical ? h : w, H = root.vertical ? w : h;
            // body
            ctx.fillStyle = Theme.face;
            ctx.beginPath();
            ctx.moveTo(0, 0); ctx.lineTo(W, 0); ctx.lineTo(W, H - pt); ctx.lineTo(W / 2, H); ctx.lineTo(0, H - pt); ctx.closePath();
            ctx.fill();
            const line = (x1, y1, x2, y2, c) => { ctx.strokeStyle = c; ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke(); };
            line(0.5, 0.5, W - 0.5, 0.5, Theme.hilight);
            line(0.5, 0.5, 0.5, H - pt, Theme.hilight);
            line(0.5, H - pt, W / 2, H - 0.5, Theme.hilight);
            line(W - 0.5, 0, W - 0.5, H - pt, Theme.dkShadow);
            line(W - 0.5, H - pt, W / 2, H - 0.5, Theme.dkShadow);
            line(W - 1.5, 1, W - 1.5, H - pt, Theme.shadow);
            line(W - 1.5, H - pt, W / 2, H - 1.5, Theme.shadow);
            ctx.restore();
        }
    }
    FocusRect {
        anchors.fill: parent
        visible: root.activeFocus
    }

    MouseArea {
        id: drag
        anchors.fill: parent
        onPressed: e => { root.forceActiveFocus(); root.setAt(root.vertical ? e.y : e.x); }
        onPositionChanged: e => { if (pressed) root.setAt(root.vertical ? e.y : e.x); }
        onWheel: e => root.moved(Math.max(0, Math.min(1, root.value + (e.angleDelta.y > 0 ? root.step : -root.step))))
    }
}
