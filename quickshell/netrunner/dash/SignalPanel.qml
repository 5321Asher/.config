import QtQuick
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import "../theme"
import "../widgets"
import "../services"
import "../rig"

// SIGNAL 信号: the audio as a mirrored bar wave (cava, while something plays), what's playing,
// and where it's going ("SPEAKERS // LIVE"). Idle, the wave lies flat with a faint noise floor.
Panel {
    id: root

    title: "SIGNAL"
    jp: "信号"
    trailing: (Pipewire.defaultAudioSink?.nickname || Pipewire.defaultAudioSink?.description || "speakers").slice(0, 18) + "  //  " + (Radio.playing ? "LIVE" : "IDLE")
    trailingColor: Radio.playing ? Theme.red : Theme.dim
    brackets: true

    readonly property var player: Mpris.players.values.find(p => p.isPlaying) ?? null
    PwObjectTracker { objects: [Pipewire.defaultAudioSink].filter(n => n) }

    // a gentle idle shimmer so the flat line isn't dead
    property real phase: 0
    NumberAnimation on phase { from: 0; to: Math.PI * 2; duration: 4000; loops: Animation.Infinite; running: !Radio.playing && root.visible }

    Item {
        anchors.fill: parent

        Row {
            id: wave
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -8
            spacing: 3
            Repeater {
                model: Radio.count
                Rectangle {
                    required property int index
                    readonly property real v: Radio.active ? (Radio.bars[index] ?? 0) * Radio.gain
                        : 0.03 + 0.02 * Math.sin(root.phase + index * 0.5)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(2, (root.body.width - (Radio.count - 1) * 3) / Radio.count)
                    height: Math.max(2, v * (root.body.height - 50))
                    color: Theme.cyan
                    opacity: Radio.active ? 0.95 : 0.5
                }
            }
        }
        Label {
            anchors.bottom: parent.bottom
            width: parent.width
            elide: Text.ElideRight
            text: root.player ? (root.player.trackArtist ? root.player.trackArtist + "  //  " : "") + (root.player.trackTitle ?? "") : "NO CARRIER"
            color: root.player ? Theme.fg : Theme.dim
        }
    }
    MouseArea { anchors.fill: parent; z: -1; onClicked: RigState.toggleTo("radio") }
}
