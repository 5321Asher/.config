pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

// Microphone levels for the dictation window (Sound Recorder) and the microphone test in Multimedia
// Properties: while dictating or `testing`, cava reads the default input (pactl get-default-source)
// instead of the speakers. `bars` is 0-1, bass first.
Singleton {
    id: root

    property bool testing: false
    readonly property bool active: testing || Voxtype.recording
    readonly property int count: 24
    property list<real> bars: Array(count).fill(0)

    onActiveChanged: if (!active) bars = Array(count).fill(0)

    Process {
        running: root.active
        // cava only reads its source from the config file: write a copy pointing at the mic
        command: ["sh", "-c", `
            src="$(pactl get-default-source 2>/dev/null)"
            f="\${XDG_RUNTIME_DIR:-/tmp}/grimoire-mic.conf"
            sed -e "s|^source = .*|source = $src|" -e "s|^bars = .*|bars = ${root.count}|" "$1" > "$f"
            exec cava -p "$f"`, "sh", Quickshell.shellDir + "/cava.conf"]
        stdout: SplitParser {
            onRead: line => {
                const parts = line.split(";");
                const out = [];
                for (let i = 0; i < root.count; i++) out.push((parseInt(parts[i]) || 0) / 100);
                root.bars = out;
            }
        }
    }
}
