pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// The notification server. Every notification arrives as a "transmission": it is kept in `model`
// (newest first) while its card is on screen, and dropped when the card is dismissed or expires.
Singleton {
    id: root

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
            // A replacement (same id) restarts that card
            if (root.byId[n.id]) root.drop(n.id);
            root.byId[n.id] = n;
            root.model.insert(0, { nid: n.id, born: Date.now() });
        }
    }
}
