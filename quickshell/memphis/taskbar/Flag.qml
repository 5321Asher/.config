import QtQuick

// The Start button's waving four-colour flag, drawn in chunky pixels, with the little motion
// streaks trailing off to the left.
Canvas {
    id: root
    implicitWidth: 22
    implicitHeight: 18
    width: implicitWidth
    height: implicitHeight
    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const px = (x, y, w, h, c) => { ctx.fillStyle = c; ctx.fillRect(x, y, w, h); };
        // each pane: a parallelogram-ish block, bent by one pixel steps to suggest the wave
        const pane = (x0, y0, c) => {
            for (let i = 0; i < 7; i++) {
                const bend = i < 2 ? 1 : i > 4 ? 1 : 0;
                px(x0 + i, y0 - bend, 1, 7, c);
            }
        };
        pane(8, 2, "#f03c1e");   // red
        pane(15, 3, "#28b43c");  // green
        pane(8, 10, "#2878f0");  // blue
        pane(15, 11, "#f0c81e"); // yellow
        // black gaps between the panes
        px(8, 9, 14, 1, "#000000");
        px(15, 2, 1, 16, "#000000");
        // motion streaks
        for (const [x, y, w] of [[0, 3, 2], [3, 3, 3], [0, 6, 1], [2, 6, 4], [1, 11, 2], [4, 11, 2], [0, 14, 3], [4, 14, 2]])
            px(x, y, w, 2, "#000000");
    }
}
