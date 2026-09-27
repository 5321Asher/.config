import QtQuick

// Filled line chart of `values`, scaled to `max` (or the largest value when max is 0)
Canvas {
    id: root

    property var values: []
    property real max: 0
    property int capacity: SysStats.historyLength
    property color color: Theme.accent
    property real lineWidth: 2

    onValuesChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const n = values.length;
        if (n < 2)
            return;

        const top = max > 0 ? max : Math.max(1, ...values);
        const step = width / (capacity - 1);
        const x0 = width - (n - 1) * step;
        const y = v => height - lineWidth - (Math.min(v, top) / top) * (height - lineWidth * 2);

        ctx.beginPath();
        ctx.moveTo(x0, y(values[0]));
        for (let i = 1; i < n; i++) {
            // Smooth with midpoints
            const px = x0 + (i - 1) * step, cx = x0 + i * step;
            const mx = (px + cx) / 2;
            ctx.bezierCurveTo(mx, y(values[i - 1]), mx, y(values[i]), cx, y(values[i]));
        }
        ctx.strokeStyle = color;
        ctx.lineWidth = lineWidth;
        ctx.lineJoin = "round";
        ctx.stroke();

        ctx.lineTo(width, height);
        ctx.lineTo(x0, height);
        ctx.closePath();
        const grad = ctx.createLinearGradient(0, 0, 0, height);
        grad.addColorStop(0, Qt.rgba(color.r, color.g, color.b, 0.3));
        grad.addColorStop(1, Qt.rgba(color.r, color.g, color.b, 0));
        ctx.fillStyle = grad;
        ctx.fill();
    }
}
