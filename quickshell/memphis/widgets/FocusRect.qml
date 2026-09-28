import QtQuick
import "../theme"

// The dotted focus rectangle 98 draws inside a focused button or round a focused label.
Canvas {
    id: root
    property color color: Theme.text
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        ctx.fillStyle = color;
        const w = Math.floor(width), h = Math.floor(height);
        for (let x = 0; x < w; x += 2) { ctx.fillRect(x, 0, 1, 1); ctx.fillRect(x, h - 1, 1, 1); }
        for (let y = 0; y < h; y += 2) { ctx.fillRect(0, y, 1, 1); ctx.fillRect(w - 1, y, 1, 1); }
    }
}
