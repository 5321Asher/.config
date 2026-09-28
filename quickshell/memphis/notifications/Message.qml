import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
import "../theme"
import "../widgets"
import "../services"

// One notification, as a small 98 window: a caption with the app's name and a close button, the
// sender's picture (or 98's information / warning / stop icon), the summary in bold, the body, and
// its actions as push buttons. Closes itself after Theme.toastTimeout (critical ones stay); the
// pointer resting on it holds it. Click the body for the default action.
Item {
    id: root

    required property int nid
    readonly property Notification n: Notifs.notification(nid)

    readonly property bool critical: n?.urgency === NotificationUrgency.Critical
    readonly property string summary: plain(n?.summary ?? "")
    readonly property string body: plain(n?.body ?? "")
    readonly property var actions: (n?.actions ?? []).filter(a => a.identifier !== "default")

    function plain(s) {
        return s.replace(/<br\s*\/?>/gi, "\n").replace(/<[^>]*>/g, "")
                .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"')
                .replace(/&#39;/g, "'").replace(/&amp;/g, "&").trim();
    }
    // image hint first, then the app icon; theme icon names only if the theme has them
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
    height: frame.height

    // ---------------------------------------------------------------- lifetime
    property bool leaving: false
    function leave(dismissed) {
        if (leaving) return;
        leaving = true;
        // Timing out only hides the window: the notification stays in the inbox until dismissed
        if (n && dismissed) n.dismiss();
        Notifs.drop(nid);
    }
    Connections {
        target: root.n
        function onClosed() { if (!root.leaving) { root.leaving = true; Notifs.drop(root.nid); } }
    }
    Timer {
        interval: Theme.toastTimeout
        running: !root.critical && !root.leaving && !hover.hovered
        onTriggered: root.leave(false)
    }
    HoverHandler { id: hover }

    // 98 had no animations to speak of: it just drops into place from the taskbar a little
    property real rise: 0
    NumberAnimation on rise { from: 16; to: 0; duration: Theme.normal; easing.type: Theme.easing; running: true }
    transform: Translate { y: root.rise }

    Win {
        id: frame
        width: root.width
        height: content.implicitHeight + Theme.titleHeight + Theme.frame * 2 + 2 + Theme.pad * 2
        title: root.n?.appName || "Message"
        icon: root.n?.appIcon && Quickshell.hasThemeIcon(root.n.appIcon) ? root.n.appIcon : "dialog-information"
        active: hover.hovered || root.critical
        onCloseRequested: root.leave(true)

        MouseArea {
            anchors.fill: parent
            onClicked: {
                const def = (root.n?.actions ?? []).find(a => a.identifier === "default");
                if (def) def.invoke();
                root.leave(true);
            }
        }

        Column {
            id: content
            x: Theme.pad
            y: Theme.pad
            width: parent.width - Theme.pad * 2
            spacing: Theme.gap + 2

            Row {
                width: parent.width
                spacing: Theme.pad

                // the sender's picture, or 98's message-box icon for the urgency
                Item {
                    width: 40
                    height: 40
                    IconImage {
                        anchors.fill: parent
                        visible: root.picture !== ""
                        source: root.picture
                    }
                    Icon {
                        anchors.fill: parent
                        visible: root.picture === ""
                        size: 40
                        name: root.critical ? "dialog-error" : root.n?.urgency === NotificationUrgency.Low ? "dialog-information" : "dialog-information"
                    }
                }
                Column {
                    width: parent.width - 40 - Theme.pad
                    spacing: 4
                    Txt {
                        width: parent.width
                        text: root.summary
                        bold: true
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignTop
                    }
                    Txt {
                        width: parent.width
                        visible: text !== ""
                        text: root.body
                        wrapMode: Text.Wrap
                        maximumLineCount: Theme.toastLines
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignTop
                    }
                }
            }

            Flow {
                visible: root.actions.length > 0
                width: parent.width
                layoutDirection: Qt.RightToLeft
                spacing: 6
                Repeater {
                    model: root.actions
                    Btn {
                        required property var modelData
                        text: modelData.text || modelData.identifier
                        onClicked: { modelData.invoke(); root.leave(true); }
                    }
                }
            }
        }
    }
}
