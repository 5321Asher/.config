pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// External monitor brightness over DDC/CI via ddcutil
Singleton {
    id: root

    property bool available: false
    property bool scanned: false
    property bool scanning: false
    // [{ bus, name, value (0-1) }]
    property var displays: []

    function scan() {
        if (scanning)
            return;
        scanning = true;
        detect.running = true;
    }

    function set(index, value) {
        const d = displays[index];
        if (!d)
            return;
        d.value = value;
        displays = displays.slice();
        pending[d.bus] = Math.round(value * 100);
        writer.restart();
    }

    // Bus -> percent waiting to be written; ddcutil is slow, so writes are batched
    property var pending: ({})

    Timer {
        id: writer
        interval: 250
        onTriggered: {
            for (const bus in root.pending)
                Quickshell.execDetached(["ddcutil", "--bus", bus, "--noverify", "setvcp", "10", String(root.pending[bus])]);
            root.pending = {};
        }
    }

    // Finds displays and reads their current brightness in one pass
    Process {
        id: detect
        command: ["sh", "-c", `
            command -v ddcutil >/dev/null || { echo MISSING; exit; }
            ddcutil detect --terse 2>/dev/null | awk '/I2C bus:/ { sub(".*i2c-", ""); bus=$0 } /Monitor:/ { split($2, m, ":"); print bus "\\t" m[2] }' |
            while IFS="$(printf '\\t')" read -r bus name; do
                v=$(ddcutil --bus "$bus" getvcp 10 --brief 2>/dev/null | awk '{ print $4 "/" $5 }')
                printf '%s\\t%s\\t%s\\n' "$bus" "$name" "$v"
            done`]
        stdout: StdioCollector {
            onStreamFinished: {
                root.scanning = false;
                root.scanned = true;
                if (text.trim() === "MISSING") {
                    root.available = false;
                    return;
                }
                root.available = true;
                root.displays = text.trim().split("\n").filter(l => l).map(l => {
                    const [bus, name, v] = l.split("\t");
                    const [cur, max] = (v || "0/100").split("/").map(Number);
                    return { bus: bus, name: name || "Display", value: max > 0 ? cur / max : 0 };
                });
            }
        }
    }
}
