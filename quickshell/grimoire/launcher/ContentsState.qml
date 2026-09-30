pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../services"
import "../codex"
import "../utilities"

// The arcana: Grimoire's root menu (SUPER + Space, or the clasp in the corner). The screen sinks into
// candlelit dark and the cards are dealt in a fan: one card per shared menu (~/.config/elephant/menus,
// the ones Walker shows: Apps, Trigger, Style, Power…), then Grimoire's own: the codex and the whole
// book. Drawing a card either does its thing (Apps opens the summoning circle) or turns it over into
// a reading: its menu, on the card's back, one level at a time (drawn by arcana/Arcana.qml).
//   qs ipc call contents toggle | open | close
//   qs ipc call contents draw <card> | choose <row> | back      (testing without the keyboard)
Singleton {
    id: root

    property bool open: false
    property var cards: []
    property int sel: 0
    // the card turned over (-1: the spread), and the menus open on its back, deepest last:
    // [{ title, items: [{ text, sub_text, check, sub, run }], loading, sel (its row, once left) }]
    property int reading: -1
    property var stack: []

    // what each shared menu looks like as a card: its numeral and its emblem (arcana/Emblem.qml)
    readonly property var arcana: ({
        apps: { numeral: "XVII", emblem: "star" },
        trigger: { numeral: "XVI", emblem: "tower" },
        style: { numeral: "XVIII", emblem: "moon" },
        power: { numeral: "XIII", emblem: "dusk" },
    })

    function toggle() { if (open) close(); else show(); }
    function show() {
        reading = -1;
        stack = [];
        sel = 0;
        open = true;
        Elephant.query("menus:start", list => {
            const shared = list.map(it => {
                const key = (it.text ?? "").toLowerCase();
                const look = arcana[key] ?? { numeral: "", emblem: "sigil" };
                const card = { title: it.text, sub_text: it.subtext ?? "", numeral: look.numeral, emblem: look.emblem };
                const isMenu = ((it.actions ?? [])[0] ?? "") === "menus:open";
                if (key === "apps") card.run = () => CircleState.open = true;     // the summoning circle
                else if (isMenu) card.sub = loader(it);
                else card.run = () => Elephant.activate(it);
                return card;
            });
            cards = shared.concat([
                { title: "Codex", sub_text: "switches · levels · letters", numeral: "II", emblem: "book", run: () => CodexState.show("helm") },
                { title: "The Book", sub_text: "every chapter laid open", numeral: "XXI", emblem: "world", run: () => OverviewState.open = true },
            ]);
        });
    }
    function close() {
        open = false;
        reading = -1;
        stack = [];
    }

    // an elephant menu's items, loaded when the reading gets to it
    function loader(it) {
        return done => Elephant.query(it.identifier.split("::")[0], l => done(l.map(x => {
            const raw = x.text ?? "";
            const item = { text: raw.replace(/^[●\s]+/, ""), sub_text: x.subtext ?? "", check: raw.startsWith("●") };
            if (((x.actions ?? [])[0] ?? "") === "menus:open") item.sub = loader(x);
            else item.run = () => Elephant.activate(x);
            return item;
        })));
    }

    // draw card i: do it, or turn it over
    function draw(i) {
        const c = cards[i];
        if (!c) return;
        sel = i;
        if (c.run) { later.fn = c.run; close(); later.restart(); return; }
        reading = i;
        stack = [];
        push(c.title, c.sub);
    }
    // The row chosen in the deepest menu. Kept apart from `stack`: changing the stack rebuilds the
    // list on screen, and the row under the pointer, rebuilt, would say "entered" again, forever
    // (hovering the menu locked it up). Each level remembers its row only when you go deeper.
    property int row: 0
    function push(title, sub) {
        const depth = stack.length;
        if (depth > 0) {
            const copy = stack.slice();
            copy[depth - 1] = Object.assign({}, copy[depth - 1], { sel: row });
            stack = copy;
        }
        row = 0;
        stack = stack.concat([{ title: title, items: [], loading: true, sel: 0 }]);
        sub(list => {
            if (stack.length <= depth || !stack[depth].loading) return;       // gone meanwhile
            const copy = stack.slice();
            copy[depth] = Object.assign({}, copy[depth], { items: list ?? [], loading: false });
            stack = copy;
            row = Math.max(0, (list ?? []).findIndex(x => x.check));
        });
    }
    function back() {
        if (stack.length > 1) { stack = stack.slice(0, -1); row = stack[stack.length - 1].sel ?? 0; }
        else if (reading >= 0) { reading = -1; stack = []; }
        else close();
    }
    function setSel(i) { row = i; }
    function choose(i) {
        const lv = stack[stack.length - 1];
        const it = lv?.items?.[i];
        if (!it) return;
        if (it.sub) { row = i; push(it.text, it.sub); return; }
        close();
        if (it.run) { later.fn = it.run; later.restart(); }
    }
    // a moment later, so the arcana is gone from the screen first (e.g. before a screenshot)
    Timer { id: later; property var fn; interval: 140; onTriggered: if (fn) fn() }

    IpcHandler {
        target: "contents"
        function toggle(): void { root.toggle(); }
        function open(): void { if (!root.open) root.show(); }
        function close(): void { root.close(); }
        function draw(i: int): void { root.draw(i); }
        function choose(i: int): void { root.choose(i); }
        function back(): void { root.back(); }
    }
}
