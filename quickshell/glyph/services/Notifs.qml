pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// The notification server. Every notification gets a pop-up message window: its id is kept in
// `model` (newest first) while on screen. Notifications stay in `history` until dismissed (a card
// timing out only hides the card). Do-not-disturb: only critical ones pop up.
Singleton {
    id: root

    property bool dnd: false
    // Newest first
    readonly property var history: server.trackedNotifications.values.slice().reverse()
    property var times: ({})          // id -> arrival (ms)
    property int unread: 0

    function clearAll() {
        for (const n of server.trackedNotifications.values.slice()) n.dismiss();
        unread = 0;
    }

    // id -> Notification; the ListModel only carries ids (so cards aren't rebuilt on every change)
    property var byId: ({})
    readonly property ListModel model: ListModel {}

    function notification(id) { return byId[id] ?? null; }

    // Take a card off the list (after it has slid away)
    function drop(id) {
        for (let i = 0; i < model.count; i++)
            if (model.get(i).nid === id) { model.remove(i); break; }
        delete byId[id];
    }

    NotificationServer {
        id: server

        keepOnReload: false
        bodySupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true;
            const t = Object.assign({}, root.times);
            t[n.id] = Date.now();
            root.times = t;
            root.unread++;
            // A replacement (same id) restarts that card
            if (root.byId[n.id]) root.drop(n.id);
            if (root.dnd && n.urgency !== NotificationUrgency.Critical) return;
            root.byId[n.id] = n;
            root.model.insert(0, { nid: n.id, born: Date.now() });
        }
    }

    // qs ipc call notifications clear | dnd
    IpcHandler {
        target: "notifications"
        function clear(): void { root.clearAll(); }
        function dnd(): void { root.dnd = !root.dnd; }
    }
}
