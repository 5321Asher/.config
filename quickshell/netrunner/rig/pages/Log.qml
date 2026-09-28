import QtQuick
import Quickshell.Services.Notifications
import "../../theme"
import "../../widgets"
import "../../services"
import ".."

// 04 LOG 記録: every message still held (newest first), with its actions; do not disturb; clear.
Column {
    id: root

    spacing: 18
    Component.onCompleted: Notifs.unread = 0

    function plain(s) {
        return (s ?? "").replace(/<br\s*\/?>/gi, "\n").replace(/<[^>]*>/g, "")
            .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&amp;/g, "&").trim();
    }
    function ago(n) {
        const t = Notifs.times[n.id];
        if (!t) return "";
        const m = Math.floor((Date.now() - t) / 60000);
        return m < 1 ? "now" : m < 60 ? m + "m" : Math.floor(m / 60) + "h";
    }

    Row {
        spacing: 10
        Switch { anchors.verticalCenter: parent.verticalCenter; checked: Notifs.dnd; onToggled: Notifs.dnd = !Notifs.dnd }
        Label { anchors.verticalCenter: parent.verticalCenter; text: Notifs.dnd ? "do not disturb // urgent only" : "messages on" }
        Btn { text: "clear all"; enabled: Notifs.history.length > 0; onClicked: Notifs.clearAll() }
    }

    Label { visible: Notifs.history.length === 0; text: "// no messages held" }

    Repeater {
        model: Notifs.history
        Item {
            id: m
            required property var modelData
            readonly property bool urgent: modelData.urgency === NotificationUrgency.Critical
            width: root.width
            height: col.implicitHeight + 20
            Chamfer { anchors.fill: parent; cut: 8; corners: "tr"; fill: Theme.alpha(Theme.bgDark, 0.6); stroke: m.urgent ? Theme.red : Theme.line }
            Rectangle { width: 2; height: parent.height; color: m.urgent ? Theme.red : Theme.cyan }
            Column {
                id: col
                x: 14; y: 10
                width: parent.width - 28
                spacing: 4
                Item {
                    width: parent.width
                    height: 16
                    Label { text: (m.modelData.appName || "system") + "  //  " + root.ago(m.modelData); color: m.urgent ? Theme.red : Theme.cyan }
                    Text { anchors.right: parent.right; text: "✕"; color: Theme.dim; font.pixelSize: 12
                           MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: m.modelData.dismiss() } }
                }
                Text { width: parent.width; wrapMode: Text.Wrap; text: root.plain(m.modelData.summary); color: Theme.bright
                       font.family: Theme.sans; font.pixelSize: Theme.data + 1; font.weight: Font.DemiBold }
                Text { visible: text !== ""; width: parent.width; wrapMode: Text.Wrap; maximumLineCount: 6; elide: Text.ElideRight
                       text: root.plain(m.modelData.body); color: Theme.fg; font.family: Theme.sans; font.pixelSize: Theme.data }
                Flow {
                    visible: (m.modelData.actions ?? []).length > 0
                    width: parent.width
                    spacing: 6
                    Repeater { model: m.modelData.actions ?? []
                        Btn { required property var modelData; text: modelData.identifier === "default" ? "open" : (modelData.text || modelData.identifier); onClicked: modelData.invoke() } }
                }
            }
        }
    }
}
