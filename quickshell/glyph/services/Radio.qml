pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../theme"

// The radio receiver behind the horizon waveform: while any media player is playing, cava runs
// (cava.conf, raw output) and `bars` holds its levels, 0-1, bass first. When playback stops cava
// is stopped and `gain` eases to 0, so the line settles back flat instead of snapping.
Singleton {
    id: root

    readonly property bool playing: Mpris.players.values.some(p => p.isPlaying)
    readonly property int count: 36
    property list<real> bars: Array(count).fill(0)
    property real level: 0                  // overall loudness, 0-1, for the glow

    property real gain: playing ? 1 : 0
    Behavior on gain { NumberAnimation { duration: Theme.slow * 2; easing.type: Theme.easing } }
    readonly property bool active: gain > 0.001

    Process {
        id: proc
        running: root.playing
        command: ["cava", "-p", Quickshell.shellDir + "/cava.conf"]
        stdout: SplitParser {
            onRead: line => {
                const parts = line.split(";");
                const out = [];
                let sum = 0;
                for (let i = 0; i < root.count; i++) {
                    const v = (parseInt(parts[i]) || 0) / 100;
                    out.push(v);
                    sum += v;
                }
                root.bars = out;
                root.level = sum / root.count;
            }
        }
    }
}
