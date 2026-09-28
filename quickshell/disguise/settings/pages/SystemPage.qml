import QtQuick
import Quickshell
import "../../theme"
import "../../widgets"
import "../../services"
import ".."

// System: the device card, then the pages under it, with what each one is set to now.
Column {
    spacing: 4
    SysBits { id: sys }
    Card {
        width: parent.width
        height: 88
        Column {
            x: 20
            anchors.verticalCenter: parent.verticalCenter
            Txt { text: sys.host; size: Theme.subtitle; strong: true }
            Txt { text: sys.model || sys.os; level: 2 }
        }
        Row {
            anchors.right: parent.right; anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            spacing: 24
            Mini { glyph: ""; title: "Windows Update"; sub: Updates.pending > 0 ? Updates.pending + " available" : "Up to date"; onClicked: SettingsApp.go("update") }
        }
    }
    Item { width: 1; height: 8 }
    SettingRow { width: parent.width; glyph: ""; title: "Display"; subtitle: "Monitors, brightness, night light, display profile"; clickable: true; onClicked: SettingsApp.go("display") }
    SettingRow { width: parent.width; glyph: ""; title: "Sound"; subtitle: "Volume levels, output, input, sound devices"; clickable: true; onClicked: SettingsApp.go("sound") }
    SettingRow { width: parent.width; glyph: ""; title: "Notifications"; subtitle: "Alerts from apps and system, do not disturb"; clickable: true; onClicked: SettingsApp.go("notifications") }
    SettingRow { width: parent.width; glyph: ""; title: "Focus"; subtitle: "Focus sessions, pomodoro, timer"; clickable: true; onClicked: SettingsApp.go("focus") }
    SettingRow { width: parent.width; glyph: ""; title: "Power & battery"; subtitle: "Sleep, battery usage, stay awake"; clickable: true; onClicked: SettingsApp.go("power") }
    SettingRow { width: parent.width; glyph: ""; title: "Storage"; subtitle: "Drives, space, mount and eject"; clickable: true; onClicked: SettingsApp.go("storage") }
    SettingRow { width: parent.width; glyph: ""; title: "Task Manager"; subtitle: "Processor, memory, graphics, disks, network"; clickable: true; onClicked: SettingsApp.go("performance") }
    SettingRow { width: parent.width; glyph: ""; title: "About"; subtitle: "Device specifications, rename PC, Windows specifications"; clickable: true; onClicked: SettingsApp.go("about") }

    component Mini: Item {
        id: mini
        property string glyph
        property string title
        property string sub
        signal clicked()
        implicitWidth: miniRow.implicitWidth
        implicitHeight: miniRow.implicitHeight
        Row {
            id: miniRow
            spacing: 10
            Glyph { g: mini.glyph; size: 20; color: Theme.accentLink; anchors.verticalCenter: parent.verticalCenter }
            Column {
                Txt { text: mini.title; size: Theme.caption; strong: true }
                Txt { text: mini.sub; size: Theme.caption; level: 2 }
            }
        }
        MouseArea { anchors.fill: parent; onClicked: mini.clicked() }
    }
}
