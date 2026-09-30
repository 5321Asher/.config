import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../theme"
import "../widgets"
import "../services"

// The scribe (voxtype dictation, SUPER + Z): a strip of parchment at the foot of the focused
// screen. While it listens, your voice is drawn as strokes of red ink from a quill on the left and
// the time runs; while it writes, the words go into the window you were in. Click it to send, ✕ to
// cancel.
PanelWindow {
    id: root

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    visible: Voxtype.busy

    anchors { bottom: true }
    margins { bottom: 36 }
    implicitWidth: 500
    implicitHeight: 96
    color: "transparent"
    exclusionMode: ExclusionMode.Normal
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "grimoire-scribe"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Rectangle {
        anchors.fill: parent; anchors.margins: 6; anchors.topMargin: 12
        radius: 3; color: Qt.alpha("#000000", 0.45)
        layer.enabled: true
        layer.effect: MultiEffect { blurEnabled: true; blur: 0.7; blurMax: 16 }
    }
    Parchment { x: 4; y: 4; width: parent.width - 12; height: parent.height - 14; age: 0.4 }
    MouseArea { anchors.fill: parent; onClicked: if (Voxtype.recording) Voxtype.toggle() }

    Column {
        x: 22; y: 16
        spacing: 3
        Text {
            text: Voxtype.recording ? "The scribe listens" : "The scribe writes…"
            color: Theme.ink
            font.family: Theme.display; font.weight: Font.DemiBold
            font.pixelSize: 17
            SequentialAnimation on opacity { running: Voxtype.transcribing; loops: Animation.Infinite
                NumberAnimation { to: 0.35; duration: 500; easing.type: Easing.InOutSine } NumberAnimation { to: 1; duration: 500; easing.type: Easing.InOutSine } }
        }
        Body { text: Voxtype.recording ? Voxtype.elapsedText + " · super + z sends" : "into the window you were in"; italic: true; color: Theme.inkDim; font.pixelSize: 13 }
        Caps { visible: Voxtype.recording; text: "✕ cancels"; font.pixelSize: 10 }
    }
    // the voice, in ink
    Row {
        x: 228
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -4
        spacing: 3
        Text { anchors.verticalCenter: parent.verticalCenter; text: "✒"; color: Theme.inkDim; font.family: Theme.symbols; font.pixelSize: 18 }
        Repeater {
            model: MicLevel.count
            Rectangle {
                required property int index
                anchors.verticalCenter: parent.verticalCenter
                width: 4
                radius: 2
                height: Math.max(2, (MicLevel.bars[index] ?? 0) * 54)
                color: Voxtype.recording ? Theme.rubric : Theme.inkDim
                Behavior on height { NumberAnimation { duration: 70 } }
            }
        }
    }
    Text {
        anchors.right: parent.right
        anchors.rightMargin: 20
        y: 12
        text: "✕"
        color: Theme.inkDim
        font.pixelSize: 13
        MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: Voxtype.cancel() }
    }
}
