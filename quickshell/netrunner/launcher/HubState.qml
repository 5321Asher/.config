pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../services"
import "../rig"
import "../utilities"
import "../dash"

// The hub: Netrunner's root menu (SUPER + Space, or the red tag), drawn as a breach protocol
// (launcher/Breach.qml). Its entries are the shared menus (~/.config/elephant/menus, the ones
// Walker shows: Apps, Trigger, Style, Power…) plus Netrunner's own: the rig, the deck and the
// subnet map. A submenu is a deeper subnet. qs ipc call hub toggle | open | close
Singleton {
    id: root

    property bool open: false
    // [{ title, items, loading }]; an item is { text, sub, glyph, run: fn } or { …, open: loader }
    property var stack: []
    property int seed: 1                    // reshuffles the code matrix per subnet
    readonly property var level: stack[stack.length - 1] ?? null
    readonly property string path: ["ROOT"].concat(stack.slice(1).map(l => l.title.toUpperCase())).join("  //  ")

    function toggle() { open ? close() : show(); }
    function show() {
        stack = [];
        push("Root", topLevel);
        open = true;
    }
    function close() { open = false; }

    function push(title, loader) {
        const depth = stack.length;
        stack = stack.concat([{ title: title, items: [], loading: true }]);
        seed = (seed * 7 + 3) % 9973;
        loader(items => {
            if (stack.length <= depth || !stack[depth].loading) return;     // backed out meanwhile
            const copy = stack.slice();
            copy[depth] = Object.assign({}, copy[depth], { items: items, loading: false });
            stack = copy;
        });
    }
    function back() {
        if (stack.length <= 1) { close(); return; }
        stack = stack.slice(0, -1);
        seed = (seed * 7 + 3) % 9973;
    }

    // Elephant items -> breach entries
    function entries(list) {
        return list.map(it => {
            const isMenu = ((it.actions ?? [])[0] ?? "") === "menus:open";
            const e = { text: (it.text ?? "").replace(/^[●\s]+/, ""), sub: it.subtext ?? "", glyph: it.icon ?? "",
                        on: (it.text ?? "").startsWith("●") };
            if (isMenu) e.open = done => Elephant.query(it.identifier.split("::")[0], l => done(root.entries(l)));
            else e.run = () => Elephant.activate(it);
            return e;
        });
    }

    function topLevel(done) {
        Elephant.query("menus:start", list => {
            const shared = root.entries(list).map(e => {
                if (e.text.toLowerCase() === "apps") { delete e.open; e.run = () => ExecState.open = true; }   // our own launcher
                return e;
            });
            done(shared.concat([
                { text: "Rig", sub: "switches // levels // system", glyph: "\u{f0493}", run: () => RigState.show("helm") },
                { text: "Deck", sub: "sys.diag // queue // vuln watch", glyph: "\u{f07c0}", run: () => DeckState.toggle() },
                { text: "Subnet map", sub: "every workspace at once", glyph: "\u{f0570}", run: () => OverviewState.open = true },
            ]));
        });
    }

    IpcHandler {
        target: "hub"
        function toggle(): void { root.toggle(); }
        function open(): void { if (!root.open) root.show(); }
        function close(): void { root.close(); }
    }
}
