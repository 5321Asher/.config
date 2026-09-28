pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../menus"
import "../services"
import "../rig"
import "../utilities"

// The hub: Netrunner's root menu (SUPER + Space, or the red tag), dropped from under the tag as a
// quickhack list. Its entries are the shared menus (~/.config/elephant/menus, the ones Walker
// shows: Apps, Trigger, Style, Power…), numbered, with their subtexts, plus Netrunner's own:
// the rig, the deck and the subnet map. qs ipc call hub toggle
Singleton {
    id: root

    function screen() { return Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]; }

    function toggle() {
        if (Menus.open && Menus.kind === "hub") { Menus.close(); return; }
        Menus.show(screen().name, "hub", topLevel, 0, 48, { big: true });
    }

    function topLevel(done) {
        Elephant.query("menus:start", list => {
            const shared = list.map(it => {
                const t = (it.text ?? "").toLowerCase();
                const isMenu = ((it.actions ?? [])[0] ?? "") === "menus:open";
                const item = { text: it.text, sub_text: it.subtext ?? "" };
                if (t === "apps") item.run = () => ExecState.open = true;         // our own launcher
                else if (isMenu) item.sub = d => Elephant.query(it.identifier.split("::")[0], l => d(Elephant.toItems(l)));
                else item.run = () => Elephant.activate(it);
                return item;
            });
            done(shared.concat([
                { sep: true },
                { text: "Rig", sub_text: "switches // levels // system", run: () => RigState.show("helm") },
                { text: "Deck", sub_text: "sys.diag // queue // vuln watch", run: () => Hyprland.dispatch(`hl.dsp.workspace.toggle_special("deck")`) },
                { text: "Subnet map", sub_text: "every workspace at once", run: () => OverviewState.open = true },
            ]));
        });
    }

    IpcHandler {
        target: "hub"
        function toggle(): void { root.toggle(); }
        function open(): void { if (!(Menus.open && Menus.kind === "hub")) root.toggle(); }
        function close(): void { Menus.close(); }
    }
}
