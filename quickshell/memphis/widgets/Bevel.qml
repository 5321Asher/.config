import QtQuick
import "../theme"

// A Windows 98 edge: two 1 px lines round a box, light from the top left.
//   button   push buttons, the Start button, caption buttons (white / black outside, light / grey inside)
//   pressed  a button held down (the reverse)
//   raised   windows, menus, the taskbar (light / black outside, white / grey inside)
//   sunken   text fields, lists, check boxes (grey / white outside, black / light inside)
//   status   the taskbar's notification area, status bar panes (1 px, grey / white)
//   thin     a small raised edge (toolbar buttons on hover) (1 px, white / grey)
//   etched   group boxes, separators (grey line with a white one beside it)
// `fill` paints the inside; children go inside the edge (use anchors.margins: Theme.bevel).
Item {
    id: root

    property string kind: "raised"
    property color fill: "transparent"

    // [outer top-left, outer bottom-right, inner top-left, inner bottom-right]; null = no inner line
    readonly property var edges: {
        switch (kind) {
        case "button": return [Theme.hilight, Theme.dkShadow, Theme.light, Theme.shadow];
        case "pressed": return [Theme.dkShadow, Theme.hilight, Theme.shadow, Theme.light];
        case "sunken": return [Theme.shadow, Theme.hilight, Theme.dkShadow, Theme.light];
        case "status": return [Theme.shadow, Theme.hilight, null, null];
        case "thin": return [Theme.hilight, Theme.shadow, null, null];
        case "etched": return [Theme.shadow, Theme.hilight, Theme.hilight, Theme.shadow];
        case "none": return [null, null, null, null];
        default: return [Theme.light, Theme.dkShadow, Theme.hilight, Theme.shadow];
        }
    }
    readonly property int depth: edges[2] === null ? (edges[0] === null ? 0 : 1) : 2

    Rectangle {
        anchors.fill: parent
        anchors.margins: root.depth
        color: root.fill
    }

    Ring { inset: 0; tl: root.edges[0]; br: root.edges[1] }
    Ring { inset: 1; tl: root.edges[2]; br: root.edges[3] }

    // One 1 px ring: top and left lines stop a pixel short so the bottom-right colour owns the corners
    component Ring: Item {
        property int inset
        property var tl
        property var br
        visible: tl !== null && tl !== undefined
        anchors.fill: parent
        anchors.margins: inset
        Rectangle { x: 0; y: 0; width: parent.width - 1; height: 1; color: parent.tl ?? "transparent" }
        Rectangle { x: 0; y: 0; width: 1; height: parent.height - 1; color: parent.tl ?? "transparent" }
        Rectangle { x: 0; y: parent.height - 1; width: parent.width; height: 1; color: parent.br ?? "transparent" }
        Rectangle { x: parent.width - 1; y: 0; width: 1; height: parent.height; color: parent.br ?? "transparent" }
    }
}
