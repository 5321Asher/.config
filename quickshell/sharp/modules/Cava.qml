pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// One shared cava process; values are 0-1, bass first.
// Captures what's playing by default; set `source` to a PipeWire node name to capture that instead (mic test).
Singleton {
    id: root

    readonly property int bars: 40
    property list<real> values: Array(bars).fill(0)
    property string source: ""
    readonly property string config: Quickshell.shellDir + "/cava.conf"

    onSourceChanged: {
        values = Array(bars).fill(0);
        proc.running = false;
        Qt.callLater(() => proc.running = true);
    }

    Process {
        id: proc

        running: true
        // cava only reads the source from its config, so write a copy with the source swapped in
        command: root.source === "" ? ["cava", "-p", root.config] : ["sh", "-c",
            'f="${XDG_RUNTIME_DIR:-/tmp}/qs-cava-test.conf"; sed "s|^source = .*|source = $2|" "$1" > "$f" && exec cava -p "$f"',
            "sh", root.config, root.source]

        stdout: SplitParser {
            onRead: line => {
                const parts = line.split(";");
                const out = [];
                for (let i = 0; i < root.bars; i++)
                    out.push((parseInt(parts[i]) || 0) / 100);
                root.values = out;
            }
        }
    }
}
