import QtQuick
import "../theme"

// A sparkline: values (newest last) as a thin line, optional base line; max 0 = fit.
Canvas {
    id: root

    property var values: []
    property real max: 0
    property color color: Theme.cyan
    property color base: "transparent"
    property int points: 30
    property real lineWidth: 1.2

    onValuesChanged: requestPaint()
    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        if (base.a > 0) {
            ctx.strokeStyle = base; ctx.lineWidth = 1;
            ctx.beginPath(); ctx.moveTo(0, height - 0.5); ctx.lineTo(width, height - 0.5); ctx.stroke();
        }
        const vs = values.slice(-points);
        if (vs.length < 2) return;
        const top = max > 0 ? max : Math.max(1e-9, ...vs);
        const step = width / (points - 1);
        ctx.strokeStyle = color;
        ctx.lineWidth = lineWidth;
        ctx.lineJoin = "miter";
        ctx.beginPath();
        for (let i = 0; i < vs.length; i++) {
            const x = width - (vs.length - 1 - i) * step;
            const y = height - 1 - Math.min(1, vs[i] / top) * (height - 2);
            if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
        }
        ctx.stroke();
    }
}
