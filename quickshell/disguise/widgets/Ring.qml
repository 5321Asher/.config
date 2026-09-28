import QtQuick
import QtQuick.Shapes
import "../theme"

// A progress ring. value 0..1, or indeterminate: the arc chases round, as Windows' does.
Item {
    id: root
    property real value: 0
    property bool indeterminate: false
    property real thickness: 3
    property color color: Theme.accent
    property color track: "transparent"
    implicitWidth: 32
    implicitHeight: 32

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.track
            strokeWidth: root.thickness
            PathAngleArc { centerX: root.width / 2; centerY: root.height / 2; radiusX: root.width / 2 - root.thickness; radiusY: radiusX; startAngle: 0; sweepAngle: 360 }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.color
            strokeWidth: root.thickness
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                id: arc
                centerX: root.width / 2; centerY: root.height / 2
                radiusX: root.width / 2 - root.thickness; radiusY: radiusX
                startAngle: -90
                sweepAngle: root.indeterminate ? 100 : 360 * Math.max(0.001, Math.min(1, root.value))
            }
        }
        RotationAnimation on rotation {
            running: root.indeterminate && root.visible
            from: 0; to: 360; duration: 1100; loops: Animation.Infinite
        }
    }
}
