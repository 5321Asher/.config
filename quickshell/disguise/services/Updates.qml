pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Vulnerability watch and pending updates (the same file is copied into each setup's shell;
// Netrunner has this logic inside its Status.qml):
//   vulns       packages with known CVEs (arch-audit), worst first: { name, severity, type, cves, fix }
//   bySeverity  { Critical, High, Medium, Low } counts; high = Critical + High
//   pending     updates waiting (checkupdates, from pacman-contrib)
// Checked every 30 minutes and on sweep(); update() opens a terminal running the upgrade.
//   qs ipc call updates sweep | report
Singleton {
    id: root

    property var vulns: []
    property var bySeverity: ({ Critical: 0, High: 0, Medium: 0, Low: 0 })
    readonly property int count: vulns.length
    readonly property int high: (bySeverity.Critical ?? 0) + (bySeverity.High ?? 0)
    readonly property int fixable: vulns.filter(v => v.fix).length
    property bool auditAvailable: true
    property date auditAt
    readonly property bool auditing: audit.running

    property int pending: 0
    property bool pendingAvailable: true
    readonly property bool checking: updates.running

    function sweep() {
        if (!audit.running) audit.running = true;
        if (!updates.running) updates.running = true;
    }
    function update() {
        Quickshell.execDetached(["kitty", "--class", "system-update", "-e", "sh", "-c",
            "sudo pacman -Syu; echo; read -p 'Done. Press Enter to close. ' _"]);
    }
    // "12 min ago"
    function ago() {
        if (!auditAt || isNaN(auditAt.getTime())) return "";
        const m = Math.floor((Date.now() - auditAt.getTime()) / 60000);
        return m < 1 ? "just now" : m < 60 ? m + " min ago" : Math.floor(m / 60) + " h ago";
    }

    Process {
        id: audit
        running: true
        // every affected package, then (after a --) the ones an update already fixes
        command: ["sh", "-c", "command -v arch-audit >/dev/null || { echo MISSING; exit 0; }; arch-audit -f '%n|%s|%t|%c' 2>/dev/null; echo --; arch-audit -u -f '%n' 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "MISSING") { root.auditAvailable = false; return; }
                root.auditAvailable = true;
                const rank = { Critical: 0, High: 1, Medium: 2, Low: 3 };
                const by = { Critical: 0, High: 0, Medium: 0, Low: 0 };
                const parts = text.split("\n--\n");
                const fixed = new Set((parts[1] ?? "").split("\n").map(l => l.trim()).filter(l => l));
                const out = [];
                for (const line of (parts[0] ?? "").split("\n")) {
                    const p = line.split("|");
                    if (p.length < 4) continue;
                    const w = (p[1] || "Low").split(" ")[0];          // "High risk" -> "High"
                    const sev = w.charAt(0).toUpperCase() + w.slice(1).toLowerCase();
                    by[sev] = (by[sev] ?? 0) + 1;
                    out.push({ name: p[0], severity: sev, type: p[2], cves: p[3].split(",").filter(c => c.trim()).length, fix: fixed.has(p[0]) });
                }
                out.sort((a, b) => (rank[a.severity] ?? 9) - (rank[b.severity] ?? 9) || b.cves - a.cves);
                root.vulns = out;
                root.bySeverity = by;
                root.auditAt = new Date();
            }
        }
    }
    Process {
        id: updates
        running: true
        command: ["sh", "-c", "command -v checkupdates >/dev/null || { echo MISSING; exit 0; }; checkupdates 2>/dev/null | wc -l"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "MISSING") { root.pendingAvailable = false; return; }
                root.pendingAvailable = true;
                root.pending = parseInt(text) || 0;
            }
        }
    }
    Timer { running: true; repeat: true; interval: 30 * 60000; onTriggered: root.sweep() }

    IpcHandler {
        target: "updates"
        function sweep(): void { root.sweep(); }
        function report(): string { return `vulns=${root.count} high=${root.high} fixable=${root.fixable} pending=${root.pending}`; }
    }
}
