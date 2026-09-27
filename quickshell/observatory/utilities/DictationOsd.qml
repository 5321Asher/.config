import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../theme"
import "../services"

// Voxtype dictation, bottom centre of the focused monitor, as a radio receiver plate:
// listening = a pulsing signal-red beacon and the elapsed time; transcribing = a phosphor sweep
// ("decoding"). Click-through and never takes the keyboard, so the text lands where you were typing.
PanelWindow {
    id: root

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    visible: Voxtype.busy || plate.opacity > 0
    color: "transparent"
    anchors.bottom: true
    margins.bottom: Theme.dictationBottom
    // Fixed size: resizing the layer surface as the text changes leaves a stale strip for a frame
    implicitWidth: 620
    implicitHeight: Theme.dictationHeight + 20
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "observatory-dictation"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    Item {
        id: plate
        readonly property color tint: Voxtype.recording ? Theme.signal : Theme.phosphor
        anchors.horizontalCenter: parent.horizontalCenter
        y: 10 + (1 - opacity) * 12
        width: row.implicitWidth + 44
        height: Theme.dictationHeight
        opacity: Voxtype.busy ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.normal; easing.type: Theme.easing } }

        // Plate with both lower corners cut
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 1
                strokeColor: Theme.alpha(plate.tint, 0.8)
                fillColor: Theme.panel
                startX: 0.5; startY: 0.5
                PathLine { x: plate.width - 0.5; y: 0.5 }
                PathLine { x: plate.width - 0.5; y: plate.height - Theme.chamfer }
                PathLine { x: plate.width - Theme.chamfer; y: plate.height - 0.5 }
                PathLine { x: Theme.chamfer; y: plate.height - 0.5 }
                PathLine { x: 0.5; y: plate.height - Theme.chamfer }
                PathLine { x: 0.5; y: 0.5 }
            }
        }
        // Decoding sweep across the plate
        Rectangle {
            visible: Voxtype.transcribing
            y: 1
            height: parent.height - 2
            width: 60
            opacity: 0.18
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.7; color: Theme.phosphor }
                GradientStop { position: 1; color: "transparent" }
            }
            NumberAnimation on x {
                running: Voxtype.transcribing
                from: -60; to: plate.width
                duration: 1100
                loops: Animation.Infinite
            }
        }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 12

            // Beacon: a ring with a pulsing core
            Item {
                width: 16
                height: 16
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    border.width: 1
                    border.color: plate.tint
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 8
                    height: 8
                    radius: 4
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
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Voxtype.recording ? "listening" : "decoding"
                color: plate.tint
                font.family: Theme.fontLabel
                font.pixelSize: Theme.labelSizeLarge
                font.capitalization: Font.SmallCaps
                font.letterSpacing: Theme.labelSpacing * 1.5
                font.weight: Font.DemiBold
            }
            Text {
                visible: Voxtype.recording
                anchors.verticalCenter: parent.verticalCenter
                text: Voxtype.elapsedText
                color: Theme.fg
                font.family: Theme.fontData
                font.pixelSize: Theme.dataSize
            }
            Text {
                visible: Voxtype.recording
                anchors.verticalCenter: parent.verticalCenter
                text: "super+z send  ·  super+shift+z cancel"
                color: Theme.dim
                font.family: Theme.fontData
                font.pixelSize: Theme.dataSizeSmall
            }
        }
    }
}
