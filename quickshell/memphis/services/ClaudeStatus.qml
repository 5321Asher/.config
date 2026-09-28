pragma Singleton

import QtQuick
import Quickshell
import "../theme"
import Quickshell.Io

// Claude Code account / model / usage info from scripts/claude-info.py
Singleton {
    id: root

    property var data: null
    property bool loading: false

    function refresh() {
        if (!proc.running) {
            loading = true;
            proc.running = true;
        }
    }

    // Skip refetching if the data is under a minute old
    function refreshIfStale() {
        if (!data || Date.now() / 1000 - data.fetchedAt > 60)
            refresh();
    }

    function launch() {
        Quickshell.execDetached(["kitty", "--directory", Quickshell.env("HOME"), "claude"]);
    }

    // "claude-opus-5-5" -> "Opus 5.5"
    function prettyModel(id) {
        if (!id)
            return "";
        const parts = id.replace(/^claude-/, "").replace(/-\d{8}$/, "").split("-");
        const name = parts.filter(p => isNaN(p)).map(p => p.charAt(0).toUpperCase() + p.slice(1)).join(" ");
        const ver = parts.filter(p => !isNaN(p)).join(".");
        return (name + " " + ver).trim();
    }

    // When an ISO timestamp is, e.g. "in 2h 5m" or "Mon 11:00"
    function resetsIn(iso) {
        if (!iso)
            return "";
        const t = new Date(iso);
        const mins = Math.max(0, Math.round((t - Date.now()) / 60000));
        if (mins < 60) return "in " + mins + "m";
        if (mins < 24 * 60) return "in " + Math.floor(mins / 60) + "h " + (mins % 60) + "m";
        return Qt.formatDateTime(t, "ddd HH:mm");
    }

    function tokens(n) {
        return n >= 1e6 ? (n / 1e6).toFixed(1) + "M" : n >= 1e3 ? (n / 1e3).toFixed(1) + "k" : String(n);
    }

    Process {
        id: proc
        command: ["python3", Quickshell.shellDir + "/scripts/claude-info.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.data = JSON.parse(text);
                } catch (e) {
                    root.data = { error: "Couldn't read Claude Code info", limits: [], fetchedAt: 0 };
                }
                root.loading = false;
            }
        }
    }
}
