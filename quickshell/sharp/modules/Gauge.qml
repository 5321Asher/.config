import QtQuick
import QtQuick.Shapes

// Ring gauge, 0-1, with an open gap at the bottom
Item {
    id: root

    property real value: 0
    property color color: Theme.accent
    property real thickness: 9
    readonly property real sweep: 270

    Behavior on value { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: Theme.hover
            strokeWidth: root.thickness
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: (root.width - root.thickness) / 2
                radiusY: radiusX
                startAngle: 135
                sweepAngle: root.sweep
            }
        }

        ShapePath {
            strokeColor: root.color
            strokeWidth: root.thickness
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: (root.width - root.thickness) / 2
                radiusY: radiusX
                startAngle: 135
                sweepAngle: Math.max(0.1, Math.min(1, root.value)) * root.sweep
            }
        }
    }
}
