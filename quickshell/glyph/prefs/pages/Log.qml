import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import "../../theme"
import "../../widgets"
import "../../services"
import ".."

// NOTES: every notification still held (newest first) as rounded cards with their actions; do not
// disturb; clear all. The count in Doto.
Column {
    id: root

    spacing: 22
    Component.onCompleted: Notifs.unread = 0

    function plain(s) {
        return (s ?? "").replace(/<br\s*\/?>/gi, "\n").replace(/<[^>]*>/g, "")
            .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&amp;/g, "&").trim();
    }
    function ago(n) {
        const t = Notifs.times[n.id];
        if (!t) return "";
        const m = Math.floor((Date.now() - t) / 60000);
        return m < 1 ? "now" : m < 60 ? m + " min" : Math.floor(m / 60) + " h";
    }
    function icon(n) {
        const i = n.image || n.appIcon || "";
        if (i.startsWith("/")) return "file://" + i;
        if (i.startsWith("file://") || i.startsWith("image://")) return i;
        return i ? Quickshell.iconPath(i, true) : "";
    }

    Row {
        spacing: 18
        Num { anchors.verticalCenter: parent.verticalCenter; text: Notifs.history.length; font.pixelSize: 64 }
        Lb { anchors.verticalCenter: parent.verticalCenter; text: "held" }
        Item { width: 30; height: 1 }
        Switch { anchors.verticalCenter: parent.verticalCenter; checked: Notifs.dnd; onToggled: Notifs.dnd = !Notifs.dnd }
        Lb { anchors.verticalCenter: parent.verticalCenter; text: Notifs.dnd ? "do not disturb · urgent only" : "do not disturb" }
        Btn { anchors.verticalCenter: parent.verticalCenter; text: "clear all"; enabled: Notifs.history.length > 0; onClicked: Notifs.clearAll() }
    }

    Lb { visible: Notifs.history.length === 0; text: "nothing here" }

    Repeater {
        model: Notifs.history
        Rectangle {
            id: m
            required property var modelData
            readonly property bool urgent: modelData.urgency === NotificationUrgency.Critical
            width: root.width
            height: col.implicitHeight + 36
            radius: 28
            color: Theme.s1
            border { width: 1; color: m.urgent ? Theme.red : Theme.s2 }
            Rectangle {
                id: ic
                x: 18
                y: 18
                width: 46
                height: 46
                radius: 23
                color: Theme.s2
                Icon { anchors.centerIn: parent; text: "\u{F009A}"; visible: !img.visible }
                Image { id: img; anchors.centerIn: parent; width: 26; height: 26; visible: status === Image.Ready; source: root.icon(m.modelData)
                        sourceSize: Qt.size(52, 52); fillMode: Image.PreserveAspectFit; layer.enabled: true; layer.effect: Dm { step: 2 } }
            }
            Column {
                id: col
                anchors { left: ic.right; leftMargin: 16; right: parent.right; rightMargin: 22 }
                y: 18
                spacing: 4
                Item {
                    width: parent.width
                    height: 16
                    Lb { text: (m.modelData.appName || "system") + "  ·  " + root.ago(m.modelData); px: 10; color: m.urgent ? Theme.red : Theme.grey }
                    Icon { anchors.right: parent.right; text: "\u{F0156}"; font.pixelSize: 16; color: Theme.grey
                           MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: m.modelData.dismiss() } }
                }
                Text { width: parent.width; wrapMode: Text.Wrap; text: root.plain(m.modelData.summary); color: Theme.fg
                       font { family: Theme.ui; pixelSize: 17; weight: Font.DemiBold } }
                Text { visible: text !== ""; width: parent.width; wrapMode: Text.Wrap; maximumLineCount: 6; elide: Text.ElideRight
                       text: root.plain(m.modelData.body); color: Theme.grey; font { family: Theme.ui; pixelSize: 15 } }
                Flow {
                    visible: (m.modelData.actions ?? []).length > 0
                    width: parent.width
                    spacing: 8
                    topPadding: 8
                    Repeater { model: m.modelData.actions ?? []
                        Btn { required property var modelData; text: modelData.identifier === "default" ? "open" : (modelData.text || modelData.identifier); onClicked: modelData.invoke() } }
                }
            }
        }
    }
}
