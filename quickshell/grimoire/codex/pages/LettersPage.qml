import QtQuick
import Quickshell.Services.Notifications
import "../../theme"
import "../../widgets"
import "../../services"
import ".."

// IV. Letters: every letter still kept (newest first), opened, with its replies; do not disturb;
// burn them all.
Column {
    id: root

    spacing: 16
    Component.onCompleted: Notifs.unread = 0

    function plain(s) {
        return (s ?? "").replace(/<br\s*\/?>/gi, "\n").replace(/<[^>]*>/g, "")
            .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&amp;/g, "&").trim();
    }
    function ago(n) {
        const t = Notifs.times[n.id];
        if (!t) return "";
        const m = Math.floor((Date.now() - t) / 60000);
        return m < 1 ? "just now" : m < 60 ? m + " min ago" : Math.floor(m / 60) + " h ago";
    }

    Row {
        spacing: 10
        Seal { anchors.verticalCenter: parent.verticalCenter; checked: Notifs.dnd; onToggled: Notifs.dnd = !Notifs.dnd }
        Body { anchors.verticalCenter: parent.verticalCenter; italic: true; color: Theme.inkDim
               text: Notifs.dnd ? "do not disturb · only urgent sendings" : "letters are welcome" }
        Btn { text: "burn them all"; enabled: Notifs.history.length > 0; onClicked: Notifs.clearAll() }
    }

    Body { visible: Notifs.history.length === 0; text: "No letters are kept. The desk is clear."; italic: true; color: Theme.inkDim }

    Repeater {
        model: Notifs.history
        Item {
            id: m
            required property var modelData
            readonly property bool urgent: modelData.urgency === NotificationUrgency.Critical
            width: root.width
            height: col.implicitHeight + 22
            Rectangle {
                anchors.fill: parent
                radius: 3
                color: Theme.alpha("#ffffff", 0.14)
                border.width: 1
                border.color: m.urgent ? Theme.alpha(Theme.rubric, 0.7) : Theme.alpha(Theme.inkDim, 0.35)
            }
            // a dab of wax in the corner
            Rectangle { x: parent.width - 20; y: 10; width: 10; height: 10; radius: 5
                        color: m.urgent ? Theme.arcane : Theme.wax; border.width: 1; border.color: Qt.darker(color, 1.4) }
            Column {
                id: col
                x: 14; y: 11
                width: parent.width - 44
                spacing: 4
                Body { text: "from " + (m.modelData.appName || "a stranger") + " · " + root.ago(m.modelData)
                       italic: true; color: m.urgent ? Theme.rubric : Theme.inkDim; font.pixelSize: 13 }
                Body { width: parent.width; wrapMode: Text.Wrap; text: root.plain(m.modelData.summary); strong: true }
                Body { visible: text !== ""; width: parent.width; wrapMode: Text.Wrap; maximumLineCount: 6; elide: Text.ElideRight
                       text: root.plain(m.modelData.body); font.pixelSize: 14 }
                Flow {
                    visible: (m.modelData.actions ?? []).length > 0
                    width: parent.width
                    spacing: 6
                    Repeater { model: m.modelData.actions ?? []
                        Btn { required property var modelData; text: modelData.identifier === "default" ? "open" : (modelData.text || modelData.identifier); onClicked: modelData.invoke() } }
                }
            }
            Text {
                anchors.right: parent.right; anchors.rightMargin: 8
                anchors.bottom: parent.bottom; anchors.bottomMargin: 6
                text: "burn"
                color: Theme.inkDim
                font.family: Theme.caps
                font.pixelSize: 10
                font.letterSpacing: 1
                MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: m.modelData.dismiss() }
            }
        }
    }
}
