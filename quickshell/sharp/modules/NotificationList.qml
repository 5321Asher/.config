import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications

// Scrollable notification history with a header and "Clear all"
ColumnLayout {
    id: root

    spacing: 10

    // Header
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
            text: "Notifications"
            font.family: Theme.font
            font.pixelSize: 14
            font.bold: true
            color: Theme.fg
        }

        Rectangle {
            visible: Notifs.count > 0
            implicitWidth: Math.max(20, countText.implicitWidth + 10)
            implicitHeight: 20
            radius: 0
            color: Theme.accentMuted

            Text {
                id: countText
                anchors.centerIn: parent
                text: Notifs.count
                font.family: Theme.font
                font.pixelSize: 11
                font.bold: true
                color: Theme.fg
            }
        }

        Item { Layout.fillWidth: true }

        // Do not disturb (also on the Quick tab)
        Rectangle {
            implicitWidth: 24
            implicitHeight: 24
            radius: 0
            color: Notifs.dnd ? Theme.accentMuted : dndMouse.containsMouse ? Theme.surface : "transparent"
            border.width: 1
            border.color: Notifs.dnd || dndMouse.containsMouse ? Theme.accent : Theme.border

            Text {
                anchors.centerIn: parent
                text: String.fromCodePoint(Notifs.dnd ? 0xF009B : 0xF009A)
                font.family: Theme.font
                font.pixelSize: 13
                color: Notifs.dnd ? Theme.fg : Theme.dim
            }

            MouseArea {
                id: dndMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Notifs.dnd = !Notifs.dnd
            }
        }

        Rectangle {
            visible: Notifs.count > 0
            implicitWidth: clearText.implicitWidth + 20
            implicitHeight: 24
            radius: 0
            color: clearMouse.containsMouse ? Theme.surface : "transparent"
            border.width: 1
            border.color: clearMouse.containsMouse ? Theme.accent : Theme.border

            Text {
                id: clearText
                anchors.centerIn: parent
                text: "Clear all"
                font.family: Theme.font
                font.pixelSize: 11
                color: clearMouse.containsMouse ? Theme.accent : Theme.dim
            }

            MouseArea {
                id: clearMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Notifs.clearAll()
            }
        }
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        // Empty state
        Column {
            anchors.centerIn: parent
            visible: Notifs.count === 0
            spacing: 8

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: ""
                font.family: Theme.font
                font.pixelSize: 24
                color: Theme.border
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "All caught up"
                font.family: Theme.font
                font.pixelSize: 12
                color: Theme.dim
            }
        }

        ListView {
            id: list

            anchors.fill: parent
            clip: true
            spacing: 8
            boundsBehavior: Flickable.StopAtBounds

            model: ScriptModel {
                values: Notifs.list
            }

            add: Transition {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 }
                NumberAnimation { property: "x"; from: 30; to: 0; duration: 250; easing.type: Easing.OutCubic }
            }
            remove: Transition {
                NumberAnimation { property: "opacity"; to: 0; duration: 150 }
                NumberAnimation { property: "x"; to: 60; duration: 200; easing.type: Easing.InCubic }
            }
            displaced: Transition {
                NumberAnimation { property: "y"; duration: 220; easing.type: Easing.OutCubic }
            }

            delegate: NotificationCard {
                required property Notification modelData
                notification: modelData
                width: list.width
            }
        }

        // Fade out the bottom edge when there's more to scroll
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 24
            visible: !list.atYEnd
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: Theme.bg }
            }
        }
    }

    component NotificationCard: Rectangle {
        id: card

        property Notification notification
        readonly property bool critical: notification?.urgency === NotificationUrgency.Critical
        readonly property var defaultAction: notification?.actions.find(a => a.identifier === "default") ?? null
        readonly property var buttons: notification?.actions.filter(a => a.identifier !== "default") ?? []
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
        radius: 0
        color: cardMouse.containsMouse ? Theme.surface : Theme.bgDark
        border.width: 1
        border.color: critical ? Theme.danger : cardMouse.containsMouse ? Theme.accent : Theme.border

        Behavior on color { ColorAnimation { duration: 120 } }

        MouseArea {
            id: cardMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: card.defaultAction ? Qt.PointingHandCursor : Qt.ArrowCursor
            // Non-resident notifications dismiss themselves when invoked
            onClicked: card.defaultAction?.invoke()
        }

        RowLayout {
            id: content

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 12

            // Icon
            ClippingRectangle {
                Layout.alignment: Qt.AlignTop
                implicitWidth: 36
                implicitHeight: 36
                radius: 0
                color: Theme.hover

                Text {
                    anchors.centerIn: parent
                    visible: iconImage.status !== Image.Ready
                    text: ""
                    font.family: Theme.font
                    font.pixelSize: 15
                    color: Theme.dim
                }

                Image {
                    id: iconImage
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

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        Layout.fillWidth: true
                        text: (card.notification?.appName || "Notification").toUpperCase()
                              + "  ·  " + Notifs.ago(card.notification)
                        elide: Text.ElideRight
                        font.family: Theme.font
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 1
                        color: card.critical ? Theme.danger : Theme.dim
                    }

                    // Dismiss
                    Rectangle {
                        implicitWidth: 20
                        implicitHeight: 20
                        radius: 0
                        opacity: cardMouse.containsMouse || closeMouse.containsMouse ? 1 : 0
                        color: closeMouse.containsMouse ? Theme.border : "transparent"

                        Behavior on opacity { NumberAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent
                            text: ""
                            font.family: Theme.font
                            font.pixelSize: 10
                            color: Theme.fg
                        }

                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: card.notification.dismiss()
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
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
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    font.family: Theme.font
                    font.pixelSize: 12
                    color: Theme.dim
                    linkColor: Theme.accent
                    onLinkActivated: link => Qt.openUrlExternally(link)
                }

                // Action buttons
                Flow {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    visible: card.buttons.length > 0
                    spacing: 6

                    Repeater {
                        model: card.buttons

                        Rectangle {
                            required property var modelData

                            width: actionText.implicitWidth + 20
                            height: 24
                            radius: 0
                            color: actionMouse.containsMouse ? Theme.accentMuted : Theme.hover

                            Text {
                                id: actionText
                                anchors.centerIn: parent
                                text: parent.modelData.text
                                font.family: Theme.font
                                font.pixelSize: 11
                                color: Theme.fg
                            }

                            MouseArea {
                                id: actionMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: parent.modelData.invoke()
                            }
                        }
                    }
                }
            }
        }
    }
}
