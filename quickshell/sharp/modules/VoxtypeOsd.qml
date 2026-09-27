import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// Bottom-centre overlay on the focused monitor while voxtype is recording or transcribing.
// Click-through and never takes keyboard focus, so the text still lands in the window you were in.
PanelWindow {
    id: root

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    visible: Voxtype.busy || card.opacity > 0
    color: "transparent"
    anchors.bottom: true
    margins.bottom: 48
    // Fixed size: resizing the layer surface as the text changes leaves a stale strip for a frame
    implicitWidth: 640
    implicitHeight: card.height
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-voxtype"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    Rectangle {
        id: card

        readonly property color tint: Voxtype.recording ? Theme.danger : Theme.accent

        anchors.horizontalCenter: parent.horizontalCenter
        width: row.implicitWidth + 32
        height: 44
        opacity: Voxtype.busy ? 1 : 0
        color: Theme.bgDark
        border.width: 1
        border.color: tint

        Behavior on opacity { NumberAnimation { duration: 180 } }
        Behavior on border.color { ColorAnimation { duration: 180 } }

        RowLayout {
            id: row

            anchors.centerIn: parent
            spacing: 10

            // Recording: pulsing square, like the bar's REC pill
            Rectangle {
                visible: Voxtype.recording
                implicitWidth: 10
                implicitHeight: 10
                color: Theme.danger

                SequentialAnimation on opacity {
                    running: Voxtype.recording
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.25; duration: 700 }
                    NumberAnimation { to: 1; duration: 700 }
                }
            }

            // Transcribing: three squares lighting up in turn
            Row {
                visible: Voxtype.transcribing
                spacing: 4

                Repeater {
                    model: 3

                    Rectangle {
                        required property int index
                        width: 6
                        height: 6
                        color: Theme.accent
                        opacity: 0.25

                        SequentialAnimation on opacity {
                            running: Voxtype.transcribing
                            loops: Animation.Infinite
                            PauseAnimation { duration: index * 180 }
                            NumberAnimation { to: 1; duration: 250 }
                            NumberAnimation { to: 0.25; duration: 450 }
                            PauseAnimation { duration: (2 - index) * 180 }
                        }
                    }
                }
            }

            Text {
                text: Voxtype.recording ? "Listening" : "Transcribing"
                font.family: Theme.font
                font.pixelSize: 13
                font.bold: true
                color: Theme.fg
            }

            Text {
                visible: Voxtype.recording
                text: Voxtype.elapsedText
                font.family: Theme.font
                font.pixelSize: 13
                color: Theme.danger
            }

            Text {
                visible: Voxtype.recording
                text: "SUPER+Z finish · SUPER+SHIFT+Z cancel"
                font.family: Theme.font
                font.pixelSize: 11
                color: Theme.dim
            }
        }
    }
}
