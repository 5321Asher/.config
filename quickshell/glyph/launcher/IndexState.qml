pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"
import "../services"
import "../utilities"
import "../quick"
import "../power"
import "../prefs"
import "../deck"

// The index: Glyph's root menu (SUPER + Space, or the mark at the top of the rail), drawn by
// launcher/Index.qml as a rotary dial of dot-matrix words. Its entries are the shared menus
// (~/.config/elephant/menus: Apps, Trigger, Style, Power…, the ones Walker shows) plus Glyph's own
// panels. A submenu is a level deeper (→ / Enter), ← goes back. qs ipc call index toggle | open | close
Singleton {
    id: root

    property bool open: false
    // [{ title, items, loading, sel }]; an item is { text, sub, glyph, on, run: fn } or { …, open: loader }
    property var stack: []
    readonly property var level: stack[stack.length - 1] ?? null
    readonly property var path: stack.map(l => l.title)

    function toggle() { open ? close() : show(); }
    function show() {
        stack = [];
        push("index", topLevel);
        open = true;
    }
    function close() { open = false; }

    function push(title, loader) {
        const depth = stack.length;
        stack = stack.concat([{ title: title, items: [], loading: true, sel: 0 }]);
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
    }
    function select(i) {
        if (!level || level.sel === i) return;
        const copy = stack.slice();
        copy[copy.length - 1] = Object.assign({}, level, { sel: i });
        stack = copy;
    }
    // Enter / → on an item: go into its submenu, or close and run it (a moment later, so the
    // index is gone from the screen first: a screenshot shouldn't catch it)
    function enter(i) {
        const it = level?.items?.[i];
        if (!it) return;
        if (it.open) { push(it.text, it.open); return; }
        close();
        later.fn = it.run;
        later.restart();
    }
    Timer { id: later; property var fn; interval: Theme.t + 40; onTriggered: if (fn) fn() }

    // Elephant items -> index entries
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
                const t = e.text.toLowerCase();
                if (t === "apps") { delete e.open; e.run = () => ExecState.open = true; }      // our own launcher
                if (t === "power") { delete e.open; e.run = () => PowerState.show(); }         // our own power screen
                return e;
            });
            done(shared.concat([
                { text: "Quick", sub: "toggles · levels · capture", glyph: "\u{F0493}", run: () => QuickState.open = true },
                { text: "Settings", sub: "network · sound · display · system", glyph: "\u{F08BB}", run: () => PrefsState.show("comms") },
                { text: "Deck", sub: "the dashboard from the bottom", glyph: "\u{F0570}", run: () => DeckState.open = true },
                { text: "Overview", sub: "every workspace at once", glyph: "\u{F0BB0}", run: () => OverviewState.open = true },
            ]));
        });
    }

    IpcHandler {
        target: "index"
        function toggle(): void { root.toggle(); }
        function open(): void { if (!root.open) root.show(); }
        function close(): void { root.close(); }
    }
}
