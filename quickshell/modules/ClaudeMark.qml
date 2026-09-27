import QtQuick

// Starburst mark, drawn in a single color
Canvas {
    id: root

    property color color: Theme.fg

    onColorChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const r = Math.min(width, height) / 2;
        ctx.translate(width / 2, height / 2);
        ctx.fillStyle = color;
        const rays = 10;
        for (let i = 0; i < rays; i++) {
            ctx.save();
            ctx.rotate(i * 2 * Math.PI / rays);
            // Tapered ray from near the center out to the edge
            ctx.beginPath();
            ctx.moveTo(-r * 0.14, -r * 0.19);
            ctx.lineTo(r * 0.14, -r * 0.19);
            ctx.lineTo(r * 0.06, -r);
            ctx.lineTo(-r * 0.06, -r);
            ctx.closePath();
            ctx.fill();
            ctx.restore();
        }
        ctx.beginPath();
        ctx.arc(0, 0, r * 0.25, 0, 2 * Math.PI);
        ctx.fill();
    }
}
