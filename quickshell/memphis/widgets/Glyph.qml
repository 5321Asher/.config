import QtQuick
import "../theme"

// The little pixel drawings on 98's buttons: caption buttons, scroll arrows, menu arrows, check marks.
// Drawn from bitmaps below, one square per "#", `scale` px each, so they stay crisp.
Canvas {
    id: root

    property string kind: "close"
    property color color: Theme.text
    property int px: 1
    // Disabled: drawn grey with a white copy a pixel down-right, like disabled text
    property bool etched: false

    readonly property var bitmaps: ({
        close: ["##......##", ".##....##.", "..##..##..", "...####...", "....##....", "...####...", "..##..##..", ".##....##.", "##......##"],
        min: ["........", "........", "........", "........", "........", "........", "######..", "######.."],
        max: ["#########", "#########", "#.......#", "#.......#", "#.......#", "#.......#", "#.......#", "#.......#", "#########"],
        help: ["..####..", ".##..##.", ".##..##.", ".....##.", "....##..", "...##...", "...##...", "........", "...##...", "...##..."],
        up: ["....#....", "...###...", "..#####..", ".#######.", "#########"],
        down: ["#########", ".#######.", "..#####..", "...###...", "....#...."],
        left: ["....#", "...##", "..###", ".####", "#####", ".####", "..###", "...##", "....#"],
        right: ["#....", "##...", "###..", "####.", "#####", "####.", "###..", "##...", "#...."],
        check: ["........#", ".......##", "#.....###", "##...###.", "###.###..", ".#####...", "..###....", "...#....."],
        dot: [".##.", "####", "####", ".##."],
        more: ["#####", ".###.", "..#.."],
        // media transport (Media Player, CD Player)
        play: ["#.......", "###.....", "#####...", "#######.", "########", "#######.", "#####...", "###.....", "#......."],
        pause: ["###..###", "###..###", "###..###", "###..###", "###..###", "###..###", "###..###", "###..###", "###..###"],
        stop: ["########", "########", "########", "########", "########", "########", "########", "########"],
        prev: ["##.....#", "##....##", "##...###", "##..####", "##.#####", "##..####", "##...###", "##....##", "##.....#"],
        next: ["#.....##", "##....##", "###...##", "####..##", "#####.##", "####..##", "###...##", "##....##", "#.....##"],
        shuffle: ["......#.", "###..###", "...##.#.", "...#....", "...#....", "...##.#.", "###..###", "......#."],
        loop: [".######.", "#......#", "#......#", "#...#..#", "#...##.#", ".....###", ".....##.", ".....#.."],
    })
    readonly property var bitmap: bitmaps[kind] ?? []
    readonly property int cols: bitmap.length ? bitmap[0].length : 0

    implicitWidth: cols * px + (etched ? 1 : 0)
    implicitHeight: bitmap.length * px + (etched ? 1 : 0)
    width: implicitWidth
    height: implicitHeight

    onColorChanged: requestPaint()
    onKindChanged: requestPaint()
    onEtchedChanged: requestPaint()
    Connections { target: Theme; function onPaletteChanged() { root.requestPaint(); } }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const draw = (c, off) => {
            ctx.fillStyle = c;
            for (let y = 0; y < bitmap.length; y++)
                for (let x = 0; x < cols; x++)
                    if (bitmap[y][x] === "#") ctx.fillRect(x * px + off, y * px + off, px, px);
        };
        if (etched) { draw(Theme.hilight, 1); draw(Theme.grayText, 0); }
        else draw(color, 0);
    }
}
