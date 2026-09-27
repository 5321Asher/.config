import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

// Collapsible tray. Left click activates (or opens the menu for menu-only items),
// right click opens the menu, middle click is the secondary action, scroll is passed through.
Row {
    id: root

    // Called with (item, iconItem) when a menu should open
    property var openMenu: (item, anchor) => {}
    property bool expanded: true

    visible: SystemTray.items.values.length > 0
    spacing: 2

    // Collapse toggle; shows the item count while collapsed
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: toggleRow.implicitWidth + 12
        implicitHeight: Theme.barHeight - 10
        radius: 0
        color: toggleMouse.containsMouse ? Theme.surface : "transparent"

        Row {
            id: toggleRow
            anchors.centerIn: parent
            spacing: 4

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.expanded
                text: SystemTray.items.values.length
                font.family: Theme.font
                font.pixelSize: 11
                font.bold: true
                color: Theme.dim
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: String.fromCodePoint(0xF0142)
                font.family: Theme.font
                font.pixelSize: 16
                color: Theme.dim
                rotation: root.expanded ? 0 : 180

                Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            }
        }

        MouseArea {
            id: toggleMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }
    }

    // Icons, sliding closed when collapsed
    Item {
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: root.expanded ? icons.implicitWidth : 0
        implicitHeight: Theme.barHeight - 10
        clip: true

        Behavior on implicitWidth { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        Row {
            id: icons

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Repeater {
                model: SystemTray.items

                Rectangle {
                    id: slot

                    required property var modelData

                    // Theme icons the theme doesn't have would render as a checkerboard
                    readonly property bool iconMissing: {
                        const src = modelData.icon ?? "";
                        if (!src.startsWith("image://icon/") || src.includes("?path="))
                            return src === "";
                        return !Quickshell.hasThemeIcon(src.slice(13).split("?")[0]);
                    }

                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: 28
                    implicitHeight: Theme.barHeight - 10
                    radius: 0
                    color: mouse.containsMouse ? Theme.surface : "transparent"

                    Text {
                        anchors.centerIn: parent
                        visible: slot.iconMissing
                        text: (slot.modelData.title || slot.modelData.id || "?").charAt(0).toUpperCase()
                        font.family: Theme.font
                        font.pixelSize: 13
                        font.bold: true
                        color: Theme.dim
                    }

                    Image {
                        anchors.centerIn: parent
                        visible: !slot.iconMissing
                        source: slot.modelData.icon
                        sourceSize.width: 16
                        sourceSize.height: 16
                        width: 16
                        height: 16
                        smooth: true
                    }

                    MouseArea {
                        id: mouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                        onClicked: e => {
                            const item = slot.modelData;
                            if (e.button === Qt.MiddleButton)
                                item.secondaryActivate();
                            else if (e.button === Qt.RightButton || item.onlyMenu)
                                item.hasMenu && root.openMenu(item, slot);
                            else
                                item.activate();
                        }
                        onWheel: e => slot.modelData.scroll(e.angleDelta.y || e.angleDelta.x, e.angleDelta.y === 0)
                    }
                }
            }
        }
    }
}
