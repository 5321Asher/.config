pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Notification daemon. Keeps every notification until dismissed; each one also pops up briefly (Toast.qml).
Singleton {
    id: root

    // Newest first
    readonly property var list: server.trackedNotifications.values.slice().reverse()
    readonly property int count: server.trackedNotifications.values.length
    // Set on arrival, cleared when the panel is opened
    property bool unread: false
    // Do not disturb: notifications are still kept, only critical ones pop up
    property bool dnd: false

    // Every notification also pops up as a toast (Toast.qml)
    signal popup(Notification notification)

    // Arrival time per notification id, and a clock to render "5m ago" against
    property var times: ({})
    property date now: new Date()

    function clearAll() {
        for (const n of server.trackedNotifications.values.slice())
            n.dismiss();
    }

    function ago(n) {
        const t = n ? times[n.id] : null;
        if (!t)
            return "";
        const mins = Math.floor((now - t) / 60000);
        if (mins < 1) return "now";
        if (mins < 60) return mins + "m";
        const hours = Math.floor(mins / 60);
        if (hours < 24) return hours + "h";
        return Math.floor(hours / 24) + "d";
    }

    Timer {
        running: true
        repeat: true
        interval: 30000
        onTriggered: root.now = new Date()
    }

    NotificationServer {
        id: server

        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        imageSupported: true

        onNotification: n => {
            n.tracked = true;
            root.times[n.id] = new Date();
            root.now = new Date();
            root.unread = true;
            // Notifications carried over from before a Quickshell reload were already shown
            if (!n.lastGeneration && (!root.dnd || n.urgency === NotificationUrgency.Critical))
                root.popup(n);
        }
    }
}
