import QtQuick
import "../theme"

// A piece of tooled leather, drawn by shaders/leather.frag: pebbled grain, a mottle through the dye,
// light from above; optionally blind tooling (a sunken line) just inside the edge.
Item {
    id: root

    property color color: Theme.leather
    property real radius: 0
    property real grain: 1
    property bool tooled: true
    property real toolInset: 5
    property real opacity_: 1
    property real seed: 0.61

    ShaderEffect {
        anchors.fill: parent
        opacity: root.opacity_
        property size size: Qt.size(width, height)
        property color base: root.color
        property real seed: root.seed
        property real grain: root.grain
        property real radius: root.radius
        property real light: Theme.light ? 0.4 : 1
        property real scale: 4.5
        fragmentShader: Theme.shaders + "leather.frag.qsb"
        layer.enabled: true
    }
    // blind tooling: a dark line with a light one under it (pressed into the leather)
    Rectangle {
        visible: root.tooled
        anchors.fill: parent
        anchors.margins: root.toolInset
        radius: Math.max(0, root.radius - root.toolInset)
        color: "transparent"
        border.width: 1
        border.color: Qt.alpha("#000000", Theme.light ? 0.16 : 0.4)
    }
    Rectangle {
        visible: root.tooled
        anchors.fill: parent
        anchors.margins: root.toolInset + 1
        radius: Math.max(0, root.radius - root.toolInset - 1)
        color: "transparent"
        border.width: 1
        border.color: Qt.alpha(Theme.tooling, 0.55)
    }
}
