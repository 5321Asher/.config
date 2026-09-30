pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Apps and windows: the installed apps (desktop entries), what's pinned to Start and to the
// taskbar (kept in ~/.local/state/disguise/pins.json), the files you opened lately, and the
// windows grouped by app the way the taskbar shows them.
Singleton {
    id: root

    readonly property var all: DesktopEntries.applications.values.filter(a => !a.noDisplay && a.name && !hidden.test(a.name))
        .sort((a, b) => nameOf(a).localeCompare(nameOf(b), undefined, { sensitivity: "base" }))

    // Windows' names for what's behind them (Start, Search, the taskbar's tooltips and jump lists),
    // and the words a Windows user would search for them by
    readonly property var winNames: ({
        "thunar": "File Explorer", "org.gnome.Nautilus": "File Explorer", "org.kde.dolphin": "File Explorer",
        "kitty": "Terminal", "btop": "Task Manager", "org.gnome.TextEditor": "Notepad", "mousepad": "Notepad",
        "org.gnome.Calculator": "Calculator", "gnome-calculator": "Calculator", "org.gnome.Loupe": "Photos",
    })
    readonly property var winWords: ({
        "thunar": "explorer files folders this pc", "kitty": "powershell cmd command prompt windows terminal wt console",
        "btop": "task manager processes performance",
    })
    function nameOf(e) { return e ? (winNames[e.id] ?? e.name) : ""; }
    // Linux plumbing Windows doesn't have: kept out of Start's list and Search
    readonly property var hidden: /^(avahi|about xfce|bulk rename|thunar preferences|qdbus|qv4l2|qvidcap|xgps|xgpsspeed|hardware locality|lstopo|cmake|qt [0-9]|assistant|designer|linguist)/i

    function entry(id) {
        if (!id) return null;
        return DesktopEntries.byId(id) ?? DesktopEntries.heuristicLookup(id) ?? null;
    }
    function launch(e) {
        if (!e) return;
        e.execute();
        // the most-used list: Start's "Top apps" in Search
        const u = Object.assign({}, usage);
        u[e.id] = (u[e.id] ?? 0) + 1;
        usage = u;
        save();
    }

    // ---------------------------------------------------------------- pins
    readonly property var defaultTaskbar: ["thunar", "brave-origin-nightly", "kitty", "obsidian"]
    readonly property var defaultStart: ["brave-origin-nightly", "kitty", "thunar", "obsidian", "dev.zed.Zed", "webapp-claude",
        "webapp-gmail", "webapp-youtube", "webapp-discord", "webapp-github", "webapp-deezer", "steam",
        "notepadqq", "org.gnome.gThumb", "org.qbittorrent.qBittorrent", "org.openrgb.OpenRGB", "btop", "virtualbox"]
    // not worth a tile when Start tops itself up
    readonly property var fillerSkip: /avahi|about|bulk rename|cmake|qt |designer|linguist|assistant|qdbus|qv4l2|qvidcap|xgps|lstopo|zenity|seahorse|pinentry|polkit|xwayland|settings|restore|configure|url handler|gcr/i
    property var taskbarPins: defaultTaskbar
    property var startPins: defaultStart
    property var usage: ({})
    // (`all` is read so these re-resolve once the desktop entries have loaded)
    readonly property var taskbarEntries: all.length >= 0 ? taskbarPins.map(entry).filter(e => e) : []
    readonly property var startEntries: {
        const pinned = all.length >= 0 ? startPins.map(entry).filter(e => e) : [];
        // Windows fills Start with apps even before you pin any: top it up from what's installed
        const seen = new Set(pinned.map(e => e.id));
        for (const a of all) { if (pinned.length >= 18) break; if (!seen.has(a.id) && !fillerSkip.test(a.name + " " + a.id)) { pinned.push(a); seen.add(a.id); } }
        return pinned;
    }
    function isPinned(list, e) { return !!e && (list === "taskbar" ? taskbarPins : startPins).includes(e.id); }
    function togglePin(list, e) {
        if (!e) return;
        const cur = list === "taskbar" ? taskbarPins : startPins;
        const next = cur.includes(e.id) ? cur.filter(x => x !== e.id) : cur.concat([e.id]);
        if (list === "taskbar") taskbarPins = next; else startPins = next;
        save();
    }
    function movePin(list, e, to) {
        const cur = (list === "taskbar" ? taskbarPins : startPins).filter(x => x !== e.id);
        cur.splice(Math.max(0, Math.min(to, cur.length)), 0, e.id);
        if (list === "taskbar") taskbarPins = cur; else startPins = cur;
        save();
    }

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/disguise"
    FileView {
        id: pinsFile
        path: root.stateDir + "/pins.json"
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                if (Array.isArray(d.taskbar)) root.taskbarPins = d.taskbar;
                if (Array.isArray(d.start)) root.startPins = d.start;
                if (d.usage) root.usage = d.usage;
            } catch (e) {}
        }
    }
    function save() {
        mkdir.running = true;
        pinsFile.setText(JSON.stringify({ taskbar: taskbarPins, start: startPins, usage: usage }, null, 1));
    }
    Process { id: mkdir; command: ["mkdir", "-p", root.stateDir] }

    // ---------------------------------------------------------------- recent files (Recommended)
    property var recent: []
    FileView {
        path: Quickshell.env("HOME") + "/.local/share/recently-used.xbel"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const out = [];
            const re = /<bookmark href="([^"]+)"[^>]*modified="([^"]+)"[\s\S]*?mime-type type="([^"]+)"/g;
            let m;
            while ((m = re.exec(text())) !== null) out.push({ href: m[1], modified: m[2], mime: m[3] });
            out.sort((a, b) => b.modified.localeCompare(a.modified));
            root.recent = out.filter(r => r.href.startsWith("file://")).slice(0, 12).map(r => {
                const path = decodeURIComponent(r.href.slice(7));
                return { path: path, name: path.split("/").pop(), mime: r.mime, when: new Date(r.modified) };
            });
        }
    }
    function mimeIcon(mime) {
        const exact = (mime ?? "").replace("/", "-");
        if (exact && Quickshell.hasThemeIcon(exact)) return exact;
        const major = (mime ?? "").split("/")[0];
        return ({ image: "image-x-generic", audio: "audio-x-generic", video: "video-x-generic", text: "text-x-generic" })[major] ?? "text-x-generic";
    }
    function ago(d) {
        const s = (Date.now() - d.getTime()) / 1000;
        if (s < 3600) return Math.max(1, Math.round(s / 60)) + "m ago";
        if (s < 86400) return Math.round(s / 3600) + "h ago";
        if (s < 86400 * 2) return "Yesterday at " + Qt.formatTime(d, "h:mm AP");
        return Qt.formatDate(d, "MMM d");
    }
    function open(path) { Quickshell.execDetached(["xdg-open", path]); }

    // ---------------------------------------------------------------- search
    // A simple Windows-like ranking: name starts with > a word starts with > contains > keywords
    function score(e, q) {
        const n = nameOf(e).toLowerCase();
        if (n === q) return 100;
        if (n.startsWith(q)) return 80;
        if (n.split(/[\s\-_.]+/).some(w => w.startsWith(q))) return 60;
        if (n.includes(q)) return 40;
        const extra = [e.name, winWords[e.id] ?? "", e.genericName ?? "", e.comment ?? "", (e.keywords ?? []).join(" "), e.id].join(" ").toLowerCase();
        if (extra.includes(q)) return 20;
        return 0;
    }
    function find(q) {
        q = q.trim().toLowerCase();
        if (!q) return [];
        return all.map(e => ({ e: e, s: score(e, q) + Math.min(10, usage[e.id] ?? 0) })).filter(x => x.s > 10)
            .sort((a, b) => b.s - a.s).map(x => x.e);
    }
    readonly property var topApps: {
        const ids = Object.keys(usage).sort((a, b) => usage[b] - usage[a]);
        const out = all.length >= 0 ? ids.map(entry).filter(e => e) : [];
        for (const e of taskbarEntries) if (!out.includes(e)) out.push(e);
        return out.slice(0, 6);
    }

    // ---------------------------------------------------------------- windows
    readonly property string minimized: "special:minimized"
    function appId(t) { return t?.wayland?.appId || t?.lastIpcObject?.class || ""; }
    function entryFor(t) { return entry(appId(t)); }
    // windows with no desktop entry that stand in for a Windows app (Satty is Snipping Tool)
    readonly property var winIcons: ({ "com.gabm.satty": "ksnip" })
    function iconFor(t) { return winIcons[appId(t)] ?? (entryFor(t)?.icon || appId(t) || "application-x-executable"); }
    function addr(t) { return t.address.startsWith("0x") ? t.address : "0x" + t.address; }
    function isMin(t) { return t.workspace?.name === minimized; }
    // focus it and bring it in front (windows float, and focusing one doesn't raise it by itself)
    function focusWin(t) {
        Hyprland.dispatch(`hl.dsp.focus({ window = "address:${addr(t)}" })`);
        Hyprland.dispatch(`hl.dsp.window.alter_zorder({ mode = "top", window = "address:${addr(t)}" })`);
    }
    function minimize(t) {
        Hyprland.dispatch(`hl.dsp.window.move({ workspace = "${minimized}", window = "address:${addr(t)}", follow = false })`);
    }
    function restore(t, ws) {
        Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${ws ?? Hyprland.focusedWorkspace?.id ?? 1}, window = "address:${addr(t)}", follow = false })`);
        focusLater.t = t;
        focusLater.restart();
    }
    Timer { id: focusLater; property var t; interval: 60; onTriggered: root.focusWin(t) }
    function closeWin(t) { onWindow(t, "hl.dsp.window.close()"); }
    // run a dispatcher on a window: focus it first, then act on "the active window"
    function onWindow(t, lua) { focusWin(t); actLater.lua = lua; actLater.restart(); }
    Timer { id: actLater; property string lua; interval: 60; onTriggered: Hyprland.dispatch(lua) }
}
