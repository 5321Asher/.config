pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The netrunner's view of the machine, all of it real, in the references' words:
//   VULN     packages with known CVEs (arch-audit): count, by severity, the worst few
//   PKG      updates waiting (checkupdates, pacman-contrib)
//   SHIELD   the firewall that's up (ufw, nftables, firewalld), or NONE
//   FAILED   failed systemd units (system + user)
//   ICE      the summary: NOMINAL (shield up, nothing failed), EXPOSED (no firewall), BREACHED (units failed)
//   PING     round trip to 1.1.1.1; SSH on/off; SESSION = how many times this shell has started
//   PROFILE  the colour profile's name; UPLINK = the host name
// Slow things (arch-audit, checkupdates) run every 30 min; the rest every minute.
Singleton {
    id: root

    property int vulnCount: 0
    property var vulnBySeverity: ({ Critical: 0, High: 0, Medium: 0, Low: 0 })
    property var vulns: []              // [{ name, severity, type, cves }], worst first
    property bool auditAvailable: true
    property date auditAt

    property int pkgPending: 0
    property bool pkgAvailable: true

    property string shield: ""          // "UFW" / "NFTABLES" / "FIREWALLD" / ""
    property int failedUnits: 0
    property int ping: -1               // ms, -1 = no reply
    property bool ssh: false
    property int session: 0
    property string host: ""
    property string profile: ""
    property string kernel: ""

    readonly property string ice: failedUnits > 0 ? "BREACHED" : shield === "" ? "EXPOSED" : "NOMINAL"
    readonly property int vulnHigh: (vulnBySeverity.Critical ?? 0) + (vulnBySeverity.High ?? 0)

    function refresh() { fast.running = true; }
    function sweep() { if (!audit.running) audit.running = true; if (!updates.running) updates.running = true; }

    // ---------------------------------------------------------------- every minute
    Process {
        id: fast
        running: true
        command: ["sh", "-c", `
            for s in ufw nftables firewalld; do systemctl is-active --quiet $s 2>/dev/null && { echo "shield=$s"; break; }; done
            echo "failed=$(( $(systemctl --failed --no-legend 2>/dev/null | wc -l) + $(systemctl --user --failed --no-legend 2>/dev/null | wc -l) ))"
            echo "ping=$(ping -c1 -W1 1.1.1.1 2>/dev/null | sed -n 's/.*time=\\([0-9.]*\\).*/\\1/p')"
            systemctl is-active --quiet sshd 2>/dev/null && echo ssh=1 || echo ssh=0
            echo "host=$(uname -n)"
            echo "kernel=$(uname -r)"
            echo "profile=$(python3 -c 'import json,os;s=json.load(open(os.path.expanduser("~/.local/state/theme/state.json")));print(s["setups"][s["setup"]]["current"])' 2>/dev/null)"`]
        stdout: StdioCollector {
            onStreamFinished: {
                let shield = "";
                for (const line of text.split("\n")) {
                    const i = line.indexOf("=");
                    if (i < 0) continue;
                    const k = line.slice(0, i), v = line.slice(i + 1).trim();
                    if (k === "shield") shield = v.toUpperCase();
                    else if (k === "failed") root.failedUnits = parseInt(v) || 0;
                    else if (k === "ping") root.ping = v ? Math.round(parseFloat(v)) : -1;
                    else if (k === "ssh") root.ssh = v === "1";
                    else if (k === "host") root.host = v;
                    else if (k === "kernel") root.kernel = v;
                    else if (k === "profile") root.profile = v.replace(/-/g, " ");
                }
                root.shield = shield;
            }
        }
    }
    Timer { running: true; repeat: true; interval: 60000; onTriggered: fast.running = true }

    // ---------------------------------------------------------------- every 30 minutes
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
                const out = [];
                const [all, fixable] = text.split("\n--\n");
                const fixed = new Set((fixable ?? "").split("\n").map(l => l.trim()).filter(l => l));
                for (const line of all.split("\n")) {
                    const p = line.split("|");
                    if (p.length < 4) continue;
                    const w = (p[1] || "Low").split(" ")[0];          // "High risk" -> "High"
                    const sev = w.charAt(0).toUpperCase() + w.slice(1).toLowerCase();
                    by[sev] = (by[sev] ?? 0) + 1;
                    out.push({ name: p[0], severity: sev, type: p[2].toLowerCase(), cves: p[3].split(",").filter(c => c).length, fix: fixed.has(p[0]) });
                }
                out.sort((a, b) => (rank[a.severity] ?? 9) - (rank[b.severity] ?? 9) || b.cves - a.cves);
                root.vulns = out;
                root.vulnBySeverity = by;
                root.vulnCount = out.length;
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
                if (text.trim() === "MISSING") { root.pkgAvailable = false; return; }
                root.pkgAvailable = true;
                root.pkgPending = parseInt(text) || 0;
            }
        }
    }
    Timer { running: true; repeat: true; interval: 30 * 60000; onTriggered: root.sweep() }

    // ---------------------------------------------------------------- session counter
    FileView {
        id: sessionFile
        path: Quickshell.statePath("session")
        printErrors: false
        blockLoading: true
    }
    Component.onCompleted: {
        root.session = (parseInt(sessionFile.text()) || 0) + 1;
        sessionFile.setText(String(root.session));
    }

    // a cache for things outside the shell (fastfetch's greeting in the terminal):
    // ~/.cache/netrunner/status.json
    FileView { id: cache; path: Quickshell.env("HOME") + "/.cache/netrunner/status.json"; printErrors: false }
    function writeCache() {
        cache.setText(JSON.stringify({
            ice: ice, shield: shield || "NONE", failed: failedUnits, vulns: vulnCount, high: vulnHigh,
            fixable: vulns.filter(v => v.fix).length, pkg: pkgPending, session: session, profile: profile,
            audit: auditAvailable, updates: pkgAvailable,
        }) + "\n");
    }
    Timer { id: cacheLater; interval: 500; onTriggered: root.writeCache() }
    onIceChanged: cacheLater.restart()
    onVulnCountChanged: cacheLater.restart()
    onPkgPendingChanged: cacheLater.restart()
    onSessionChanged: cacheLater.restart()
    onProfileChanged: cacheLater.restart()
    onAuditAvailableChanged: cacheLater.restart()
    onPkgAvailableChanged: cacheLater.restart()
    onFailedUnitsChanged: cacheLater.restart()
    onShieldChanged: cacheLater.restart()

    IpcHandler {
        target: "status"
        function sweep(): void { root.sweep(); root.refresh(); }
        function report(): string {
            return `ice=${root.ice} shield=${root.shield} failed=${root.failedUnits} vuln=${root.vulnCount} pkg=${root.pkgPending} ping=${root.ping} session=${root.session}`;
        }
    }
}
