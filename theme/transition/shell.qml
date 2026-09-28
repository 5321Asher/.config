//@ pragma UseQApplication

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// The switch transition, run by ~/.config/theme/theme around `theme set` / `theme setup`.
//
// It covers every monitor with a snapshot of what was on it a moment ago (so nothing seems to happen),
// the switch runs underneath it, then `qs ipc -p <this folder> call transition go` reveals the new
// look in the setup's style and the process quits:
//   fade   a plain crossfade
//   wipe   a hard-edged sweep from the left with a line in the new accent (Sharp)
//   iris   a circle opening from the centre, edged with a ring in the new accent (Observatory)
//   dissolve  the old picture breaks up into square blocks in random order (Memphis)
// params.json (written by the theme tool, next to the snapshots): style, accent, duration, dir.
ShellRoot {
    id: root

    readonly property string dir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/theme-transition"
    property var params: ({})
    readonly property string style: params.style ?? "fade"
    readonly property color accent: params.accent ?? "#ffffff"
    readonly property int duration: params.duration ?? 700

    property real progress: 0            // 0 = the old picture, 1 = gone
    NumberAnimation on progress {
        id: reveal
        running: false
        from: 0; to: 1
        duration: root.duration
        easing.type: root.style === "fade" ? Easing.InOutQuad : root.style === "dissolve" ? Easing.Linear : Easing.InOutCubic
        onFinished: cleanup.running = true
    }
    // The snapshots are ~10 MB each in RAM (tmpfs): gone with the overlay
    Process {
        id: cleanup
        command: ["sh", "-c", 'rm -f "$1"/*.ppm "$1"/ready', "sh", root.dir]
        onExited: Qt.quit()
    }

    FileView {
        path: root.dir + "/params.json"
        blockLoading: true
        onLoaded: root.params = JSON.parse(text())
    }

    function go() { if (!reveal.running) reveal.start(); }

    IpcHandler {
        target: "transition"
        function go(): void { root.go(); }
    }
    // If the theme tool never says go (it crashed), don't leave the screen frozen
    Timer { running: true; interval: 10000; onTriggered: root.go() }

    // Tell the theme tool the covers are up (a couple of frames after they're shown)
    Timer { id: ready; interval: 60; running: true; onTriggered: touch.running = true }
    Process { id: touch; command: ["touch", root.dir + "/ready"] }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "theme-transition"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region {}

            readonly property real diag: Math.hypot(width, height)

            // The old picture
            Image {
                id: shot
                anchors.fill: parent
                source: "file://" + root.dir + "/" + win.modelData.name + ".ppm"
                asynchronous: false
                cache: false
                visible: root.style === "fade"
                opacity: 1 - root.progress
            }

            // wipe / iris: the old picture with a hole cut in it that grows to the whole screen
            Item {
                id: hole
                anchors.fill: parent
                visible: false
                layer.enabled: true
                Rectangle {
                    visible: root.style === "wipe"
                    width: win.width * root.progress
                    height: win.height
                    color: "white"
                }
                // dissolve: blocks, each gone once progress passes its own random moment
                Repeater {
                    id: blocks
                    readonly property int size: 32
                    readonly property int cols: Math.ceil(win.width / size)
                    model: root.style === "dissolve" ? cols * Math.ceil(win.height / size) : 0
                    Rectangle {
                        required property int index
                        readonly property real at: Math.random() * 0.94
                        x: (index % blocks.cols) * blocks.size
                        y: Math.floor(index / blocks.cols) * blocks.size
                        width: blocks.size
                        height: blocks.size
                        visible: root.progress > at
                        color: "white"
                    }
                }
                Rectangle {
                    visible: root.style === "iris"
                    readonly property real d: win.diag * 1.02 * root.progress
                    x: (win.width - d) / 2
                    y: (win.height - d) / 2
                    width: d
                    height: d
                    radius: d / 2
                    color: "white"
                }
            }
            MultiEffect {
                anchors.fill: parent
                visible: root.style !== "fade"
                source: shot
                maskEnabled: true
                maskSource: hole
                maskInverted: true
                maskThresholdMin: 0.5
                maskSpreadAtMin: 0.02
            }

            // The edge, in the new accent
            Rectangle {
                visible: root.style === "wipe" && root.progress > 0 && root.progress < 1
                x: win.width * root.progress - width / 2
                width: 3
                height: win.height
                color: root.accent
            }
            Rectangle {
                visible: root.style === "iris" && root.progress > 0 && root.progress < 1
                readonly property real d: win.diag * 1.02 * root.progress
                x: (win.width - d) / 2
                y: (win.height - d) / 2
                width: d
                height: d
                radius: d / 2
                color: "transparent"
                border.width: 3
                border.color: root.accent
                opacity: 1 - root.progress * 0.6

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: root.accent
                    shadowBlur: 0.7
                    shadowOpacity: 0.9
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0
                    blurMax: 24
                }
            }
        }
    }
}
