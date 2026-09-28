pragma Singleton

import QtQuick
import Quickshell
import "../theme"
import Quickshell.Io

// Live system stats from scripts/stats.py, plus short histories for charts
Singleton {
    id: root

    readonly property int interval: 2
    // Only sampled while something shows it (the deck's telemetry page)
    property bool active: false
    readonly property int historyLength: 60

    property var data: null
    property var cpuHistory: []
    property var gpuHistory: []
    property var rxHistory: []
    property var txHistory: []

    function push(list, value) {
        const out = list.concat([value]);
        return out.length > historyLength ? out.slice(out.length - historyLength) : out;
    }

    function bytes(n, decimals = 1) {
        const units = ["B", "KB", "MB", "GB", "TB"];
        let i = 0;
        while (n >= 1024 && i < units.length - 1) {
            n /= 1024;
            i++;
        }
        return n.toFixed(i === 0 ? 0 : decimals) + " " + units[i];
    }

    function tempColor(t) {
        return t >= 80 ? Theme.danger : t >= 60 ? Theme.warn : Theme.windowText;
    }

    Process {
        id: proc
        running: root.active
        command: ["python3", Quickshell.shellDir + "/scripts/stats.py", String(root.interval)]

        stdout: SplitParser {
            onRead: line => {
                let d;
                try {
                    d = JSON.parse(line);
                } catch (e) {
                    return;
                }
                root.data = d;
                root.cpuHistory = root.push(root.cpuHistory, d.cpu.usage);
                root.gpuHistory = root.push(root.gpuHistory, d.gpu?.usage ?? 0);
                root.rxHistory = root.push(root.rxHistory, d.net.rx);
                root.txHistory = root.push(root.txHistory, d.net.tx);
            }
        }

        // Restart if the script dies
        onExited: restart.start()
    }

    Timer {
        id: restart
        interval: 5000
        onTriggered: proc.running = root.active
    }
}
