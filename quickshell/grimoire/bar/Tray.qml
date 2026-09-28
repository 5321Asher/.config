import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../theme"

// Tray apps as small icons set into the leather: left click activates (or opens the menu for
// menu-only apps), right click drops the menu as a parchment slip, middle is secondary, scroll
// scrolls. The icons sit a little dim and brighten under the pointer.
Row {
    id: root

    required property var bar
    spacing: 10
    visible: SystemTray.items.values.length > 0

    Repeater {
        model: SystemTray.items
        Item {
            id: slot
            required property var modelData
            width: 18
            height: 18
            Image {
                anchors.fill: parent
                source: slot.modelData.icon
                sourceSize.width: 18
                sourceSize.height: 18
                opacity: mouse.containsMouse ? 1 : 0.78
            }
            MouseArea {
                id: mouse
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: e => {
                    const it = slot.modelData;
                    if (e.button === Qt.MiddleButton) it.secondaryActivate();
                    else if (e.button === Qt.RightButton || it.onlyMenu) {
                        const p = slot.mapToItem(null, 0, 0);
                        TrayMenus.show(it, root.bar.screen.name, p.x - 30, Theme.barHeight + 6);
                    } else it.activate();
                }
                onWheel: e => slot.modelData.scroll(e.angleDelta.y || e.angleDelta.x, e.angleDelta.y === 0)
            }
        }
    }
}
