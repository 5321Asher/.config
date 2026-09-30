import QtQuick
import "../theme"

// A lit book cover (shaders/cover.frag): leather over boards with rounded, rubbed edges, and whatever
// you put inside it pressed into the leather: draw it in Cover.gilt (red: gold-tooled) or Cover.blind
// (green: blind-tooled, no gold). A point light (the candle) plus ambient; metal: true makes it brass.
Item {
    id: root

    readonly property color gilt: "#ff0000"
    readonly property color blind: "#00ff00"

    property color color: Theme.leather
    property real radius: 6
    property real bevel: 10
    property real wear: 0.6
    property real seed: 0.5
    property bool metal: false
    // the light, in this item's coordinates (z: its height above the cover)
    property vector3d light: Qt.vector3d(-width * 0.3, height * 0.7, Math.max(width, height) * 0.8)
    property real lightPower: 1.3
    property color lightColor: Theme.mix(Theme.flame, "#ffffff", 0.35)
    property real ambient: 0.55

    default property alias tooling: mask.data

    Item {
        id: mask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        layer.samples: 4
        layer.smooth: true
    }
    ShaderEffect {
        anchors.fill: parent
        property var mask: mask
        property size size: Qt.size(width, height)
        property color base: root.color
        property color gold: Theme.gold
        property color goldBright: Theme.goldBright
        property color goldDeep: Theme.goldDeep
        property color lightColor: root.lightColor
        property vector3d lightPos: root.light
        property real lightPower: root.lightPower
        property real ambient: root.ambient
        property real radius: root.radius
        property real bevel: root.bevel
        property real seed: root.seed
        property real wear: root.wear
        property real metal: root.metal ? 1 : 0
        fragmentShader: Theme.shaders + "cover.frag.qsb"
    }
}
