import QtQuick
import QtQuick.Shapes
import "../theme"

// The bookmark: a silk ribbon in the arcane colour, a sheen down its middle and gold thread along
// its edges, cut in a swallowtail at the end. It hangs from its top edge and swings when it moves
// to another chapter (swing(dir)), settling like cloth.
Item {
    id: root

    property color color: Theme.arcane
    property real length: 70
    width: 24
    height: length

    transformOrigin: Item.Top
    function swing(dir) {
        settle.stop();
        settle.from = dir * 11;
        settle.start();
    }
    SpringAnimation on rotation { id: settle; running: false; to: 0; spring: 2.2; damping: 0.09; epsilon: 0.05; mass: 1.2 }

    Shape {
        id: rs
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        readonly property real w: root.width
        readonly property real h: root.height
        readonly property real notch: 9

        ShapePath {
            strokeColor: Qt.darker(root.color, 1.6)
            strokeWidth: 1
            joinStyle: ShapePath.MiterJoin
            fillGradient: LinearGradient {
                x1: 0; y1: 0; x2: root.width; y2: 0
                GradientStop { position: 0; color: Qt.darker(root.color, 1.75) }
                GradientStop { position: 0.3; color: Qt.darker(root.color, 1.15) }
                GradientStop { position: 0.48; color: Qt.lighter(root.color, 1.18) }
                GradientStop { position: 0.62; color: root.color }
                GradientStop { position: 1; color: Qt.darker(root.color, 1.9) }
            }
            startX: 0; startY: 0
            PathLine { x: rs.w; y: 0 }
            PathLine { x: rs.w; y: rs.h }
            PathLine { x: rs.w / 2; y: rs.h - rs.notch }
            PathLine { x: 0; y: rs.h }
            PathLine { x: 0; y: 0 }
        }
    }
    // gold thread along both edges
    Rectangle { x: 2; width: 1; height: parent.height - 3; color: Theme.alpha(Theme.goldBright, 0.55) }
    Rectangle { x: parent.width - 3; width: 1; height: parent.height - 3; color: Theme.alpha(Theme.goldBright, 0.55) }
    // a shadow on the page under it
    Rectangle {
        z: -1
        x: 3; y: 4
        width: parent.width; height: parent.height - 6
        color: Theme.alpha("#000000", 0.35)
        radius: 2
    }
}
