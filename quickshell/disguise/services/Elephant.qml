pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The shared menus (~/.config/elephant/menus: Trigger, Style, Power…), read and run exactly as
// Walker does, so the Start menu offers every function the other setups' launchers do:
//   query("menus:start", items => …)   elephant query --json 'menus:start;;500;false'
//   activate(item)                     elephant activate 'provider;identifier;action;;'
// and toItems() turns them into Start-menu items (submenus load when opened).
Singleton {
    id: root

    function query(provider, done) {
        const p = runner.createObject(root, { provider: provider, done: done });
        p.running = true;
    }

    function activate(it) {
        const action = (it.actions ?? [])[0] ?? "";
        Quickshell.execDetached(["elephant", "activate", `${it.provider};${it.identifier};${action};;`]);
    }

    // Windows 98-ish icons for the shared menus' entries (they carry Nerd Font glyphs, not theme icons)
    readonly property var icons: [
        [/screenshot region|region/i, "applets-screenshooter"], [/screenshot|screen$/i, "applets-screenshooter"],
        [/copy text|ocr/i, "edit-copy"], [/record/i, "media-record"], [/capture/i, "camera-photo"],
        [/cheat|keybind|shortcut/i, "preferences-desktop-keyboard"], [/web app/i, "internet-web-browser"],
        [/^setup/i, "preferences-desktop"], [/theme tools|manager/i, "preferences-desktop-theme"],
        [/theme|colour/i, "preferences-desktop-theme"], [/wallpaper/i, "preferences-desktop-wallpaper"],
        [/config|kitty|hyprland|walker|quickshell|fastfetch|setup file|settings/i, "text-x-generic"],
        [/lock/i, "system-lock-screen"], [/suspend|sleep/i, "system-suspend"], [/log ?out/i, "system-log-out"],
        [/reboot|restart/i, "system-reboot"], [/shut ?down|power ?off/i, "system-shutdown"],
        [/folder/i, "folder"], [/random|next/i, "view-refresh"], [/edit/i, "accessories-text-editor"],
        [/remove|delete/i, "edit-delete"], [/new|add/i, "document-new"],
    ]
    function iconFor(it, isMenu) {
        const icon = it.icon ?? "";
        if (icon.length > 2 && (icon.startsWith("/") || Quickshell.hasThemeIcon(icon))) return icon;
        for (const [re, name] of icons) if (re.test(it.text ?? "")) return name;
        return isMenu ? "folder" : "application-x-executable";
    }

    // Elephant items -> menu items. `special(it)` may return a replacement item (or null to drop it).
    function toItems(list, special) {
        const out = [];
        for (const it of list) {
            if (special) {
                const s = special(it);
                if (s === null) continue;
                if (s !== undefined) { out.push(s); continue; }
            }
            const isMenu = ((it.actions ?? [])[0] ?? "") === "menus:open";
            const raw = it.text ?? "";
            const item = {
                text: raw.replace(/^[●\s]+/, ""),
                icon: iconFor(it, isMenu),
                check: raw.startsWith("●"),
            };
            if (isMenu) item.sub = done => root.query(it.identifier.split("::")[0], l => done(root.toItems(l)));
            else item.run = () => root.activate(it);
            out.push(item);
        }
        return out;
    }

    Component {
        id: runner
        Process {
            id: proc
            property string provider
            property var done
            property bool finished: false
            command: ["elephant", "query", "--json", `${provider};;500;false`]
            stdout: StdioCollector {
                onStreamFinished: {
                    const out = [];
                    for (const line of text.split("\n")) {
                        if (!line.trim()) continue;
                        try { out.push(JSON.parse(line).item); } catch (e) {}
                    }
                    proc.finish(out);
                }
            }
            onExited: code => { if (code !== 0) finish([]); }
            function finish(out) {
                if (finished) return;
                finished = true;
                try { done(out); } catch (e) { console.warn("elephant:", e); }
                destroy();
            }
        }
    }
}
