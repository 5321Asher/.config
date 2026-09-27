import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../theme"
import "../services"

// Voxtype dictation notifier, bottom centre of the focused monitor, as a radio receiver plate.
// Listening: a pulsing signal-red beacon, a live oscilloscope trace of your microphone and the
// elapsed time. Decoding (transcribing): the trace flattens and a phosphor sweep runs across.
// Click-through and never takes the keyboard, so the text lands where you were typing.
PanelWindow {
    id: root

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    visible: Voxtype.busy || plate.opacity > 0
    color: "transparent"
    anchors.bottom: true
    margins.bottom: Theme.dictationBottom
    // Fixed size: resizing the layer surface as the text changes leaves a stale strip for a frame
    implicitWidth: 820
    implicitHeight: Theme.dictationHeight + 30
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "observatory-dictation"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    // The mic is only read while recording
    Binding { target: MicLevel; property: "active"; value: Voxtype.recording }

    Item {
        id: plate
        readonly property color tint: Voxtype.recording ? Theme.signal : Theme.phosphor
        anchors.horizontalCenter: parent.horizontalCenter
        y: 15 + (1 - opacity) * 16
        width: row.implicitWidth + 56
        height: Theme.dictationHeight
        opacity: Voxtype.busy ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.normal; easing.type: Theme.easing } }

        // Plate: corners cut, a brass hairline and a coloured top rule
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 1.2
                strokeColor: Theme.alpha(plate.tint, 0.85)
                fillColor: Theme.alpha(Theme.bgDark, 0.93)
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
                shadowEnabled: true; shadowColor: plate.tint; shadowBlur: 0.8; shadowOpacity: 0.55
                shadowHorizontalOffset: 0; shadowVerticalOffset: 0; blurMax: 28
            }
        }
        // Decoding sweep across the plate
        Rectangle {
            visible: Voxtype.transcribing
            y: 1
            height: parent.height - 2
            width: 90
            opacity: 0.2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.75; color: Theme.phosphor }
                GradientStop { position: 1; color: "transparent" }
            }
            NumberAnimation on x {
                running: Voxtype.transcribing
                from: -90; to: plate.width
                duration: 1000
                loops: Animation.Infinite
            }
        }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 16

            // Beacon: a ring with a pulsing core
            Item {
                width: 20
                height: 20
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    border.width: 1.2
                    border.color: plate.tint
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 10
                    height: 10
                    radius: 5
                    color: plate.tint
                    SequentialAnimation on opacity {
                        running: Voxtype.busy
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.2; duration: Voxtype.recording ? 650 : 300 }
                        NumberAnimation { to: 1; duration: Voxtype.recording ? 650 : 300 }
                    }
                }
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true; shadowColor: plate.tint; shadowBlur: 0.7; shadowOpacity: 1
                    shadowHorizontalOffset: 0; shadowVerticalOffset: 0; blurMax: 12
                }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: -2
                Text {
                    text: Voxtype.recording ? "listening" : "decoding"
                    color: plate.tint
                    font.family: Theme.fontLabel
                    font.pixelSize: Theme.labelSizeLarge + 2
                    font.capitalization: Font.SmallCaps
                    font.letterSpacing: Theme.labelSpacing * 1.5
                    font.weight: Font.DemiBold
                }
                Text {
                    text: Voxtype.recording ? "dictation · voxtype" : "transcribing your transmission"
                    color: Theme.dim
                    font.family: Theme.fontData
                    font.pixelSize: Theme.dataSizeSmall
                }
            }

            // Live microphone trace
            Item {
                id: scope
                width: Theme.dictationTrace
                height: Theme.dictationHeight - 16
                anchors.verticalCenter: parent.verticalCenter

                Canvas {
                    id: trace
                    anchors.fill: parent
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        const w = width, h = height, mid = h / 2;
                        // graticule
                        ctx.strokeStyle = Theme.alpha(Theme.brass, 0.18);
                        ctx.lineWidth = 1;
                        ctx.beginPath();
                        ctx.moveTo(0, mid + 0.5); ctx.lineTo(w, mid + 0.5);
                        for (let x = 0; x <= w; x += w / 8) { ctx.moveTo(Math.round(x) + 0.5, mid - 3); ctx.lineTo(Math.round(x) + 0.5, mid + 3); }
                        ctx.stroke();
                        // the trace: mirrored levels, alternating up and down like a waveform
                        const bars = MicLevel.bars, n = bars.length;
                        const steps = Math.floor(w / 5);
                        ctx.strokeStyle = Voxtype.recording ? Theme.signal : Theme.phosphor;
                        ctx.lineWidth = 1.6;
                        ctx.beginPath();
                        let px = 0, py = mid;
                        ctx.moveTo(0, mid);
                        for (let j = 1; j <= steps; j++) {
                            const x = j / steps * w;
                            const t = Math.abs(j / steps * 2 - 1);         // bass in the middle
                            const f = (1 - t) * (n - 1), i = Math.floor(f), k = f - i;
                            const v = (bars[i] ?? 0) * (1 - k) + (bars[Math.min(n - 1, i + 1)] ?? 0) * k;
                            const env = Math.sin(Math.PI * j / steps);
                            const y = mid + (j % 2 ? 1 : -1) * v * env * (mid - 2);
                            ctx.quadraticCurveTo(px, py, (px + x) / 2, (py + y) / 2);
                            px = x; py = y;
                        }
                        ctx.lineTo(w, mid);
                        ctx.stroke();
                    }
                    Connections {
                        target: MicLevel
                        function onBarsChanged() { trace.requestPaint(); }
                    }
                    Connections {
                        target: Voxtype
                        function onStatusChanged() { trace.requestPaint(); }
                    }
                }
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true; shadowColor: plate.tint; shadowBlur: 0.5; shadowOpacity: 0.9
                    shadowHorizontalOffset: 0; shadowVerticalOffset: 0; blurMax: 10
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                Text {
                    text: Voxtype.recording ? Voxtype.elapsedText : "···"
                    color: Theme.fg
                    font.family: Theme.fontData
                    font.pixelSize: Theme.dataSize + 3
                }
                Text {
                    visible: Voxtype.recording
                    text: "super+z send · super+shift+z cancel"
                    color: Theme.dim
                    font.family: Theme.fontData
                    font.pixelSize: Theme.dataSizeSmall
                }
            }
        }
    }
}
