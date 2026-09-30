import QtQuick

// A turn about a vertical hinge at x = 0 (a cover or a leaf on its spine), seen from well back: the
// same as Rotation { axis.y: 1 } but with a gentle perspective (Qt's own is so strong that a turning
// page balloons to twice its size). angle: 0 flat, -180 over to the left.
Matrix4x4 {
    property real angle: 0
    property real originY: 0
    property real distance: 3200
    readonly property real c: Math.cos(angle * Math.PI / 180)
    readonly property real s: -Math.sin(angle * Math.PI / 180) / distance
    matrix: Qt.matrix4x4(c, 0, 0, 0,
                         -originY * s, 1, 0, 0,
                         0, 0, 1, 0,
                         -s, 0, 0, 1)
}
