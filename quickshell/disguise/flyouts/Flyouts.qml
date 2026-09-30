pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Which flyout is open, and on which screen. One at a time, like Windows:
//   start     the Start menu                      (SUPER + Space, the Start button)
//   search    Search                             (SUPER + CTRL + Space, the search box)
//   quick     Quick Settings                     (the network / volume / battery button)
//   notif     the notification centre + calendar (the clock)
//   widgets   Widgets                            (the weather at the left of the taskbar)
//   tray      the hidden tray icons              (the ^ chevron)
//   run       Run… (Win + R)
//   emoji     the emoji panel / clipboard history (Win + . / Win + V)
//   menu      a context menu (right-click on the taskbar, a tray app's menu, Start's power button…)
// FlyoutLayer draws them; close() lets the open one slide away first.
Singleton {
    id: root

    property string kind: ""            // what's showing ("" = nothing)
    property string screen: ""
    property bool closing: false
    readonly property bool isOpen: kind !== ""
    property var opts: ({})             // per-flyout extras: { page, text, x, … }

    // each screen's taskbar window: the flyout's focus grab includes it, so the taskbar's buttons still
    // take clicks (and toggle) while a flyout is open
    property var bars: ({})
    function registerBar(screenName, win) { const b = Object.assign({}, bars); b[screenName] = win; bars = b; }

    // A click outside clears the focus grab (closing the flyout). If that click was on the button
    // that opened it, its toggle arrives just after: it mustn't open it again.
    property string lastClosed: ""
    property real closedAt: 0

    // menus: [{ items, x, y, up, sel, from }] in screen coordinates (x, y = the menu's corner)
    property var levels: []

    function focusedScreen() {
        return Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0];
    }

    function show(k, screenName, o) {
        hideTimer.stop();
        closing = false;
        screen = screenName ?? focusedScreen()?.name ?? "";
        opts = o ?? {};
        if (k !== "menu") levels = [];
        kind = k;
    }
    function toggle(k, screenName, o) {
        const s = screenName ?? focusedScreen()?.name ?? "";
        if (kind === k && screen === s) { close(); return; }          // open (or closing): close
        if (lastClosed === k + "@" + s && Date.now() - closedAt < 300) return;
        show(k, s, o);
    }
    function close() {
        if (!isOpen || closing) return;
        lastClosed = kind + "@" + screen;
        closedAt = Date.now();
        closing = true;
        hideTimer.restart();
    }
    Timer {
        id: hideTimer
        interval: 140
        onTriggered: { root.kind = ""; root.closing = false; root.levels = []; }
    }

    // ---------------------------------------------------------------- context menus
    // items: [{ text, glyph, icon, sub (items or fn(done)), run, sep, enabled, check, radio, hint, danger }]
    // Over an open flyout (Start's power button, a tile's right-click) the flyout stays open under
    // the menu; otherwise the menu is the flyout.
    function menu(screenName, items, x, y, up) {
        const s = screenName ?? focusedScreen()?.name ?? "";
        if (!(isOpen && !closing && screen === s && kind !== "menu")) show("menu", s, {});
        levels = [];
        push({ x: x, y: y, up: up ?? true }, items);
    }
    function closeMenu() {
        if (kind === "menu") close();
        else levels = [];
    }
    function push(level, items) {
        const depth = levels.length;
        level.sel = -1;
        level.items = typeof items === "function" ? [] : (items ?? []);
        level.loading = typeof items === "function";
        levels = levels.concat([level]);
        if (typeof items === "function")
            items(list => {
                if (levels.length <= depth || !levels[depth].loading) return;
                const copy = levels.slice();
                copy[depth] = Object.assign({}, copy[depth], { items: list ?? [], loading: false });
                levels = copy;
            });
    }
    function setSel(depth, i) {
        if (depth >= levels.length || levels[depth].sel === i) return;
        // pointing at another row closes the submenu that belonged to the old one
        const keep = levels.length > depth + 1 && levels[depth + 1].from === i;
        const copy = keep ? levels.slice() : levels.slice(0, depth + 1);
        copy[depth] = Object.assign({}, copy[depth], { sel: i });
        levels = copy;
    }
    function openSub(depth, i, rowRight, rowLeft, rowY) {
        const item = levels[depth]?.items?.[i];
        if (!item?.sub || item.enabled === false) return;
        if (levels.length > depth + 1 && levels[depth + 1].from === i) return;
        levels = levels.slice(0, depth + 1);
        push({ x: rowRight + 2, altX: rowLeft - 2, y: rowY - 4, up: false, from: i }, item.sub);
    }
    function activate(depth, i, geom) {
        const item = levels[depth]?.items?.[i];
        if (!item || item.sep || item.enabled === false) return;
        if (item.sub) { if (geom) openSub(depth, i, geom.right, geom.left, geom.y); return; }
        close();
        if (item.run) { later.fn = item.run; later.restart(); }
    }
    Timer { id: later; property var fn; interval: 120; onTriggered: if (fn) fn() }

    // ---------------------------------------------------------------- IPC
    IpcHandler {
        target: "start"
        function toggle(): void { root.toggle("start"); }
        function open(): void { root.show("start"); }
        function close(): void { root.close(); }
    }
    IpcHandler {
        target: "search"
        function toggle(): void { root.toggle("search"); }
        function open(text: string): void { root.show("search", null, { text: text }); }
    }
    // the emoji panel on a tab (emoji | gif | kaomoji | symbols | clipboard), at global (x, y):
    //   qs ipc call emoji open clipboard 1200 600     (scripts/panel.sh passes the pointer)
    IpcHandler {
        target: "emoji"
        function open(tab: string, x: int, y: int): void {
            if (root.kind === "emoji" && (root.opts.tab ?? "") === tab) { root.close(); return; }
            root.show("emoji", null, { tab: tab, x: x, y: y });
        }
        function close(): void { root.close(); }
    }
    IpcHandler {
        target: "run"
        function toggle(): void { root.toggle("run"); }
        function open(): void { root.show("run"); }
    }
    // qs ipc call flyout open quick | notif | widgets | tray  (and close); page quick wifi|bluetooth|vpn|sound;
    // current (what is open: for tests)
    IpcHandler {
        target: "flyout"
        function open(k: string): void { root.show(k); }
        function page(k: string, page: string): void { root.show(k, null, { page: page }); }
        function toggle(k: string): void { root.toggle(k); }
        function current(): string { return root.closing ? "" : root.kind; }
        function close(): void { root.close(); }
    }
}
