import QtQuick
import "../widgets"

// Something that turns over on its left edge like a leaf or a cover: `angle` 0 lies flat where it
// is, -180 lies flat to the left of that edge. Past edge-on the back shows (mirrored, so it reads
// the right way round once it's over).
Item {
    id: root

    property real angle: 0
    property Component front
    property Component back
    readonly property bool over: angle < -90

    transform: Hinge { angle: root.angle; originY: root.height / 2 }
    Loader {
        anchors.fill: parent
        visible: !root.over
        sourceComponent: root.front
    }
    Loader {
        anchors.fill: parent
        visible: root.over
        sourceComponent: root.back
        transform: Scale { origin.x: root.width / 2; xScale: -1 }
    }
    // darker as it stands up edge-on
    Rectangle {
        anchors.fill: parent
        radius: 4
        color: "#000000"
        opacity: 0.35 * Math.sin(Math.abs(root.angle) * Math.PI / 180)
        visible: opacity > 0.01
    }
}
