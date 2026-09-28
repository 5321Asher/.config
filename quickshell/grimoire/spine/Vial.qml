import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "../theme"

// A glass vial of potion, filled to `value` (0..1): a round-bottomed flask ("flask") or a slim
// tube ("tube"), corked, with a highlight down the glass. The potion glows faintly and bubbles
// rise through it (faster the harder it works). Past `hot` it turns red.
Item {
    id: root

    property real value: 0
    property color potion: Theme.arcane
    property string shape: "flask"
    property real hot: 0.9
    readonly property color liquid: value > hot ? Theme.danger : potion
    readonly property real level: Math.max(0.04, Math.min(1, value))

    implicitWidth: 34
    implicitHeight: 58

    // the vessel's inside, as a path in this item's coordinates
    readonly property real w: width
    readonly property real h: height
    readonly property string inside: shape === "flask"
        ? `M ${w / 2 - 5} 9 L ${w / 2 - 5} ${h * 0.34} A ${w / 2 - 2} ${w / 2 - 2} 0 1 0 ${w / 2 + 5} ${h * 0.34} L ${w / 2 + 5} 9 Z`
        : `M ${w / 2 - 7} 9 L ${w / 2 - 7} ${h - 9} A 7 7 0 0 0 ${w / 2 + 7} ${h - 9} L ${w / 2 + 7} 9 Z`
    // the part of the height the potion can fill (the flask's neck stays mostly empty)
    readonly property real fillTop: shape === "flask" ? h * 0.3 : 12
    readonly property real fillBottom: shape === "flask"
        ? h * 0.34 + Math.sqrt(Math.max(0, (w / 2 - 2) * (w / 2 - 2) - 25)) + (w / 2 - 2) - 2
        : h - 3

    // ---------------------------------------------------------------- the potion
    // the vessel's inside, filled, seen through a window from the surface down: exactly the liquid
    property real surface: fillBottom - (fillBottom - fillTop) * level
    Behavior on surface { NumberAnimation { duration: Theme.slow; easing.type: Theme.easing } }
    Item {
        id: potionLayer
        y: root.surface
        width: root.width
        height: Math.max(0, root.height - root.surface)
        clip: true
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: root.liquid
            shadowBlur: 0.5
            shadowOpacity: 0.3 + root.value * 0.45
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
            blurMax: 12
        }
        Shape {
            y: -root.surface
            width: root.width
            height: root.height
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "transparent"
                fillGradient: LinearGradient {
                    x1: 0; y1: root.surface; x2: 0; y2: root.height
                    GradientStop { position: 0; color: Qt.lighter(root.liquid, 1.5) }
                    GradientStop { position: 0.12; color: Qt.lighter(root.liquid, 1.15) }
                    GradientStop { position: 1; color: Qt.darker(root.liquid, 1.6) }
                }
                PathSvg { path: root.inside }
            }
        }
        // bubbles, rising up the middle
        Repeater {
            model: 4
            Rectangle {
                id: bub
                required property int index
                width: 2 + index % 2 * 1.5; height: width; radius: width / 2
                color: Qt.lighter(root.liquid, 1.9)
                opacity: 0.85
                x: root.w / 2 - 4 + (index * 37 % 8)
                property real p: 0
                y: (root.fillBottom - 5 - root.surface) * (1 - p)
                visible: root.value > 0.03
                NumberAnimation on p {
                    running: root.value > 0.03
                    from: 0; to: 1
                    duration: 2600 - Math.min(1800, root.value * 2000) + bub.index * 390
                    loops: Animation.Infinite
                }
            }
        }
    }

    // ---------------------------------------------------------------- the glass
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Theme.alpha(Theme.light ? Theme.ink : Theme.fg, 0.55)
            strokeWidth: 1.2
            fillColor: Theme.alpha(Theme.light ? Theme.ink : Theme.fg, 0.05)
            PathSvg { path: root.inside }
        }
        // the highlight down the glass
        ShapePath {
            strokeColor: Theme.alpha("#ffffff", 0.35)
            strokeWidth: 1.5
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathSvg {
                path: root.shape === "flask"
                    ? `M ${root.w / 2 - 12} ${root.h * 0.52} Q ${root.w / 2 - 12} ${root.h * 0.72} ${root.w / 2 - 6} ${root.h * 0.82}`
                    : `M ${root.w / 2 - 4} 16 L ${root.w / 2 - 4} ${root.h - 12}`
            }
        }
    }
    // the cork and the lip
    Rectangle { x: root.w / 2 - 7; y: 7; width: 14; height: 3; radius: 1.5; color: Theme.alpha(Theme.light ? Theme.ink : Theme.fg, 0.5) }
    Rectangle {
        x: root.w / 2 - 4; y: 0; width: 8; height: 8; radius: 1.5
        gradient: Gradient {
            GradientStop { position: 0; color: "#b0875a" }
            GradientStop { position: 1; color: "#6e4a2c" }
        }
    }

}
