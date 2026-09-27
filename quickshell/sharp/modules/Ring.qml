import QtQuick
import QtQuick.Shapes

// Full circular progress ring, 0-1, filling clockwise from the top
Item {
    id: root

    property real value: 0
    property color color: Theme.accent
    property color trackColor: Theme.hover
    property real thickness: 10

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.trackColor
            strokeWidth: root.thickness
            fillColor: "transparent"

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: (root.width - root.thickness) / 2
                radiusY: radiusX
                startAngle: 0
                sweepAngle: 360
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
                startAngle: -90
                sweepAngle: Math.max(0.01, Math.min(1, root.value)) * 360
            }
        }
    }
}
