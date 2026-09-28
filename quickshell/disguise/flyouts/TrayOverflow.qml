import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../theme"
import "../widgets"

// The hidden icons (the taskbar's ^): every tray app, four across. Click to open it, right-click
// for its menu.
Item {
    id: root

    required property string screenName
    readonly property var items: SystemTray.items.values
    implicitWidth: Math.max(1, Math.min(4, items.length)) * 40 + 16
    implicitHeight: Math.max(1, Math.ceil(items.length / 4)) * 40 + 16

    Acrylic { anchors.fill: parent }
    Txt { visible: root.items.length === 0; anchors.centerIn: parent; text: "—"; level: 3 }
    Grid {
        x: 8; y: 8
        columns: 4
        Repeater {
            model: root.items
            Item {
                id: slot
                required property var modelData
                width: 40; height: 40
                Rectangle { anchors.fill: parent; anchors.margins: 2; radius: Theme.radius; color: sm.containsMouse ? Theme.subtle : "transparent" }
                AppIcon { anchors.centerIn: parent; size: Theme.trayIcon; name: slot.modelData.icon }
                MouseArea {
                    id: sm
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    onClicked: e => {
                        if (e.button === Qt.RightButton || slot.modelData.onlyMenu) {
                            const p = slot.mapToItem(null, slot.width / 2, 0);
                            TrayMenus.show(slot.modelData, root.screenName, p.x, p.y);
                        } else if (e.button === Qt.MiddleButton) slot.modelData.secondaryActivate();
                        else { Flyouts.close(); slot.modelData.activate(); }
                    }
                }
                Tip { target: slot; hovered: sm.containsMouse; text: slot.modelData.tooltipTitle || slot.modelData.title || slot.modelData.id }
            }
        }
    }
}
