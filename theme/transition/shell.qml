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
//   glitch    the old picture tears into horizontal bands that jitter sideways with red/cyan edges
//             in the new accent and its complement, then drop out one by one (Netrunner)
//   burn      the old picture burns away from a scatter of embers: a ragged front with a scorched
//             band and a glowing lip in the new accent (Grimoire; a shader, burn.frag.qsb)
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
        easing.type: root.style === "fade" ? Easing.InOutQuad : root.style === "dissolve" || root.style === "glitch" ? Easing.Linear : root.style === "burn" ? Easing.InQuad : Easing.InOutCubic
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
                visible: root.style !== "fade" && root.style !== "glitch" && root.style !== "burn"
                source: shot
                maskEnabled: true
                maskSource: hole
                maskInverted: true
                maskThresholdMin: 0.5
                maskSpreadAtMin: 0.02
            }

            // glitch: bands of the old picture, torn sideways, dropping out at random moments
            Item {
                anchors.fill: parent
                visible: root.style === "glitch"
                clip: true
                Repeater {
                    id: bands
                    model: root.style === "glitch" ? 22 : 0
                    Item {
                        id: band
                        required property int index
                        readonly property real at: 0.15 + Math.random() * 0.8
                        readonly property real jitter: (Math.random() - 0.5) * 140
                        readonly property real bandY: index / 22 * win.height
                        readonly property bool alive: root.progress < at
                        readonly property bool torn: root.progress > at - 0.18
                        y: bandY
                        width: win.width
                        height: win.height / 22 + 1
                        visible: alive
                        clip: true
                        Image {
                            y: -band.bandY
                            x: band.torn ? band.jitter * (0.3 + Math.random() * 0.7) : 0
                            width: win.width
                            height: win.height
                            source: shot.source
                            cache: true
                            asynchronous: false
                        }
                        // chromatic edges while it tears
                        Rectangle { visible: band.torn; width: parent.width; height: 2; color: root.accent; opacity: 0.8 }
                        Rectangle { visible: band.torn; y: parent.height - 2; width: parent.width; height: 2
                                    color: Qt.rgba(1 - root.accent.r, 1 - root.accent.g, 1 - root.accent.b, 1); opacity: 0.6 }
                    }
                }
                // the progress jitters the whole thing a little
                Timer { running: root.style === "glitch" && reveal.running; interval: 40; repeat: true
                        onTriggered: parent.x = (Math.random() - 0.5) * 12 * (1 - root.progress) }
            }

            // burn: the shader eats the old picture from a few embers outward
            ShaderEffect {
                anchors.fill: parent
                visible: root.style === "burn"
                property var source: shot
                property real progress: root.progress
                property real aspect: win.width / Math.max(1, win.height)
                property real seed: 0.37 + Quickshell.screens.indexOf(win.modelData) * 0.21
                property color accent: root.accent
                fragmentShader: root.style === "burn" ? Qt.resolvedUrl("burn.frag.qsb") : ""
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
