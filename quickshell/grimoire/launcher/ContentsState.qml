pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../menus"
import "../services"
import "../codex"
import "../utilities"

// The table of contents: Grimoire's root menu (SUPER + Space, or the clasp in the corner), a
// parchment contents page dropped from the clasp. Its entries are the shared menus
// (~/.config/elephant/menus, the ones Walker shows: Apps, Trigger, Style, Power…) with their
// subtexts, then Grimoire's own: the codex, the whole book (overview) and the summoning circle.
//   qs ipc call contents toggle | open | close
Singleton {
    id: root

    function screen() { return Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]; }

    function toggle() {
        if (Menus.open && Menus.kind === "contents") { Menus.close(); return; }
        Menus.show(screen().name, "contents", topLevel, 10, 56, { big: true });
    }

    function topLevel(done) {
        Elephant.query("menus:start", list => {
            const shared = list.map(it => {
                const t = (it.text ?? "").toLowerCase();
                const isMenu = ((it.actions ?? [])[0] ?? "") === "menus:open";
                const item = { text: it.text, sub_text: it.subtext ?? "" };
                if (t === "apps") item.run = () => CircleState.open = true;       // the summoning circle
                else if (isMenu) item.sub = d => Elephant.query(it.identifier.split("::")[0], l => d(Elephant.toItems(l)));
                else item.run = () => Elephant.activate(it);
                return item;
            });
            done(shared.concat([
                { sep: true },
                { text: "The Codex", sub_text: "switches, levels, letters, the almanac…", run: () => CodexState.show("helm") },
                { text: "The Whole Book", sub_text: "every chapter laid open", run: () => OverviewState.open = true },
            ]));
        });
    }

    IpcHandler {
        target: "contents"
        function toggle(): void { root.toggle(); }
        function open(): void { if (!(Menus.open && Menus.kind === "contents")) root.toggle(); }
        function close(): void { Menus.close(); }
    }
}
