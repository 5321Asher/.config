import QtQuick
import QtQuick.Shapes

// A card's emblem, as line art in white on a 100 × 100 field (the card stamps it in gold foil):
//   star (Apps) · tower (Trigger) · moon (Style) · dusk (Power) · book (the codex) ·
//   world (the whole book) · sigil (anything else)
Item {
    id: root

    property string kind: "sigil"
    property real stroke: 1.6
    implicitWidth: 100
    implicitHeight: 100

    // an n-pointed star as an SVG path: points of radius R, inner radius r
    function star(cx, cy, n, R, r, rot) {
        let d = "";
        for (let k = 0; k < n * 2; k++) {
            const a = rot + k * Math.PI / n;
            const rr = k % 2 === 0 ? R : r;
            d += (k === 0 ? "M " : " L ") + (cx + Math.cos(a) * rr).toFixed(2) + " " + (cy + Math.sin(a) * rr).toFixed(2);
        }
        return d + " Z";
    }
    function eightStar(cx, cy, long, short, inner) {
        let d = "";
        for (let k = 0; k < 16; k++) {
            const a = -Math.PI / 2 + k * Math.PI / 8;
            const rr = k % 4 === 0 ? long : k % 2 === 0 ? short : inner;
            d += (k === 0 ? "M " : " L ") + (cx + Math.cos(a) * rr).toFixed(2) + " " + (cy + Math.sin(a) * rr).toFixed(2);
        }
        return d + " Z";
    }
    function rays(cx, cy, r1, r2, from, to, step) {
        let d = "";
        for (let a = from; a <= to + 0.01; a += step) {
            const t = a * Math.PI / 180;
            d += ` M ${(cx + Math.cos(t) * r1).toFixed(2)} ${(cy - Math.sin(t) * r1).toFixed(2)} L ${(cx + Math.cos(t) * r2).toFixed(2)} ${(cy - Math.sin(t) * r2).toFixed(2)}`;
        }
        return d;
    }
    function circle(cx, cy, r) {
        return `M ${cx - r} ${cy} A ${r} ${r} 0 1 0 ${cx + r} ${cy} A ${r} ${r} 0 1 0 ${cx - r} ${cy} Z`;
    }

    // [outline paths, filled paths]
    readonly property var art: {
        switch (kind) {
        case "star": return [
            eightStar(50, 50, 40, 20, 6.5) + circle(50, 50, 13),
            star(20, 22, 4, 5, 1.4, -Math.PI / 2) + star(82, 28, 4, 4, 1.1, -Math.PI / 2) + star(78, 80, 4, 5, 1.4, -Math.PI / 2)
                + star(18, 76, 4, 3.5, 1, -Math.PI / 2) + circle(50, 50, 3)];
        case "tower": return [
            "M 38 88 L 40 46 L 60 46 L 62 88 M 37 46 L 37 37 L 42 37 L 42 41 L 47 41 L 47 37 L 53 37 L 53 41 L 58 41 L 58 37 L 63 37 L 63 46"
                + " M 46 88 L 46 77 Q 50 70 54 77 L 54 88 M 48 56 L 52 56 L 52 63 L 48 63 Z M 22 88 L 78 88",
            "M 74 6 L 57 26 L 64 27 L 50 40 L 69 24 L 62 23 Z" + circle(30, 30, 1.6) + circle(76, 50, 1.3) + circle(24, 60, 1.2)];
        case "moon": return [
            "M 60 20 A 30 30 0 1 0 60 80 A 23 23 0 1 1 60 20 Z" + circle(50, 50, 42),
            star(72, 34, 4, 6, 1.5, -Math.PI / 2) + star(78, 62, 4, 3.5, 1, -Math.PI / 2) + circle(66, 48, 1.4)];
        case "dusk": return [
            "M 12 64 L 88 64 M 24 72 L 76 72 M 36 80 L 64 80 M 30 64 A 20 20 0 0 1 70 64" + rays(50, 64, 26, 36, 18, 162, 18),
            star(50, 18, 4, 5, 1.4, -Math.PI / 2) + circle(28, 26, 1.3) + circle(73, 24, 1.3)];
        case "book": return [
            "M 50 40 Q 35 32 16 36 L 16 78 Q 35 74 50 82 Q 65 74 84 78 L 84 36 Q 65 32 50 40 Z M 50 40 L 50 82"
                + " M 23 48 Q 34 45 44 50 M 23 57 Q 34 54 44 59 M 23 66 Q 34 63 44 68 M 56 50 Q 66 45 77 48 M 56 59 Q 66 54 77 57 M 56 68 Q 66 63 77 66"
                + rays(50, 30, 6, 16, 30, 150, 30),
            star(50, 30, 4, 4, 1.2, -Math.PI / 2)];
        case "world": return [
            "M 50 12 A 25 38 0 1 0 50 88 A 25 38 0 1 0 50 12 Z M 50 20 A 18 30 0 1 0 50 80 A 18 30 0 1 0 50 20 Z",
            star(50, 50, 4, 9, 2.4, -Math.PI / 2) + star(12, 12, 4, 5, 1.4, -Math.PI / 2) + star(88, 12, 4, 5, 1.4, -Math.PI / 2)
                + star(12, 88, 4, 5, 1.4, -Math.PI / 2) + star(88, 88, 4, 5, 1.4, -Math.PI / 2)];
        default: return [circle(50, 50, 36) + star(50, 50, 5, 30, 12, -Math.PI / 2), circle(50, 50, 3)];
        }
    }

    Shape {
        width: 100
        height: 100
        scale: Math.min(root.width, root.height) / 100
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "white"
            strokeWidth: root.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: root.art[0] }
        }
        ShapePath {
            strokeColor: "transparent"
            fillColor: "white"
            PathSvg { path: root.art[1] }
        }
    }
}
