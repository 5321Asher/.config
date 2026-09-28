import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../theme"
import "../widgets"
import "../services"

// Dictation (voxtype, SUPER + Z): VOICE 音声 at the bottom of the focused screen: the live
// microphone as a mirrored bar trace, the time, and what's happening (LISTENING in red,
// DECODING while it types). Click to stop; the ✕ cancels.
PanelWindow {
    id: root

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    visible: Voxtype.busy

    anchors { bottom: true }
    margins { bottom: 40 }
    implicitWidth: 460
    implicitHeight: 90
    color: "transparent"
    exclusionMode: ExclusionMode.Normal
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "netrunner-voice"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Chamfer { anchors.fill: parent; cut: 14; corners: "tr bl"; fill: Theme.alpha(Theme.bgDark, 0.94)
              stroke: Voxtype.recording ? Theme.red : Theme.cyan }
    MouseArea { anchors.fill: parent; onClicked: if (Voxtype.recording) Voxtype.toggle() }

    Column {
        x: 18; y: 14
        spacing: 6
        Row {
            spacing: 8
            Tag { height: 18; pixelSize: 10; text: "VOICE"; color: Voxtype.recording ? Theme.red : Theme.cyan }
            Jp { anchors.verticalCenter: parent.verticalCenter; text: "音声" }
        }
        Label { text: Voxtype.recording ? "LISTENING  " + Voxtype.elapsedText : "DECODING…"; strong: true
                color: Voxtype.recording ? Theme.red : Theme.cyan
                SequentialAnimation on opacity { running: Voxtype.transcribing; loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 350 } NumberAnimation { to: 1; duration: 350 } } }
        Label { text: Voxtype.recording ? "SUPER+Z SENDS  //  ✕ CANCELS" : "TYPING INTO THE FOCUSED WINDOW" }
    }
    Row {
        x: 210
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3
        Repeater {
            model: MicLevel.count
            Rectangle {
                required property int index
                anchors.verticalCenter: parent.verticalCenter
                width: 5
                height: Math.max(2, (MicLevel.bars[index] ?? 0) * 58)
                color: Voxtype.recording ? Theme.red : Theme.cyan
                Behavior on height { NumberAnimation { duration: 60 } }
            }
        }
    }
    Text {
        anchors.right: parent.right
        anchors.rightMargin: 14
        y: 10
        text: "✕"
        color: Theme.dim
        font.pixelSize: 14
        MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: Voxtype.cancel() }
    }
}
