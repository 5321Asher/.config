import QtQuick
import "../theme"

// A sheet of parchment, drawn by shaders/paper.frag: the page colour with a slow wash of tone, fine
// laid fibres, margins browned with age and, for a page in an open book, the gutter's shade.
Item {
    id: root

    property color color: Theme.page
    property real radius: 2
    property real texture: 1               // how much fibre and grain
    property real age: 0.45                // how browned the margins are
    property bool edge: true
    property int gutter: 0                 // -1: bound on the left, 1: on the right
    property real seed: 0.37

    ShaderEffect {
        anchors.fill: parent
        property size size: Qt.size(width, height)
        property color base: root.color
        property color deep: Theme.pageDeep
        property color ink: Theme.ink
        property real seed: root.seed
        property real age: root.age
        property real gutter: root.gutter
        property real radius: root.radius
        property real grain: root.texture
        property real edge: root.edge ? 1 : 0
        fragmentShader: Theme.shaders + "paper.frag.qsb"
        // drawn once, then kept as a picture until something about it changes
        layer.enabled: true
    }
}
