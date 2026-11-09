import QtQuick

// A dot mask for layer.effect: `layer.enabled: true; layer.effect: Dm { step: 6 }` turns an item
// into a matrix of equal LED dots, each the brightness of its cell's centre (album art, icons,
// the halftone orb). Monochrome, like the Glyph lights on the back of the phone.
ShaderEffect {
    property real step: 5
    readonly property real pitch: step          // the shader's name (step is a GLSL builtin)
    property bool circle: false                 // dots only inside the inscribed circle
    readonly property real circ: circle ? 1 : 0
    readonly property size size: Qt.size(width, height)
    fragmentShader: Qt.resolvedUrl("shaders/dots.frag.qsb")
}
