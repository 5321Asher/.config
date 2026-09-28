import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "../theme"

// The heat crystal: a faceted gem that glows with the CPU's temperature: the arcane colour when
// cool, gold when warm, the flame's orange when hot and red past 85°. It breathes, faster and
// brighter the hotter it gets.
Item {
    id: root

    property real temp: 40
    readonly property real heat: Math.max(0, Math.min(1, (temp - 35) / 55))
    readonly property color glow: temp >= 85 ? Theme.danger
        : heat < 0.45 ? Theme.mix(Theme.arcane, Theme.gold, heat / 0.45)
        : Theme.mix(Theme.gold, Theme.flame, (heat - 0.45) / 0.55)

    implicitWidth: 30
    implicitHeight: 46

    property real breath: 0
    SequentialAnimation on breath {
        loops: Animation.Infinite
        NumberAnimation { to: 1; duration: 2400 - root.heat * 1700; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0; duration: 2400 - root.heat * 1700; easing.type: Easing.InOutSine }
    }

    Item {
        id: gem
        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: root.glow
            shadowBlur: 0.55 + root.heat * 0.45
            shadowOpacity: 0.35 + root.heat * 0.5 + root.breath * 0.2
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
            blurMax: 20
        }
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            readonly property real w: width
            readonly property real h: height
            // outline: a long hexagonal crystal, pointed at both ends
            ShapePath {
                strokeColor: Qt.lighter(root.glow, 1.4)
                strokeWidth: 1
                joinStyle: ShapePath.MiterJoin
                fillGradient: LinearGradient {
                    x1: 0; y1: 0; x2: root.width; y2: root.height
                    GradientStop { position: 0; color: Qt.lighter(root.glow, 1.5 + root.breath * 0.2) }
                    GradientStop { position: 0.5; color: root.glow }
                    GradientStop { position: 1; color: Qt.darker(root.glow, 2.2) }
                }
                PathSvg { path: `M ${root.width / 2} 0 L ${root.width} ${root.height * 0.26} L ${root.width} ${root.height * 0.7} L ${root.width / 2} ${root.height} L 0 ${root.height * 0.7} L 0 ${root.height * 0.26} Z` }
            }
            // facets
            ShapePath {
                strokeColor: Theme.alpha("#ffffff", 0.4)
                strokeWidth: 0.8
                fillColor: "transparent"
                PathSvg { path: `M ${root.width / 2} 0 L ${root.width * 0.36} ${root.height * 0.26} L ${root.width * 0.36} ${root.height * 0.7} L ${root.width / 2} ${root.height} M ${root.width * 0.36} ${root.height * 0.26} L 0 ${root.height * 0.26} M ${root.width * 0.36} ${root.height * 0.7} L 0 ${root.height * 0.7} M ${root.width / 2} 0 L ${root.width * 0.72} ${root.height * 0.26} L ${root.width * 0.72} ${root.height * 0.7} L ${root.width / 2} ${root.height}` }
            }
        }
        // the glint
        Rectangle { x: root.width * 0.18; y: root.height * 0.3; width: 2; height: root.height * 0.3; radius: 1; color: Theme.alpha("#ffffff", 0.5 + root.breath * 0.3) }
    }
}
