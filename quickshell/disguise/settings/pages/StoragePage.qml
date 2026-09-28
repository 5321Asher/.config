import QtQuick
import Quickshell
import "../../theme"
import "../../widgets"
import "../../services"
import ".."

// Storage: every drive with a bar of how full it is; mount, unmount, eject, open in File Explorer.
Column {
    id: root
    spacing: 4
    Component.onCompleted: Devices.active = true
    Component.onDestruction: Devices.active = false

    Repeater {
        model: Devices.drives
        Card {
            id: drv
            required property var modelData
            readonly property real used: modelData.total > 0 ? modelData.used / modelData.total : 0
            width: root.width
            height: 96
            Glyph { x: 20; y: 22; g: modelData.removable ? "" : ""; size: 24 }
            Column {
                x: 64; y: 16
                width: parent.width - 340
                spacing: 4
                Txt { width: parent.width; text: drv.modelData.name + (drv.modelData.mounts.length ? " (" + drv.modelData.mounts[0] + ")" : ""); strong: true }
                Txt { text: drv.modelData.fstype + " · " + SysStats.bytes(drv.modelData.size, 0) + (drv.modelData.system ? " · System" : ""); level: 2; size: Theme.caption }
                Rectangle {
                    visible: drv.modelData.total > 0
                    width: parent.width; height: 6; radius: 3
                    color: Theme.subtle
                    Rectangle { width: parent.width * drv.used; height: parent.height; radius: 3; color: drv.used > 0.9 ? Theme.danger : Theme.accent }
                }
                Txt { visible: drv.modelData.total > 0; text: SysStats.bytes(drv.modelData.used, 0) + " used of " + SysStats.bytes(drv.modelData.total, 0); size: Theme.caption; level: 2 }
            }
            Row {
                anchors.right: parent.right; anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Btn { visible: !drv.modelData.mounts.length; text: "Mount"; enabled: Devices.udisks && Devices.busy === ""; onClicked: Devices.mount(drv.modelData) }
                Btn { visible: drv.modelData.mounts.length > 0 && !drv.modelData.system; text: "Unmount"; enabled: Devices.busy === ""; onClicked: Devices.unmount(drv.modelData) }
                Btn { visible: drv.modelData.removable && !drv.modelData.system; text: "Eject"; enabled: Devices.busy === ""; onClicked: Devices.eject(drv.modelData) }
                Btn { visible: drv.modelData.mounts.length > 0; text: "Open"; onClicked: Quickshell.execDetached(["thunar", drv.modelData.mounts[0]]) }
            }
        }
    }
    Txt { visible: Devices.error !== ""; width: parent.width; wrapMode: Text.Wrap; color: Theme.danger; text: Devices.error }
}
