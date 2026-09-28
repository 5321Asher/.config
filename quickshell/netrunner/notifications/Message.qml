import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
import "../theme"
import "../widgets"
import "../services"

// One message: a cut-corner card sliding in from the right under the bar, a red (urgent) or
// cyan edge, "MSG // APP" in a tag, the summary decoding itself, the body, the actions. Leaves
// after Theme.toastTimeout (urgent ones stay); the pointer resting on it holds it; click to
// dismiss (running its default action).
Item {
    id: root

    required property int nid
    readonly property Notification n: Notifs.notification(nid)
    readonly property bool urgent: n?.urgency === NotificationUrgency.Critical
    readonly property color edge: urgent ? Theme.red : Theme.cyan
    readonly property var actions: (n?.actions ?? []).filter(a => a.identifier !== "default")

    function plain(s) {
        return (s ?? "").replace(/<br\s*\/?>/gi, "\n").replace(/<[^>]*>/g, "")
            .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&amp;/g, "&").trim();
    }
    function resolve(i) {
        if (!i) return "";
        if (i.startsWith("/")) return "file://" + i;
        if (i.startsWith("file:")) return i;
        if (i.startsWith("image://icon/")) i = i.slice(13);
        else if (i.startsWith("image://")) return i;
        return Quickshell.hasThemeIcon(i) ? Quickshell.iconPath(i) : "";
    }
    readonly property string picture: resolve(n?.image ?? "") || resolve(n?.appIcon ?? "")

    width: Theme.toastWidth
    height: card.height + 8

    property bool leaving: false
    property real slide: 1
    Behavior on slide { NumberAnimation { duration: Theme.normal; easing.type: Theme.easing } }
    Component.onCompleted: slide = 0
    function leave(dismissed) {
        if (leaving) return;
        leaving = true;
        slide = 1;
        gone.dismissed = dismissed;
        gone.start();
    }
    Timer {
        id: gone
        property bool dismissed: false
        interval: Theme.normal
        onTriggered: { if (root.n && dismissed) root.n.dismiss(); Notifs.drop(root.nid); }
    }
    Connections { target: root.n; function onClosed() { root.leave(false); } }
    Timer { interval: Theme.toastTimeout; running: !root.urgent && !root.leaving && !hover.hovered; onTriggered: root.leave(false) }
    HoverHandler { id: hover }

    Item {
        id: card
        x: root.slide * (root.width + 30)
        width: root.width
        height: col.implicitHeight + 26
        opacity: 1 - root.slide

        Chamfer { anchors.fill: parent; cut: 12; corners: "tr bl"; fill: Theme.alpha(Theme.bgDark, 0.94); stroke: Theme.alpha(root.edge, 0.8) }
        Rectangle { width: 2; height: parent.height - 12; color: root.edge }
        // urgent: the edge pulses
        SequentialAnimation on opacity { running: root.urgent && root.slide === 0; loops: Animation.Infinite
            NumberAnimation { to: 0.75; duration: 700 } NumberAnimation { to: 1; duration: 700 } }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                const def = (root.n?.actions ?? []).find(a => a.identifier === "default");
                if (def) def.invoke();
                root.leave(true);
            }
        }

        Column {
            id: col
            x: 16; y: 12
            width: parent.width - 32
            spacing: 6
            Row {
                spacing: 8
                Tag { height: 18; pixelSize: 10; text: root.urgent ? "ALERT" : "MSG"; color: root.edge }
                Label { anchors.verticalCenter: parent.verticalCenter; text: (root.n?.appName || "system"); strong: true; color: root.edge }
                Jp { anchors.verticalCenter: parent.verticalCenter; text: root.urgent ? "警告" : "受信" }
            }
            Row {
                width: parent.width
                spacing: 12
                IconImage {
                    visible: root.picture !== ""
                    implicitSize: 40
                    source: root.picture
                }
                Column {
                    width: parent.width - (root.picture ? 52 : 0)
                    spacing: 3
                    Scramble {
                        width: parent.width
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        target: root.plain(root.n?.summary)
                        color: Theme.bright
                        font.family: Theme.sans
                        font.pixelSize: Theme.data + 2
                        font.weight: Font.DemiBold
                    }
                    Text {
                        visible: text !== ""
                        width: parent.width
                        wrapMode: Text.Wrap
                        maximumLineCount: 5
                        elide: Text.ElideRight
                        text: root.plain(root.n?.body)
                        color: Theme.fg
                        font.family: Theme.sans
                        font.pixelSize: Theme.data
                    }
                }
            }
            Flow {
                visible: root.actions.length > 0
                width: parent.width
                spacing: 6
                Repeater { model: root.actions
                    Btn { required property var modelData; text: modelData.text || modelData.identifier; onClicked: { modelData.invoke(); root.leave(true); } } }
            }
        }
    }
}
