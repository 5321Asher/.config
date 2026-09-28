pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../flyouts"
import "../services"
import "../settings"

// The Start button's right-click menu (Windows + X's "power user" menu), with the shared menus
// (~/.config/elephant/menus: Trigger, Style…) as cascades, and Power as "Shut down or sign out".
//   qs ipc call winx open
Singleton {
    id: root

    function show(screenName, x, y) {
        Elephant.query("menus:start", list => {
            const shared = Elephant.toItems(list, it => {
                const t = (it.text ?? "").toLowerCase();
                return t === "apps" || t === "power" ? null : undefined;
            }).map(i => Object.assign(i, { icon: undefined, glyph: glyphFor(i.text) }));
            const power = list.find(it => (it.text ?? "").toLowerCase() === "power");
            const run = (cmd) => () => Quickshell.execDetached(cmd);
            Flyouts.menu(screenName, [
                { text: "Installed apps", glyph: "", run: () => SettingsApp.open("apps") },
                { text: "Power Options", glyph: "", run: () => SettingsApp.open("power") },
                { text: "System", glyph: "", run: () => SettingsApp.open("about") },
                { text: "Device Manager", glyph: "", run: () => SettingsApp.open("bluetooth") },
                { text: "Network Connections", glyph: "", run: () => SettingsApp.open("network") },
                { text: "Disk Management", glyph: "", run: () => SettingsApp.open("storage") },
                { sep: true },
                { text: "Terminal", glyph: "", run: run(["gtk-launch", "kitty"]) },
                { text: "Task Manager", glyph: "", run: run(["kitty", "--class", "btop", "-e", "btop"]) },
                { text: "Settings", glyph: "", run: () => SettingsApp.open("home") },
                { text: "File Explorer", glyph: "", run: run(["thunar"]) },
                { text: "Search", glyph: "", run: () => Flyouts.show("search", screenName) },
                { sep: true },
            ].concat(shared).concat([
                { sep: true },
                { text: "Shut down or sign out", glyph: "", sub: power ? (done => Elephant.query(power.identifier.split("::")[0], l => done(Elephant.toItems(l)))) : [] },
                { text: "Desktop", glyph: "", run: () => ShowDesktop.toggle(Hyprland.focusedMonitor) },
            ]), x, y, true);
        });
    }
    function glyphFor(t) {
        t = (t ?? "").toLowerCase();
        return t.includes("trigger") ? "" : t.includes("style") ? "" : "";
    }

    IpcHandler {
        target: "winx"
        function open(): void {
            const s = Flyouts.focusedScreen();
            root.show(s.name, 40, s.height - 48 - 12);
        }
    }
}
