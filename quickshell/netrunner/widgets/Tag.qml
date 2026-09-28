import QtQuick
import QtQuick.Shapes
import "../theme"

// The red tag: a solid block with a slanted right end and dark text ("GB//13", "TTY.03").
// `slant` is how far the right edge leans; `outline` draws it hollow instead.
Item {
    id: root

    property string text: ""
    property color color: Theme.red
    property color textColor: Theme.onRed
    property real slant: height * 0.55
    property bool outline: false
    property int pixelSize: Theme.label + 1
    property string family: Theme.mono
    property bool bold: true
    property real padding: 10

    implicitWidth: label.implicitWidth + padding * 2 + slant
    implicitHeight: 20

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: root.outline ? "transparent" : root.color
            strokeColor: root.outline ? root.color : "transparent"
            strokeWidth: root.outline ? 1 : 0
            startX: 0.5; startY: 0.5
            PathLine { x: root.width - 0.5; y: 0.5 }
            PathLine { x: root.width - root.slant; y: root.height - 0.5 }
            PathLine { x: 0.5; y: root.height - 0.5 }
            PathLine { x: 0.5; y: 0.5 }
        }
    }
    Text {
        id: label
        x: root.padding
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        color: root.outline ? root.color : root.textColor
        font.family: root.family
        font.pixelSize: root.pixelSize
        font.letterSpacing: Theme.tracking
        font.weight: root.bold ? Font.Bold : Font.Normal
        textFormat: Text.PlainText
    }
}
