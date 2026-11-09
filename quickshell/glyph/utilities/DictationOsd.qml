import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../theme"
import "../widgets"
import "../services"

// Dictation (voxtype, SUPER + Z): a pill at the bottom while it listens or types: the red dot (the
// live thing) and the time, the mic level as a Glyph strip of dots, ✕ to cancel. Click sends.
PanelWindow {
    id: root

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    readonly property real s: Theme.scaleFor(screen)
    visible: Voxtype.busy

    anchors { bottom: true }
    margins { bottom: Math.round(40 * s) }
    implicitWidth: Math.ceil(560 * s)
    implicitHeight: Math.ceil(76 * s)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "glyph-voice"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Stage {
        s: root.s
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Theme.s1
            border { width: 1; color: Voxtype.recording ? Theme.fg : Theme.s3 }
            MouseArea { anchors.fill: parent; onClicked: if (Voxtype.recording) Voxtype.toggle() }

            Rectangle {
                id: dot
                x: 26
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 16
                radius: 8
                color: Voxtype.recording ? Theme.red : Theme.grey
                SequentialAnimation on opacity {
                    running: root.visible
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.25; duration: 600; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 600; easing.type: Easing.InOutSine }
                }
            }
            Column {
                anchors { left: dot.right; leftMargin: 16; verticalCenter: parent.verticalCenter }
                Lb { text: Voxtype.recording ? "listening" : "typing…"; color: Theme.fg; px: 11 }
                Lb { text: Voxtype.recording ? "super + z sends" : "into the focused window"; px: 9 }
            }
            Num {
                id: time
                anchors { right: bars.left; rightMargin: 20; verticalCenter: parent.verticalCenter }
                text: Voxtype.elapsedText
                font.pixelSize: 30
            }
            // the mic as columns of dots, lit from the middle out
            Row {
                id: bars
                anchors { right: close.left; rightMargin: 20; verticalCenter: parent.verticalCenter }
                spacing: 4
                Repeater {
                    model: Math.min(16, MicLevel.count)
                    Column {
                        required property int index
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3
                        readonly property int lit: Math.round((MicLevel.bars[index] ?? 0) * 7)
                        Repeater {
                            model: 7
                            Rectangle {
                                required property int index
                                width: 5
                                height: 5
                                radius: 2.5
                                color: Math.abs(index - 3) * 2 < parent.lit ? Theme.fg : Theme.s3
                            }
                        }
                    }
                }
            }
            Rectangle {
                id: close
                anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                width: 48
                height: 48
                radius: 24
                color: ch.hovered ? Theme.s3 : Theme.s2
                Icon { anchors.centerIn: parent; text: "\u{F0156}"; font.pixelSize: 18 }
                HoverHandler { id: ch; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: Voxtype.cancel() }
            }
        }
    }
}
