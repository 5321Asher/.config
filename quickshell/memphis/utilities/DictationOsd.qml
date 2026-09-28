import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../theme"
import "../widgets"
import "../services"

// Dictation (voxtype, SUPER + Z), as 98's Sound Recorder: a small window above the taskbar with
// the green trace on black (the live microphone), "Position" and "Length", and its ● ■ buttons.
// ■ (or SUPER + Z again) stops and types what you said; the close button cancels.
PanelWindow {
    id: root

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    visible: Voxtype.busy

    anchors { bottom: true }
    margins { bottom: 10 }
    implicitWidth: 420
    implicitHeight: 190
    color: "transparent"
    exclusionMode: ExclusionMode.Normal
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "memphis-dictation"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Win {
        anchors.fill: parent
        title: "Dictation - Sound Recorder"
        icon: "audio-input-microphone"
        minButton: true
        onCloseRequested: Voxtype.cancel()
        onMinRequested: Voxtype.cancel()

        Row {
            x: 8; y: 8
            spacing: 8
            Column {
                spacing: 2
                Txt { text: "Position:" }
                Txt { text: Voxtype.elapsedText + " sec." }
            }
            // the trace: the microphone's levels as a waveform, green on black
            Bevel {
                width: 220
                height: 56
                kind: "sunken"
                fill: "#000000"
                Canvas {
                    id: trace
                    anchors.fill: parent
                    anchors.margins: 2
                    property var bars: MicLevel.bars
                    onBarsChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        const mid = height / 2;
                        ctx.strokeStyle = "#00ff00";
                        ctx.lineWidth = 1;
                        ctx.beginPath();
                        const n = bars.length;
                        for (let x = 0; x < width; x++) {
                            const v = n ? bars[Math.floor(x / width * n)] : 0;
                            const y = mid + Math.sin(x * 0.9) * v * (height / 2 - 2);
                            if (x === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
                        }
                        ctx.stroke();
                    }
                }
            }
            Column {
                spacing: 2
                Txt { text: "Length:" }
                Txt { text: Voxtype.recording ? "listening" : "typing…" }
            }
        }
        Row {
            x: 8
            y: 76
            spacing: 4
            Btn { width: 46; implicitWidth: 46; padding: 0; glyph: "stop"; enabled: Voxtype.recording; onClicked: Voxtype.toggle() }
            Btn {
                width: 46; implicitWidth: 46; padding: 0
                enabled: false
                Rectangle { width: 12; height: 12; radius: 6; color: Voxtype.recording ? "#e00000" : Theme.grayText }
            }
            Txt {
                height: Theme.button
                leftPadding: 8
                text: Voxtype.recording ? "Recording… press ■ or Super+Z to type it" : "Turning your words into text…"
            }
        }
        Progress {
            x: 8
            y: 116
            width: parent.width - 16
            height: 16
            visible: Voxtype.transcribing
            smooth: false
            // an indeterminate bar: blocks marching along
            SequentialAnimation on value {
                running: Voxtype.transcribing
                loops: Animation.Infinite
                NumberAnimation { from: 0; to: 1; duration: 1600 }
            }
        }
    }
}
