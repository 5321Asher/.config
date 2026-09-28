import QtQuick
import Quickshell
import "../theme"

// Tonight's moon, drawn: the lit part in parchment (or `lit`), the rest in shadow, a gold rim.
Canvas {
    id: root

    property real size: 16
    property color lit: Theme.fg
    property color dark: Theme.alpha(Theme.leatherDark, 0.9)
    property color rim: Theme.alpha(Theme.gold, 0.7)
    readonly property real phase: {
        const days = (clock.date.getTime() - Date.UTC(2000, 0, 6, 18, 14)) / 86400000;
        const p = (days / 29.530588853) % 1;
        return p < 0 ? p + 1 : p;
    }
    SystemClock { id: clock; precision: SystemClock.Hours }

    width: size + 2
    height: size + 2
    onPhaseChanged: requestPaint()
    onLitChanged: requestPaint()
    onDarkChanged: requestPaint()
    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const r = size / 2, cx = width / 2, cy = height / 2;
        ctx.fillStyle = dark;
        ctx.beginPath(); ctx.arc(cx, cy, r, 0, 2 * Math.PI); ctx.fill();
        const k = Math.cos(2 * Math.PI * phase), waxing = phase < 0.5;
        ctx.fillStyle = lit;
        ctx.beginPath();
        ctx.arc(cx, cy, r, -Math.PI / 2, Math.PI / 2, !waxing);
        ctx.save(); ctx.translate(cx, cy); ctx.scale(Math.max(0.001, Math.abs(k)), 1);
        ctx.arc(0, 0, r, Math.PI / 2, -Math.PI / 2, (k > 0) === waxing);
        ctx.restore(); ctx.closePath(); ctx.fill();
        ctx.strokeStyle = rim; ctx.lineWidth = 1;
        ctx.beginPath(); ctx.arc(cx, cy, r, 0, 2 * Math.PI); ctx.stroke();
    }
}
