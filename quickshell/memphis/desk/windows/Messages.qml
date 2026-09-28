import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import "../../theme"
import "../../widgets"
import "../../services"
import "../../menus"
import ".."

// The notification history, as an Outlook Express inbox: a toolbar (Delete, Delete All, Do Not
// Disturb), the message list (priority, From = the program, Subject = the summary, Received),
// and the preview pane with the body and the message's actions.
Win {
    id: root

    title: "Inbox - Notifications"
    icon: "internet-mail"
    minButton: true
    onMinRequested: closeRequested()
    status: `${list.length} message(s)` + (Notifs.dnd ? "  ·  Do Not Disturb is on: only urgent messages pop up" : "")
    menus: [
        { title: "File", items: () => [{ text: "Close", run: () => root.closeRequested() }] },
        { title: "Edit", items: () => [
            { text: "Delete", enabled: !!current, run: () => current.dismiss() },
            { text: "Delete All", enabled: list.length > 0, run: () => Notifs.clearAll() },
        ] },
        { title: "Tools", items: () => [{ text: "Do Not Disturb", check: Notifs.dnd, run: () => Notifs.dnd = !Notifs.dnd }] },
    ]
    onMenuRequested: (menu, x, y) => Menus.show(Desk.wins.messages?.screen ?? Desk.focusedScreen(), "menubar", menu.items(), x, y, {})

    readonly property var list: Notifs.history
    property int sel: 0
    readonly property Notification current: list[Math.min(sel, list.length - 1)] ?? null

    Component.onCompleted: Notifs.unread = 0
    onActiveChanged: if (active) Notifs.unread = 0

    function plain(s) {
        return (s ?? "").replace(/<br\s*\/?>/gi, "\n").replace(/<[^>]*>/g, "")
            .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&amp;/g, "&").trim();
    }
    function received(n) {
        const t = Notifs.times[n.id];
        if (!t) return "";
        const d = new Date(t), now = new Date();
        return d.toDateString() === now.toDateString() ? Qt.formatTime(d, "h:mm AP") : Qt.formatDateTime(d, "M/d/yy h:mm AP");
    }

    Column {
        anchors.fill: parent
        anchors.margins: 2
        spacing: 4

        // ---------------------------------------------------------------- toolbar
        Row {
            spacing: 2
            ToolBtn { text: "Delete"; icon: "edit-delete"; enabled: !!root.current; onClicked: root.current.dismiss() }
            ToolBtn { text: "Delete All"; icon: "user-trash"; enabled: root.list.length > 0; onClicked: Notifs.clearAll() }
            Sep { vertical: true; height: 44; y: 2 }
            ToolBtn {
                text: "Do Not Disturb"
                icon: "notification-disabled"
                checked: Notifs.dnd
                onClicked: Notifs.dnd = !Notifs.dnd
            }
        }

        // ---------------------------------------------------------------- the list
        ListBox {
            id: box
            width: parent.width
            height: (parent.height - 56) * 0.48
            model: root.list
            currentIndex: root.sel
            onClicked: i => root.sel = i
            iconOf: n => n.urgency === NotificationUrgency.Critical ? "dialog-error" : "mail-read"
            columns: [
                { title: "From", width: 170, text: n => n.appName || "Unknown" },
                { title: "Subject", width: 0, text: n => root.plain(n.summary) },
                { title: "Received", width: 150, text: n => root.received(n) },
            ]
        }

        // ---------------------------------------------------------------- preview
        Bevel {
            width: parent.width
            height: parent.height - box.height - 56
            kind: "sunken"
            fill: Theme.window

            Rectangle {
                id: head
                x: 2; y: 2
                width: parent.width - 4
                height: 48
                color: Theme.face
                Column {
                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    Txt { text: "From:  " + (root.current?.appName || ""); bold: true }
                    Txt { text: "Subject:  " + root.plain(root.current?.summary); width: head.width - 16; elide: Text.ElideRight }
                }
            }
            Flickable {
                id: flick
                x: 10
                y: head.height + 8
                width: parent.width - 20 - (bar.visible ? bar.width : 0)
                height: parent.height - y - 8 - acts.height
                clip: true
                contentHeight: body.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                Txt {
                    id: body
                    width: flick.width
                    wrapMode: Text.Wrap
                    verticalAlignment: Text.AlignTop
                    color: Theme.windowText
                    text: root.current ? root.plain(root.current.body) || "(no message text)" : "There are no messages."
                }
            }
            Scroll { id: bar; flick: flick; x: parent.width - width - 2; y: flick.y; height: flick.height }
            Row {
                id: acts
                x: 10
                y: parent.height - height - 8
                spacing: 6
                Repeater {
                    model: root.current?.actions ?? []
                    Btn {
                        required property var modelData
                        text: modelData.identifier === "default" ? "Open" : (modelData.text || modelData.identifier)
                        onClicked: modelData.invoke()
                    }
                }
            }
        }
    }

    // Outlook Express's big toolbar buttons: icon over label, flat until hovered
    component ToolBtn: Btn {
        flat: true
        implicitHeight: 44
        iconSize: 24
    }
}
