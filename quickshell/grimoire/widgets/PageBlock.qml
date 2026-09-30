import QtQuick
import "../theme"

// The edge of a block of pages (shaders/pages.frag): across = true for a head or foot (the leaves
// stacked downwards), false for a fore-edge.
ShaderEffect {
    property bool across: true
    property real shadeDepth: 0.6
    property real seedValue: 0.4
    property size size: Qt.size(width, height)
    property color paper: Theme.mix(Theme.page, Theme.pageDeep, 0.35)
    property color ink: Theme.ink
    property real across_: across ? 1 : 0
    property real seed: seedValue
    property real shade: shadeDepth
    fragmentShader: Theme.shaders + "pages.frag.qsb"
}
