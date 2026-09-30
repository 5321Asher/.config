import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "../theme"

// A brass-rimmed instrument plate with cut corners and a soft brass glow (the prompt, the clipboard
// archive). Put it behind the content with anchors.fill.
Shape {
    id: plate

    property color edge: Theme.brass

    preferredRendererType: Shape.CurveRenderer
    ShapePath {
        strokeWidth: 1.2
        strokeColor: plate.edge
        fillColor: Theme.alpha(Theme.bgDark, 0.96)
        startX: Theme.chamfer; startY: 0.5
        PathLine { x: plate.width - Theme.chamfer; y: 0.5 }
        PathLine { x: plate.width - 0.5; y: Theme.chamfer }
        PathLine { x: plate.width - 0.5; y: plate.height - Theme.chamfer }
        PathLine { x: plate.width - Theme.chamfer; y: plate.height - 0.5 }
        PathLine { x: Theme.chamfer; y: plate.height - 0.5 }
        PathLine { x: 0.5; y: plate.height - Theme.chamfer }
        PathLine { x: 0.5; y: Theme.chamfer }
        PathLine { x: Theme.chamfer; y: 0.5 }
    }
    layer.enabled: true
    layer.effect: MultiEffect {
        shadowEnabled: true; shadowColor: Theme.brass; shadowBlur: 0.7; shadowOpacity: 0.5
        shadowHorizontalOffset: 0; shadowVerticalOffset: 0; blurMax: 28
    }
}
