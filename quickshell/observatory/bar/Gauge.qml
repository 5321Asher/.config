import QtQuick
import QtQuick.Effects
import "../theme"

// One analog instrument: a 240° brass dial with graduations and a red zone, a needle that swings
// to the value (OutCubic), and a small-caps label with a mono readout beside it.
// Past Theme.gaugeAlarm of full scale the needle, arc and readout turn signal red.
Item {
    id: root

    property string label: ""
    property real value: 0          // 0-1 of full scale
    property string readout: ""
    signal clicked()

    readonly property bool alarm: value > Theme.gaugeAlarm
    readonly property color ink: alarm ? Theme.signal : Theme.brassBright

    // The needle trails the value mechanically
    property real shown: value
    Behavior on shown { NumberAnimation { duration: Theme.slow; easing.type: Theme.easing } }
    property color inkShown: ink
    Behavior on inkShown { ColorAnimation { duration: Theme.normal } }

    implicitWidth: dialLayer.width + 6 + texts.width
    implicitHeight: Theme.barHeight

    readonly property real r: Theme.gaugeRadius
    readonly property real start: Math.PI * 5 / 6          // 150°, lower left
    readonly property real sweep: Math.PI * 4 / 3          // 240°
    function angle(f) { return start + sweep * Math.max(0, Math.min(1, f)); }

    Item {
        id: dialLayer
        width: root.r * 2 + 8
        height: parent.height

        Canvas {
            id: dial
            anchors.fill: parent
            renderStrategy: Canvas.Cooperative

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const cx = width / 2, cy = Theme.gaugeCenterY, r = root.r;

                // Face
                ctx.fillStyle = Theme.alpha(Theme.bgDark, 0.8);
                ctx.beginPath();
                ctx.arc(cx, cy, r + 1, 0, 2 * Math.PI);
                ctx.fill();

                // Bezel over the working range
                ctx.strokeStyle = Theme.alpha(Theme.brassDeep, 0.95);
                ctx.lineWidth = 1;
                ctx.beginPath();
                ctx.arc(cx, cy, r, root.angle(0), root.angle(Theme.gaugeAlarm));
                ctx.stroke();
                // Red zone
                ctx.strokeStyle = Theme.alpha(Theme.signal, 0.85);
                ctx.lineWidth = 2;
                ctx.beginPath();
                ctx.arc(cx, cy, r - 0.5, root.angle(Theme.gaugeAlarm), root.angle(1));
                ctx.stroke();

                // Graduations every 10%, long at 0 / 50 / 100
                for (let i = 0; i <= 10; i++) {
                    const a = root.angle(i / 10), major = i % 5 === 0;
                    const r1 = r - 2, r2 = r - (major ? 5 : 3.5);
                    ctx.strokeStyle = i >= 9 ? Theme.alpha(Theme.signal, 0.8)
                                             : Theme.alpha(Theme.brass, major ? 0.9 : 0.55);
                    ctx.lineWidth = major ? 1.1 : 0.8;
                    ctx.beginPath();
                    ctx.moveTo(cx + r1 * Math.cos(a), cy + r1 * Math.sin(a));
                    ctx.lineTo(cx + r2 * Math.cos(a), cy + r2 * Math.sin(a));
                    ctx.stroke();
                }

                // Phosphor trace of the reading inside the scale
                ctx.strokeStyle = Theme.alpha(root.alarm ? Theme.signal : Theme.phosphor, 0.35);
                ctx.lineWidth = 2;
                ctx.beginPath();
                ctx.arc(cx, cy, r - 7, root.angle(0), root.angle(root.shown));
                ctx.stroke();

                // Needle and pivot
                const a = root.angle(root.shown), nl = r - 2;
                const nx = Math.cos(a), ny = Math.sin(a), px = -ny, py = nx;
                ctx.fillStyle = root.inkShown;
                ctx.beginPath();
                ctx.moveTo(cx + nx * nl, cy + ny * nl);
                ctx.lineTo(cx + px * 1.4, cy + py * 1.4);
                ctx.lineTo(cx - nx * 3.5, cy - ny * 3.5);
                ctx.lineTo(cx - px * 1.4, cy - py * 1.4);
                ctx.closePath();
                ctx.fill();
                ctx.fillStyle = Theme.brassDeep;
                ctx.strokeStyle = Theme.brass;
                ctx.lineWidth = 0.8;
                ctx.beginPath();
                ctx.arc(cx, cy, 2, 0, 2 * Math.PI);
                ctx.fill();
                ctx.stroke();
            }

            Connections {
                target: root
                function onShownChanged() { dial.requestPaint(); }
                function onInkShownChanged() { dial.requestPaint(); }
            }
            Connections {
                target: Theme
                function onPaletteChanged() { dial.requestPaint(); }
            }
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: root.alarm ? Theme.signal : Theme.brass
            shadowBlur: 0.3
            shadowOpacity: 0.55
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
            blurMax: 10
        }
    }

    Column {
        id: texts
        anchors.left: dialLayer.right
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 1
        spacing: -3

        Text {
            text: root.label
            color: root.alarm ? Theme.signal : Theme.brass
            font.family: Theme.fontLabel
            font.pixelSize: Theme.labelSize - 1
            font.capitalization: Font.SmallCaps
            font.letterSpacing: Theme.labelSpacing
            font.weight: Font.DemiBold
            Behavior on color { ColorAnimation { duration: Theme.normal } }
        }
        Text {
            text: root.readout
            color: root.alarm ? Theme.signal : Theme.fg
            font.family: Theme.fontData
            font.pixelSize: Theme.dataSizeSmall
            Behavior on color { ColorAnimation { duration: Theme.normal } }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
