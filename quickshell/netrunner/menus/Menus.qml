pragma Singleton

import QtQuick
import Quickshell

// The open menu cascade (Start menu, a tray app's menu, a window's menu bar), drawn by MenuLayer
// on one screen. A menu is a list of items:
//   { text, icon (theme icon name), sub (items, or fn(done) that calls done(items) when ready),
//     run (fn), sep (a separator line), enabled, check (bool: a check mark), radio (bool: a dot),
//     bold, hint (right-aligned text) }
// `sub` and `run` are exclusive. Levels: [{ items, ax, ay, altX, up, big, banner, sel, loading }].
Singleton {
    id: root

    property string screen: ""      // the screen's name while a menu is open
    property string kind: ""        // "start", "tray", "menubar"… ("" = closed)
    property var levels: []
    readonly property bool open: kind !== ""

    // Open a cascade: `items` at (x, y) in the screen's coordinates; up = grow upwards from y
    function show(screenName, kind_, items, x, y, opts) {
        const o = opts ?? {};
        screen = screenName;
        kind = kind_;
        levels = [];
        push({ ax: x, ay: y, altX: x, up: o.up ?? false, big: o.big ?? false, banner: o.banner ?? false }, items);
    }
    function close() {
        kind = "";
        levels = [];
    }
    function toggle(screenName, kind_, items, x, y, opts) {
        if (open && kind === kind_ && screen === screenName) close();
        else show(screenName, kind_, items, x, y, opts);
    }

    // Add a level; `items` may be a list or a loader function
    function push(level, items) {
        const depth = levels.length;
        level.sel = -1;
        level.items = typeof items === "function" ? [] : (items ?? []);
        level.loading = typeof items === "function";
        levels = levels.concat([level]);
        if (typeof items === "function") {
            items(list => {
                if (levels.length <= depth || !levels[depth].loading) return;     // closed meanwhile
                const copy = levels.slice();
                copy[depth] = Object.assign({}, copy[depth], { items: list ?? [], loading: false });
                levels = copy;
            });
        }
    }

    // Select a row (deeper levels stay open until closeFrom / openSub replaces them)
    function setSel(depth, index) {
        if (depth >= levels.length || levels[depth].sel === index) return;
        const copy = levels.slice();
        copy[depth] = Object.assign({}, copy[depth], { sel: index });
        levels = copy;
    }

    // Open item `index` of level `depth`'s submenu next to its row (rowX..rowRight, rowY in screen px)
    function openSub(depth, index, rowRight, rowLeft, rowY, selectFirst) {
        const item = levels[depth]?.items?.[index];
        if (!item || !item.sub || item.enabled === false) return;
        if (levels.length > depth + 1 && levels[depth + 1].from === index) {
            if (selectFirst) setSel(depth + 1, firstEnabled(levels[depth + 1].items, 0, 1));
            return;
        }
        levels = levels.slice(0, depth + 1);
        setSelKeep(depth, index);
        push({ ax: rowRight - 3, ay: rowY - 3, altX: rowLeft + 3, up: false, big: false, banner: false, from: index }, item.sub);
        if (selectFirst) setSel(depth + 1, firstEnabled(levels[depth + 1].items, 0, 1));
    }
    function setSelKeep(depth, index) {
        const copy = levels.slice();
        copy[depth] = Object.assign({}, copy[depth], { sel: index });
        levels = copy;
    }
    function closeFrom(depth) {
        if (depth <= 0) close();
        else levels = levels.slice(0, depth);
    }

    function firstEnabled(items, from, dir) {
        const n = items.length;
        for (let k = 0; k < n; k++) {
            const i = ((from + k * dir) % n + n) % n;
            if (!items[i].sep && items[i].enabled !== false) return i;
        }
        return -1;
    }

    // Run an item: its submenu, or close everything and do it (a moment later, so the menu is gone
    // from the screen first, e.g. before a screenshot)
    function activate(depth, index, geom) {
        const item = levels[depth]?.items?.[index];
        if (!item || item.sep || item.enabled === false) return;
        if (item.sub) {
            if (geom) openSub(depth, index, geom.right, geom.left, geom.y, true);
            return;
        }
        close();
        if (item.run) { later.fn = item.run; later.restart(); }
    }
    Timer { id: later; property var fn; interval: 90; onTriggered: if (fn) fn() }
}
