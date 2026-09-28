import QtQuick
import "../theme"

// 98's 50% dither: a 1 px checkerboard of two colours (a toggled button's face, a scroll bar's track,
// the dimmed screen behind "Shut Down Windows").
Canvas {
    id: root

    property color a: Theme.hilight
    property color b: Theme.face

    onAChanged: requestPaint()
    onBChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        ctx.fillStyle = b;
        ctx.fillRect(0, 0, width, height);
        const img = ctx.createImageData(2, 2);
        const ca = Qt.color(a);
        for (const [x, y] of [[0, 0], [1, 1]]) {
            const i = (y * 2 + x) * 4;
            img.data[i] = Math.round(ca.r * 255); img.data[i + 1] = Math.round(ca.g * 255);
            img.data[i + 2] = Math.round(ca.b * 255); img.data[i + 3] = Math.round(ca.a * 255);
        }
        ctx.fillStyle = ctx.createPattern(img, "repeat");
        ctx.fillRect(0, 0, width, height);
    }
}
