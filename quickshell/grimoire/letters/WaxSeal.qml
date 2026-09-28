import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "../theme"

// A wax seal: an uneven blob of wax with a stamped ring and a letter pressed into it. `broken`
// cracks it along a jagged line: the halves split apart, turn and fall away. `glowing` (urgent
// letters) makes it pulse with the arcane colour.
Item {
    id: root

    property color wax: Theme.wax
    property string letter: "G"
    property real seed: 1
    property bool broken: false
    property bool glowing: false
    property real size: 46

    width: size
    height: size

    property real crack: broken ? 1 : 0
    Behavior on crack { NumberAnimation { duration: 620; easing.type: Easing.OutCubic } }
    property real pulse: 0
    SequentialAnimation on pulse {
        running: root.glowing && !root.broken
        loops: Animation.Infinite
        NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0; duration: 900; easing.type: Easing.InOutSine }
    }

    // the blob's outline: a circle pushed about by a few waves (seeded, so each seal is its own)
    readonly property string blob: {
        const n = 36, c = size / 2, r = size / 2 - 3;
        let d = "";
        for (let i = 0; i <= n; i++) {
            const a = i / n * 2 * Math.PI;
            const w = Math.sin(a * 3 + seed) * 1.4 + Math.sin(a * 5 + seed * 2.3) * 1.0 + Math.sin(a * 8 + seed * 0.7) * 0.6;
            d += (i ? " L " : "M ") + (c + Math.cos(a) * (r + w)).toFixed(2) + " " + (c + Math.sin(a) * (r + w)).toFixed(2);
        }
        return d + " Z";
    }
    // the crack: a zigzag from top to bottom, a little off centre
    readonly property var zig: {
        const pts = [], c = size / 2;
        for (let i = 0; i <= 6; i++) pts.push([c + (i % 2 ? 4 : -3) + Math.sin(seed + i) * 2, -2 + i * (size + 4) / 6]);
        return pts;
    }
    function halfPath(left) {
        let d = left ? "M -4 -4 " : `M ${size + 4} -4 `;
        for (const p of zig) d += `L ${p[0].toFixed(2)} ${p[1].toFixed(2)} `;
        return d + (left ? `L -4 ${size + 4} Z` : `L ${size + 4} ${size + 4} Z`);
    }

    // the whole seal, drawn once and shown through each half's mask
    Item {
        id: art
        width: root.size; height: root.size
        visible: false
        layer.enabled: true
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Qt.darker(root.wax, 1.5)
                strokeWidth: 1
                fillGradient: RadialGradient {
                    centerX: root.size * 0.4; centerY: root.size * 0.36; centerRadius: root.size * 0.62
                    focalX: root.size * 0.36; focalY: root.size * 0.3
                    GradientStop { position: 0; color: Qt.lighter(root.wax, 1.55) }
                    GradientStop { position: 0.55; color: root.wax }
                    GradientStop { position: 1; color: Qt.darker(root.wax, 1.6) }
                }
                PathSvg { path: root.blob }
            }
        }
        // the stamp's ring, pressed in
        Rectangle {
            anchors.centerIn: parent
            width: root.size * 0.66; height: width; radius: width / 2
            color: Qt.darker(root.wax, 1.12)
            border.width: 1.5
            border.color: Qt.darker(root.wax, 1.55)
            Rectangle { anchors.fill: parent; anchors.margins: 1.5; radius: width / 2; color: "transparent"; border.width: 1; border.color: Qt.lighter(root.wax, 1.35) }
        }
        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 1
            text: root.letter
            color: Qt.darker(root.wax, 1.7)
            style: Text.Raised
            styleColor: Qt.lighter(root.wax, 1.5)
            font.family: Theme.blackletter
            font.pixelSize: root.size * 0.42
        }
    }

    Repeater {
        model: [true, false]
        Item {
            id: half
            required property bool modelData
            width: root.size; height: root.size
            x: (modelData ? -9 : 11) * root.crack
            y: (modelData ? 6 : 12) * root.crack * root.crack
            rotation: (modelData ? -24 : 19) * root.crack
            opacity: 1 - Math.max(0, root.crack - 0.45) / 0.55
            Shape {
                id: mask
                anchors.fill: parent
                visible: false
                layer.enabled: true
                ShapePath { strokeColor: "transparent"; fillColor: "white"; PathSvg { path: root.halfPath(half.modelData) } }
            }
            MultiEffect {
                anchors.fill: parent
                source: art
                maskEnabled: true
                maskSource: mask
                shadowEnabled: true
                shadowColor: root.glowing ? Theme.arcane : "#000000"
                shadowBlur: root.glowing ? 0.6 + root.pulse * 0.4 : 0.3
                shadowOpacity: root.glowing ? 0.6 + root.pulse * 0.4 : 0.5
                shadowHorizontalOffset: root.glowing ? 0 : 1
                shadowVerticalOffset: root.glowing ? 0 : 2
                blurMax: 16
            }
        }
    }
}
