import QtQuick
import Quickshell
import Quickshell.Wayland
import "../theme"
import "../widgets"
import "../services"
import "../flyouts"

// Voice typing (Windows + H), for voxtype: the small bar at the top of the screen with the
// microphone button (it glows with your voice: a live meter from MicLevel), "Listening…" or
// "Writing it down…", and close. Click the microphone to finish, × to cancel.
PanelWindow {
    id: root

    screen: Quickshell.screens.find(s => s.name === Flyouts.focusedScreen()?.name) ?? Quickshell.screens[0]
    visible: Voxtype.busy || fade.running
    anchors { top: true }
    margins { top: 24 }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 300
    implicitHeight: 64
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "disguise-voice"

    readonly property real level: MicLevel.bars.length ? Math.min(1, MicLevel.bars.reduce((a, b) => Math.max(a, b), 0) * 1.6) : 0

    Item {
        anchors.fill: parent
        opacity: Voxtype.busy ? 1 : 0
        Behavior on opacity { NumberAnimation { id: fade; duration: Theme.normal } }
        Acrylic { anchors.fill: parent; radius: Theme.radiusLarge }

        // the microphone: an accent circle, ringed by your voice
        Item {
            x: 12; width: 44; height: 44
            anchors.verticalCenter: parent.verticalCenter
            Rectangle {
                anchors.centerIn: parent
                width: 40 + root.level * 14; height: width; radius: width / 2
                color: Qt.alpha(Theme.accent, 0.3)
                visible: Voxtype.recording
                Behavior on width { NumberAnimation { duration: 80 } }
            }
            Rectangle {
                anchors.centerIn: parent
                width: 40; height: 40; radius: 20
                color: Voxtype.recording ? (mic.containsMouse ? Theme.accentHover : Theme.accent) : Theme.control
                border.width: Voxtype.recording ? 0 : 1
                border.color: Theme.controlStroke
                Glyph { anchors.centerIn: parent; g: ""; size: 16; color: Voxtype.recording ? Theme.accentText : Theme.text }
                Ring { anchors.fill: parent; visible: Voxtype.transcribing; indeterminate: true; thickness: 2 }
            }
            MouseArea { id: mic; anchors.fill: parent; hoverEnabled: true; onClicked: Voxtype.toggle() }
        }
        Column {
            x: 68
            anchors.verticalCenter: parent.verticalCenter
            Txt { text: Voxtype.recording ? "Listening…" : "Writing it down…"; strong: true }
            Txt { text: Voxtype.recording ? Voxtype.elapsedText + " · Super + Z to finish" : "Hold on"; size: Theme.caption; level: 2 }
        }
        Btn {
            anchors.right: parent.right; anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            kind: "subtle"; glyph: ""; glyphSize: 12; width: 32
            onClicked: Voxtype.cancel()
        }
    }
}
