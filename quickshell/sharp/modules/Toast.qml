import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Widgets

// Notification popups under the bar on the focused monitor, newest on top.
// A toast hides after the app's timeout (5s by default, critical ones stay); the notification itself
// stays in the panel list. Click a toast to run its default action and hide it.
PanelWindow {
    id: root

    readonly property int maxToasts: 4
    // Notification objects currently shown, newest first
    property var toasts: []

    function hide(n) {
        toasts = toasts.filter(t => t !== n);
    }

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    visible: toasts.length > 0
    color: "transparent"
    anchors {
        top: true
        right: true
    }
    margins {
        top: Theme.barHeight + 8
        right: 8
    }
    implicitWidth: 360
    implicitHeight: Math.max(1, column.implicitHeight)
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-toast"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Connections {
        target: Notifs
        // A replaced notification (same id) is the same object: bring it back to the top
        function onPopup(n) {
            root.toasts = [n, ...root.toasts.filter(t => t !== n)].slice(0, root.maxToasts);
        }
    }

    Column {
        id: column

        width: parent.width
        spacing: 8

        move: Transition {
            NumberAnimation { property: "y"; duration: 220; easing.type: Easing.OutCubic }
        }

        Repeater {
            model: ScriptModel {
                values: root.toasts
            }

            delegate: ToastCard {
                required property Notification modelData
                notification: modelData
                width: column.width
            }
        }
    }

    component ToastCard: Rectangle {
        id: card

        property Notification notification
        readonly property bool critical: notification?.urgency === NotificationUrgency.Critical
        readonly property var defaultAction: notification?.actions.find(a => a.identifier === "default") ?? null
        readonly property string icon: resolveIcon(notification?.image) || resolveIcon(notification?.appIcon)

        // Image URL, file path or theme icon name -> loadable URL, or "" if the theme lacks it
        function resolveIcon(src) {
            if (!src)
                return "";
            if (src.startsWith("image://icon/")) {
                const name = src.slice(13);
                // File paths arrive wrapped as image://icon//path/to/file.png
                if (name.startsWith("/"))
                    return "file://" + name;
                return Quickshell.hasThemeIcon(name) ? src : "";
            }
            if (src.startsWith("/"))
                return "file://" + src;
            if (src.includes("://"))
                return src;
            return Quickshell.hasThemeIcon(src) ? Quickshell.iconPath(src) : "";
        }

        height: content.implicitHeight + 24
        color: mouse.containsMouse ? Theme.surface : Theme.bgDark
        border.width: 1
        border.color: critical ? Theme.danger : Theme.accent
        opacity: 0
        Component.onCompleted: opacity = 1

        Behavior on opacity { NumberAnimation { duration: 200 } }
        Behavior on color { ColorAnimation { duration: 120 } }

        // Dismissed from the panel or closed by the app
        Connections {
            target: card.notification
            function onClosed() {
                root.hide(card.notification);
            }
        }

        // Restarted when a replacement notification updates this one
        Connections {
            target: card.notification
            function onSummaryChanged() {
                hideTimer.restart();
            }
            function onBodyChanged() {
                hideTimer.restart();
            }
        }

        Timer {
            id: hideTimer
            interval: (card.notification?.expireTimeout ?? 0) > 0 ? card.notification.expireTimeout * 1000 : 5000
            running: !card.critical && !mouse.containsMouse
            onTriggered: root.hide(card.notification)
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                const n = card.notification;
                root.hide(n);
                card.defaultAction?.invoke();
            }
        }

        RowLayout {
            id: content

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 12

            ClippingRectangle {
                Layout.alignment: Qt.AlignTop
                visible: card.icon !== ""
                implicitWidth: 36
                implicitHeight: 36
                color: Theme.hover

                Image {
                    anchors.fill: parent
                    source: card.icon
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 72
                    sourceSize.height: 72
                    asynchronous: true
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Text {
                    Layout.fillWidth: true
                    text: (card.notification?.appName || "Notification").toUpperCase()
                    elide: Text.ElideRight
                    font.family: Theme.font
                    font.pixelSize: 10
                    font.bold: true
                    font.letterSpacing: 1
                    color: card.critical ? Theme.danger : Theme.accent
                }

                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: card.notification?.summary ?? ""
                    elide: Text.ElideRight
                    font.family: Theme.font
                    font.pixelSize: 13
                    font.bold: true
                    color: Theme.fg
                }

                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: card.notification?.body ?? ""
                    textFormat: Text.StyledText
                    wrapMode: Text.Wrap
                    maximumLineCount: 4
                    elide: Text.ElideRight
                    font.family: Theme.font
                    font.pixelSize: 11
                    color: Theme.dim
                }
            }
        }
    }
}
