import QtQuick
import "../theme"

// A history as a dot matrix (the reference's CPU-60-s widget): one column per sample, `rows` dots
// high; the top dot of each column is white, the ones under it grey, the rest unlit.
Canvas {
    id: root

    property var values: []
    property real max: 0
    property color color: Theme.fg
    property color under: Theme.grey
    property color off: Theme.s2
    property int points: 34
    property int rows: 8
    property real lineWidth: 0              // (old API; unused)
    property color base: "transparent"      // (old API; unused)

    onValuesChanged: requestPaint()
    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onOffChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const vs = values.slice(-points);
        const top = max > 0 ? max : Math.max(1e-9, ...vs, 0);
        const cw = width / points, rh = height / rows;
        const d = Math.max(1.5, Math.min(cw, rh) * 0.62);
        for (let c = 0; c < points; c++) {
            const v = vs[c - points + vs.length];
            const h = v === undefined ? 0 : Math.round(1 + (rows - 1) * Math.min(1, v / top));
            for (let r = 0; r < rows; r++) {
                const up = rows - r;
                ctx.fillStyle = up === h ? color : up < h ? under : off;
                ctx.beginPath();
                ctx.arc(c * cw + cw / 2, r * rh + rh / 2, d / 2, 0, 2 * Math.PI);
                ctx.fill();
            }
        }
    }
}
