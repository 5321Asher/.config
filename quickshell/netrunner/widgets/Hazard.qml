import QtQuick
import "../theme"

// Hazard stripes: slanted bars in the signal colour (a band on SYS.DIAG, the lock screen).
Canvas {
    id: root

    property color color: Theme.red
    property int stripe: 6
    property int spacing: 5

    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        ctx.fillStyle = color;
        const h = height, s = stripe, p = stripe + spacing;
        for (let x = -h; x < width; x += p) {
            ctx.beginPath();
            ctx.moveTo(x + h, 0); ctx.lineTo(x + h + s, 0); ctx.lineTo(x + s, h); ctx.lineTo(x, h);
            ctx.closePath();
            ctx.fill();
        }
    }
}
