import QtQuick
import QtQuick.Shapes
import "../theme"

// A box with cut corners: Netrunner's frame. `cut` is the size of the cut; `corners` which ones
// ("tl tr br bl", any subset). Filled with `fill`, outlined with `stroke` (width `strokeWidth`).
Shape {
    id: root

    property real cut: Theme.chamfer
    property string corners: "tl br"
    property color fill: "transparent"
    property color stroke: Theme.line
    property real strokeWidth: 1

    readonly property real c1: corners.includes("tl") ? cut : 0
    readonly property real c2: corners.includes("tr") ? cut : 0
    readonly property real c3: corners.includes("br") ? cut : 0
    readonly property real c4: corners.includes("bl") ? cut : 0
    readonly property real h: strokeWidth / 2

    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: root.fill
        strokeColor: root.strokeWidth > 0 ? root.stroke : "transparent"
        strokeWidth: root.strokeWidth
        joinStyle: ShapePath.MiterJoin
        startX: root.h + root.c1; startY: root.h
        PathLine { x: root.width - root.h - root.c2; y: root.h }
        PathLine { x: root.width - root.h; y: root.h + root.c2 }
        PathLine { x: root.width - root.h; y: root.height - root.h - root.c3 }
        PathLine { x: root.width - root.h - root.c3; y: root.height - root.h }
        PathLine { x: root.h + root.c4; y: root.height - root.h }
        PathLine { x: root.h; y: root.height - root.h - root.c4 }
        PathLine { x: root.h; y: root.h + root.c1 }
        PathLine { x: root.h + root.c1; y: root.h }
    }
}
