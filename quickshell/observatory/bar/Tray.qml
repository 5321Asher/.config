import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../theme"
import "../utilities"

// System tray, on the horizon: each tray app is a small satellite in a brass ring.
// Left click activates it (or opens the menu for menu-only apps), right click opens its menu,
// middle click is its secondary action, scroll goes to the app.
Row {
    id: root

    required property ShellScreen screen

    spacing: 6
    visible: SystemTray.items.values.length > 0

    Repeater {
        model: SystemTray.items

        Item {
            id: slot
            required property var modelData

            // Theme icons the theme doesn't have would render as a checkerboard
            readonly property bool iconMissing: {
                const src = modelData.icon ?? "";
                if (!src.startsWith("image://icon/") || src.includes("?path=")) return src === "";
                return !Quickshell.hasThemeIcon(src.slice(13).split("?")[0]);
            }

            width: Theme.traySlot
            height: Theme.traySlot
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: mouse.containsMouse ? Theme.alpha(Theme.hover, 0.95) : Theme.alpha(Theme.bgDark, 0.7)
                border.width: 1
                border.color: mouse.containsMouse || TrayMenuState.item === slot.modelData ? Theme.brassBright : Theme.alpha(Theme.brass, 0.55)
            }
            Image {
                anchors.centerIn: parent
                visible: !slot.iconMissing
                source: slot.modelData.icon
                sourceSize.width: Theme.trayIcon
                sourceSize.height: Theme.trayIcon
                width: Theme.trayIcon
                height: Theme.trayIcon
                smooth: true
            }
            Text {
                anchors.centerIn: parent
                visible: slot.iconMissing
                text: (slot.modelData.title || slot.modelData.id || "?").charAt(0).toUpperCase()
                color: Theme.brass
                font.family: Theme.fontData
                font.pixelSize: Theme.dataSizeSmall + 1
                font.weight: Font.DemiBold
            }
            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: e => {
                    const item = slot.modelData;
                    if (e.button === Qt.MiddleButton) item.secondaryActivate();
                    else if (e.button === Qt.RightButton || item.onlyMenu) {
                        if (item.hasMenu) TrayMenuState.show(item, root.screen, slot.mapToItem(null, slot.width / 2, 0).x);
                    } else item.activate();
                }
                onWheel: e => slot.modelData.scroll(e.angleDelta.y || e.angleDelta.x, e.angleDelta.y === 0)
            }
        }
    }
}
