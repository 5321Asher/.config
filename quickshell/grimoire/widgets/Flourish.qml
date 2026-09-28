import QtQuick
import QtQuick.Shapes
import "../theme"

// A corner flourish: an L of gold leaf that ends in two scrolled curls, a leaf between them and a
// dot, drawn for the top-left corner in a size x size box (the corner at 0,0). `corner` turns it
// for the others: "tl" "tr" "bl" "br".
Item {
    id: root

    property string corner: "tl"
    property real size: 44
    property color color: Theme.gold
    property color shade: Theme.goldDeep
    property real stroke: 1.6
    property real grow: 1              // 0..1: draws itself in
    property bool leaf: true           // the leaf on the diagonal (off for window corners)

    width: size
    height: size

    transform: [
        Scale {
            origin.x: root.size / 2
            origin.y: root.size / 2
            xScale: root.corner === "tr" || root.corner === "br" ? -1 : 1
            yScale: root.corner === "bl" || root.corner === "br" ? -1 : 1
        }
    ]

    Shape {
        id: sh
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        opacity: Math.min(1, root.grow * 2)
        readonly property real k: root.size / 44

        // the shadow line, under
        ShapePath {
            strokeColor: Qt.alpha(root.shade, 0.7)
            strokeWidth: root.stroke + 1.4
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: sh.curl }
        }
        ShapePath {
            strokeColor: root.color
            strokeWidth: root.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: sh.curl }
        }
        // the leaf and the dot
        ShapePath {
            strokeColor: "transparent"
            fillColor: root.leaf ? root.color : "transparent"
            PathSvg { path: sh.leaf }
        }

        readonly property string curl: {
            const s = k * root.grow;
            const p = (x, y) => `${(x * k).toFixed(2)} ${(y * k).toFixed(2)}`;
            // two arms along the edges, each ending in a spiral turned back toward the corner
            return `M ${p(2, 2 + 40 * root.grow)} L ${p(2, 12)} Q ${p(2, 2)} ${p(12, 2)} L ${p(2 + 40 * root.grow, 2)}`
                + ` M ${p(30, 2)} C ${p(36, 2)} ${p(38, 9)} ${p(33, 10)} C ${p(29, 11)} ${p(28, 6)} ${p(31, 6)}`
                + ` M ${p(2, 30)} C ${p(2, 36)} ${p(9, 38)} ${p(10, 33)} C ${p(11, 29)} ${p(6, 28)} ${p(6, 31)}`
                + (root.leaf ? ` M ${p(7, 7)} C ${p(14, 9)} ${p(18, 14)} ${p(20, 20)}` : "");
        }
        readonly property string leaf: {
            const p = (x, y) => `${(x * k).toFixed(2)} ${(y * k).toFixed(2)}`;
            return (root.leaf ? `M ${p(20, 20)} C ${p(25, 17)} ${p(29, 21)} ${p(25, 25)} C ${p(21, 29)} ${p(17, 25)} ${p(20, 20)} Z ` : "")
                + `M ${p(15, 7)} a ${(1.6 * k).toFixed(2)} ${(1.6 * k).toFixed(2)} 0 1 0 0.01 0 Z`
                + ` M ${p(7, 15)} a ${(1.6 * k).toFixed(2)} ${(1.6 * k).toFixed(2)} 0 1 0 0.01 0 Z`;
        }
    }
}
