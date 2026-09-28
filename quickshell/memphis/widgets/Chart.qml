import QtQuick
import "../theme"

// A System Monitor chart: black, a dark green grid that scrolls, the history as a bright line.
// values: newest last; max: full scale (0 = fit to the largest value).
Canvas {
    id: root

    property var values: []
    property real max: 100
    property color line: Theme.lcdText
    property int points: 60

    onValuesChanged: requestPaint()
    onWidthChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        ctx.fillStyle = "#000000";
        ctx.fillRect(0, 0, width, height);
        const step = width / Math.max(1, points - 1);
        // grid, shifted with the data so it scrolls like 98's
        ctx.strokeStyle = "#004000";
        ctx.lineWidth = 1;
        ctx.beginPath();
        const shift = (values.length % 4) * step;
        for (let x = width - shift; x > 0; x -= step * 4) { ctx.moveTo(Math.round(x) + 0.5, 0); ctx.lineTo(Math.round(x) + 0.5, height); }
        for (let y = height / 4; y < height; y += height / 4) { ctx.moveTo(0, Math.round(y) + 0.5); ctx.lineTo(width, Math.round(y) + 0.5); }
        ctx.stroke();
        if (values.length < 2) return;
        const top = max > 0 ? max : Math.max(1, ...values) * 1.1;
        ctx.strokeStyle = line;
        ctx.lineWidth = 1;
        ctx.beginPath();
        const vs = values.slice(-points);
        for (let i = 0; i < vs.length; i++) {
            const x = width - (vs.length - 1 - i) * step;
            const y = height - 1 - Math.min(1, Math.max(0, vs[i] / top)) * (height - 2);
            if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
        }
        ctx.stroke();
    }
}
