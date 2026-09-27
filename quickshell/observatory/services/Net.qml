pragma Singleton

import QtQuick
import Quickshell
import "../theme"
import Quickshell.Io

// Wi-Fi (NetworkManager) and Tailscale: state, lists and actions
Singleton {
    id: root

    // --- Wi-Fi ---
    property bool wifiEnabled: false
    property string ssid: ""
    property string wifiDevice: ""
    // [{ ssid, signal, security, secure, inUse, saved (connection name or "") }], strongest first
    property var networks: []
    property bool scanning: false
    property string connecting: ""
    property string wifiError: ""

    // --- Tailscale ---
    property bool tsAvailable: false
    property bool tsRunning: false
    property string tsName: ""
    property string tsIp: ""
    property int tsPeersOnline: 0
    property string tsError: ""
    property string tsBusy: ""
    // Own devices: [{ name, dns, ip, os, online, taildrop }]
    property var tsDevices: []
    // Exit nodes: [{ name, ip, country, countryCode, city, online, mullvad }]
    property var tsExitNodes: []
    property string tsExitNode: ""
    property bool tsAllowLan: false

    function refresh() {
        if (!wifiProc.running)
            wifiProc.running = true;
        if (!tsStatus.running)
            tsStatus.running = true;
    }

    // Split nmcli -t output on unescaped colons
    function splitTerse(line) {
        const out = [];
        let cur = "";
        for (let i = 0; i < line.length; i++) {
            const c = line[i];
            if (c === "\\" && i + 1 < line.length) {
                cur += line[++i];
            } else if (c === ":") {
                out.push(cur);
                cur = "";
            } else {
                cur += c;
            }
        }
        out.push(cur);
        return out;
    }

    function toggleWifi() {
        wifiEnabled = !wifiEnabled;
        Quickshell.execDetached(["nmcli", "radio", "wifi", wifiEnabled ? "on" : "off"]);
    }

    function scan() {
        if (scanning)
            return;
        scanning = true;
        scanProc.running = true;
    }

    function connect(net, password) {
        wifiError = "";
        connecting = net.ssid;
        if (net.saved)
            wifiAction.command = ["nmcli", "connection", "up", "id", net.saved];
        else if (password)
            wifiAction.command = ["nmcli", "device", "wifi", "connect", net.ssid, "password", password];
        else
            wifiAction.command = ["nmcli", "device", "wifi", "connect", net.ssid];
        wifiAction.forgetOnFail = net.saved ? "" : net.ssid;
        wifiAction.running = true;
    }

    function disconnectWifi() {
        if (wifiDevice)
            Quickshell.execDetached(["nmcli", "device", "disconnect", wifiDevice]);
    }

    function forget(net) {
        if (net.saved)
            Quickshell.execDetached(["nmcli", "connection", "delete", "id", net.saved]);
        rescanSoon.restart();
    }

    function toggleTailscale() {
        tsRun(tsRunning ? "Disconnecting" : "Connecting", ["tailscale", tsRunning ? "down" : "up"]);
    }

    function setExitNode(ip) {
        tsRun(ip ? "Switching exit node" : "Turning off exit node", ["tailscale", "set", "--exit-node=" + ip]);
    }

    function setAllowLan(allow) {
        tsRun("Updating", ["tailscale", "set", "--exit-node-allow-lan-access=" + allow]);
    }

    function sendFile(path, device) {
        tsSend.target = device.name;
        tsSend.command = ["tailscale", "file", "cp", path, device.ip + ":"];
        tsSend.running = true;
    }

    function copy(text) {
        Quickshell.execDetached(["wl-copy", text]);
    }

    function tsRun(label, cmd) {
        tsError = "";
        tsBusy = label;
        tsAction.command = cmd;
        tsAction.running = true;
    }

    function tsErrorText(t) {
        t = t.trim();
        if (t.includes("access denied") || t.includes("operator") || t.includes("permission"))
            return "Needs operator: sudo tailscale set --operator=$USER";
        return t.split("\n")[0];
    }

    // --- Wi-Fi processes ---

    Process {
        id: wifiProc
        command: ["sh", "-c", "nmcli -t -f WIFI g; nmcli -t -f ACTIVE,SSID dev wifi list --rescan no | grep '^yes:' | cut -d: -f2-"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                root.wifiEnabled = lines[0] === "enabled";
                root.ssid = (lines[1] ?? "").replace(/\\:/g, ":");
            }
        }
    }

    // Full scan: networks + saved profiles (name -> ssid) + wifi device
    Process {
        id: scanProc
        command: ["sh", "-c", `
            nmcli -t -f DEVICE,TYPE dev | grep ':wifi$' | head -1 | sed 's/^/DEV\\t/'
            nmcli dev wifi rescan 2>/dev/null && sleep 3
            nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID dev wifi list --rescan no | sed 's/^/NET\\t/'
            nmcli -t -f NAME,TYPE connection show | while IFS= read -r l; do
                case "$l" in *:802-11-wireless)
                    n="$(printf '%s' "\${l%:802-11-wireless}" | sed 's/\\\\:/:/g')"
                    printf 'SAVED\\t%s\\t%s\\n' "$n" "$(nmcli -g 802-11-wireless.ssid connection show id "$n")";;
                esac
            done`]
        stdout: StdioCollector {
            onStreamFinished: {
                const saved = {};
                const byName = {};
                for (const line of text.split("\n")) {
                    const [kind, a, b] = line.split("\t");
                    if (kind === "DEV")
                        root.wifiDevice = a.split(":")[0];
                    else if (kind === "SAVED")
                        saved[b] = a;
                }
                for (const line of text.split("\n")) {
                    if (!line.startsWith("NET\t"))
                        continue;
                    const [inUse, signal, security, ssid] = root.splitTerse(line.slice(4));
                    if (!ssid)
                        continue;
                    const net = {
                        ssid: ssid,
                        signal: parseInt(signal) || 0,
                        security: security === "--" ? "" : security,
                        secure: security !== "" && security !== "--",
                        inUse: inUse === "*",
                        saved: saved[ssid] ?? ""
                    };
                    // One entry per SSID: keep the connected or strongest access point
                    const prev = byName[ssid];
                    if (!prev || net.inUse || (!prev.inUse && net.signal > prev.signal))
                        byName[ssid] = net;
                }
                root.networks = Object.values(byName).sort((x, y) => (y.inUse - x.inUse) || (y.signal - x.signal));
                root.scanning = false;
            }
        }
    }

    Process {
        id: wifiAction

        property string forgetOnFail: ""

        stderr: StdioCollector { id: wifiErr }
        onExited: code => {
            if (code !== 0) {
                const t = wifiErr.text.trim();
                root.wifiError = t.includes("Secrets were required") || t.includes("802-11-wireless-security")
                    ? "Wrong password" : (t.split("\n").pop() || "Couldn't connect");
                // A failed first attempt leaves a half-made profile behind
                if (forgetOnFail)
                    Quickshell.execDetached(["nmcli", "connection", "delete", "id", forgetOnFail]);
            }
            root.connecting = "";
            rescanSoon.restart();
        }
    }

    Timer {
        id: rescanSoon
        interval: 800
        onTriggered: {
            root.refresh();
            if (!scanProc.running)
                scanProc.running = true;
        }
    }

    // NetworkManager prints a line on every state change
    Process {
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            onRead: debounce.restart()
        }
    }

    Timer {
        id: debounce
        interval: 500
        onTriggered: root.refresh()
    }

    // --- Tailscale processes ---

    Process {
        id: tsStatus
        command: ["sh", "-c", "tailscale status --json; printf '\\036'; tailscale debug prefs 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [statusText, prefsText] = text.split("\x1e");
                let d;
                try {
                    d = JSON.parse(statusText);
                } catch (e) {
                    root.tsAvailable = false;
                    return;
                }
                root.tsAvailable = true;
                root.tsRunning = d.BackendState === "Running";
                root.tsName = d.Self?.HostName ?? "";
                root.tsIp = d.Self?.TailscaleIPs?.[0] ?? "";

                const peers = Object.values(d.Peer ?? {});
                root.tsPeersOnline = peers.filter(p => p.Online && !p.Location).length;
                root.tsDevices = peers.filter(p => !p.Location).map(p => ({
                    name: p.HostName,
                    dns: (p.DNSName ?? "").replace(/\.$/, ""),
                    ip: p.TailscaleIPs?.[0] ?? "",
                    os: p.OS ?? "",
                    online: !!p.Online,
                    // TaildropTarget 1 = available (others: offline, unsupported, ...)
                    taildrop: p.TaildropTarget === 1
                })).sort((a, b) => (b.online - a.online) || a.name.localeCompare(b.name));
                root.tsExitNodes = peers.filter(p => p.ExitNodeOption).map(p => ({
                    name: p.Location?.City ? p.Location.City : p.HostName,
                    host: p.HostName,
                    ip: p.TailscaleIPs?.[0] ?? "",
                    country: p.Location?.Country ?? "",
                    countryCode: p.Location?.CountryCode ?? "",
                    city: p.Location?.City ?? "",
                    online: !!p.Online,
                    mullvad: !!p.Location
                })).sort((a, b) => a.country.localeCompare(b.country) || a.name.localeCompare(b.name));
                root.tsExitNode = peers.find(p => p.ExitNode)?.TailscaleIPs?.[0] ?? "";

                try {
                    root.tsAllowLan = !!JSON.parse(prefsText).ExitNodeAllowLANAccess;
                } catch (e) {}
            }
        }
    }

    Process {
        id: tsAction
        stderr: StdioCollector { id: tsErr }
        onExited: code => {
            if (code !== 0)
                root.tsError = root.tsErrorText(tsErr.text);
            root.tsBusy = "";
            tsStatus.running = true;
        }
    }

    Process {
        id: tsSend

        property string target

        stderr: StdioCollector { id: sendErr }
        onExited: code => {
            Quickshell.execDetached(["notify-send", "-a", "Taildrop",
                code === 0 ? "Sent to " + target : "Couldn't send to " + target,
                code === 0 ? "" : root.tsErrorText(sendErr.text)]);
        }
    }

    Timer {
        running: true
        repeat: true
        triggeredOnStart: true
        interval: 10000
        onTriggered: root.refresh()
    }
}
