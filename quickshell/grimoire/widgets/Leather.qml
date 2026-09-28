import QtQuick
import "../theme"

// A piece of tooled leather: the theme's leather, its pebbled grain (assets/leather.png), a soft
// light from above, and optionally blind tooling (a sunken line) just inside the edge.
Item {
    id: root

    property color color: Theme.leather
    property real radius: 0
    property real grain: Theme.light ? 0.16 : 0.2
    property bool tooled: true
    property real toolInset: 5
    property real opacity_: 1

    Rectangle {
        id: base
        anchors.fill: parent
        radius: root.radius
        color: root.color
        opacity: root.opacity_
    }
    Image {
        anchors.fill: parent
        source: Theme.assets + "leather.png"
        fillMode: Image.Tile
        opacity: root.grain * root.opacity_
        smooth: false
        visible: root.radius === 0
    }
    // light from above, falling off
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        opacity: root.opacity_
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha("#ffffff", Theme.light ? 0.12 : 0.05) }
            GradientStop { position: 0.5; color: "transparent" }
            GradientStop { position: 1; color: Qt.alpha("#000000", Theme.light ? 0.06 : 0.22) }
        }
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
