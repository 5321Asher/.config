pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// QUEUE // DAILY GIGS: a short list of things to do today, each with a tag ("HEALTH", "FINANCE").
// Done marks clear themselves every morning (the gigs are daily); the list itself stays.
// Kept in ~/.local/share/netrunner/queue.json: { day, gigs: [{ text, tag, done }] }.
//   qs ipc call queue add "Gym|health" | toggle <n> | remove <n> | list
Singleton {
    id: root

    property var gigs: []
    property string day: ""
    readonly property int cleared: gigs.filter(g => g.done).length
    readonly property int total: gigs.length
    // the next one not done: the "ACTIVE" gig; after it, "NEXT"
    readonly property int active: gigs.findIndex(g => !g.done)

    readonly property string path: Quickshell.env("HOME") + "/.local/share/netrunner/queue.json"

    function today() { return Qt.formatDate(new Date(), "yyyy-MM-dd"); }
    function save() { file.setText(JSON.stringify({ day: day, gigs: gigs }, null, 1)); }
    function set(list) { gigs = list; save(); }

    function add(text, tag) {
        const t = (text ?? "").trim();
        if (!t) return;
        set(gigs.concat([{ text: t, tag: (tag ?? "").trim().toUpperCase(), done: false }]));
    }
    function toggle(i) {
        if (i < 0 || i >= gigs.length) return;
        const g = gigs.slice();
        g[i] = Object.assign({}, g[i], { done: !g[i].done });
        set(g);
    }
    function remove(i) { set(gigs.filter((_, k) => k !== i)); }
    function status(i) {
        const g = gigs[i];
        return !g ? "" : g.done ? "done" : i === active ? "active" : "next";
    }

    // a new day clears the marks
    function rollover() {
        const t = today();
        if (day === t) return;
        day = t;
        set(gigs.map(g => Object.assign({}, g, { done: false })));
    }
    Timer { running: true; repeat: true; interval: 60000; onTriggered: root.rollover() }

    FileView {
        id: file
        path: root.path
        printErrors: false
        atomicWrites: true
        onLoaded: {
            try {
                const j = JSON.parse(text());
                root.gigs = j.gigs ?? [];
                root.day = j.day ?? "";
            } catch (e) {}
            root.rollover();
        }
        onLoadFailed: {
            // first run: a starter list to edit
            root.day = root.today();
            root.set([{ text: "Stretch", tag: "HEALTH", done: false }, { text: "Inbox zero", tag: "WORK", done: false },
                      { text: "Breakfast", tag: "MEAL", done: false }]);
        }
    }

    IpcHandler {
        target: "queue"
        function add(spec: string): void { const p = spec.split("|"); root.add(p[0], p[1] ?? ""); }
        function toggle(n: int): void { root.toggle(n); }
        function remove(n: int): void { root.remove(n); }
        function list(): string { return root.gigs.map((g, i) => `${i} ${g.done ? "x" : " "} ${g.text} [${g.tag}]`).join("\n"); }
    }
}
