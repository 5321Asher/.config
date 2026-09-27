pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// OpenRGB via its CLI. Uses a running OpenRGB server if there is one, otherwise talks to the hardware directly.
Singleton {
    id: root

    property bool available: false
    property bool scanned: false
    property bool busy: false
    property string error: ""
    // [{ index, name, type, modes: [..], mode, zones: [..] }]
    property var devices: []
    property var profiles: []
    // Set every device to the theme accent on each theme switch (~/.config/theme/theme)
    property bool followWallpaper: true

    function setFollowWallpaper(on) {
        followWallpaper = on;
        followFile.setText(on ? "on\n" : "off\n");
        if (on)
            Quickshell.execDetached([Quickshell.env("HOME") + "/.config/theme/theme", "openrgb"]);
    }
    // Zone sizes OpenRGB has saved: { deviceName: [{ name, leds, min, max }] }
    property var zones: ({})

    function scan() {
        if (scanner.running)
            return;
        busy = true;
        scanner.running = true;
    }

    function hex(c) {
        return c.toString().replace("#", "").slice(-6).toUpperCase();
    }

    // Mode to use for a plain color: Static if the device has it, else Direct
    function colorMode(dev) {
        return dev.modes.find(m => m.toLowerCase() === "static") ?? dev.modes.find(m => m.toLowerCase() === "direct") ?? dev.modes[0];
    }

    function setAll(color) {
        const args = [];
        for (const d of devices)
            args.push("-d", String(d.index), "-m", colorMode(d), "-c", hex(color));
        run(args);
    }

    function setDevice(dev, mode, color) {
        const args = ["-d", String(dev.index), "-m", mode];
        if (color !== undefined)
            args.push("-c", hex(color));
        run(args);
    }

    // Resizable zones (addressable headers) for a device, with their index in the device
    function resizableZones(dev) {
        return (zones[dev.name] ?? []).map((z, i) => Object.assign({ index: i }, z)).filter(z => z.max > z.min);
    }

    // Set an addressable header's LED count. The CLI needs a mode alongside it, so pass the
    // device's current one without a color, leaving the existing lighting alone.
    function setZoneSize(dev, zoneIndex, leds) {
        run(["-d", String(dev.index), "-z", String(zoneIndex), "-sz", String(leds), "-m", dev.mode || colorMode(dev)]);
    }

    function loadProfile(name) {
        run(["-p", name]);
    }

    function saveProfile(name) {
        run(["-sp", name]);
    }

    function run(args) {
        busy = true;
        error = "";
        action.command = ["openrgb"].concat(args);
        action.running = true;
    }

    // Split an OpenRGB list line: words, 'quoted words' and [current] entries
    function tokens(s) {
        const out = [];
        const re = /\[([^\]]+)\]|'([^']*)'|(\S+)/g;
        let m;
        while ((m = re.exec(s)) !== null)
            out.push({ text: m[1] ?? m[2] ?? m[3], current: m[1] !== undefined });
        return out;
    }

    Process {
        id: scanner
        command: ["sh", "-c", "command -v openrgb >/dev/null || { echo MISSING; exit; }; openrgb -ld 2>/dev/null | grep -v '^\\['; echo '@@PROFILES'; openrgb -lp 2>/dev/null | grep -v '^\\['"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.busy = false;
                root.scanned = true;
                if (text.trim() === "MISSING") {
                    root.available = false;
                    return;
                }
                root.available = true;
                const [devText, profText] = text.split("@@PROFILES");
                const devs = [];
                let cur = null;
                for (const line of devText.split("\n")) {
                    const head = /^(\d+): (.+)$/.exec(line);
                    if (head) {
                        cur = { index: +head[1], name: head[2].trim(), type: "", modes: [], mode: "", zones: [] };
                        devs.push(cur);
                        continue;
                    }
                    if (!cur)
                        continue;
                    const kv = /^\s+(\w+):\s*(.*)$/.exec(line);
                    if (!kv)
                        continue;
                    if (kv[1] === "Type")
                        cur.type = kv[2].trim();
                    else if (kv[1] === "Modes") {
                        const t = root.tokens(kv[2]);
                        cur.modes = t.map(x => x.text);
                        cur.mode = t.find(x => x.current)?.text ?? "";
                    } else if (kv[1] === "Zones")
                        cur.zones = root.tokens(kv[2]).map(x => x.text);
                }
                root.devices = devs;
                root.profiles = (profText ?? "").split("\n").map(s => s.trim()).filter(s => s);
            }
        }
    }

    FileView {
        id: followFile
        path: Quickshell.shellDir + "/rgb-follow"
        printErrors: false
        onLoaded: root.followWallpaper = text().trim() !== "off"
    }

    // OpenRGB saves zone sizes here whenever they change
    FileView {
        id: sizes
        path: Quickshell.env("HOME") + "/.config/OpenRGB/Configuration.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const out = {};
                for (const c of JSON.parse(text()).controllers ?? [])
                    out[c.name] = (c.zones ?? []).map(z => ({ name: z.name, leds: z.leds_count, min: z.leds_min, max: z.leds_max }));
                root.zones = out;
            } catch (e) {}
        }
    }

    Process {
        id: action
        stderr: StdioCollector { id: actionErr }
        stdout: StdioCollector { id: actionOut }
        onExited: code => {
            root.busy = false;
            if (code !== 0)
                root.error = (actionErr.text + actionOut.text).split("\n").filter(l => l && !l.startsWith("[")).pop() || "OpenRGB command failed";
            // Refresh current modes
            root.scan();
        }
    }
}
