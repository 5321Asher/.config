import QtQuick
import Quickshell
import Quickshell.Bluetooth
import "../../theme"
import "../../widgets"
import "../../services"
import ".."

// Settings' Home: this device (its wallpaper, its name), three status cards (Wi-Fi, Windows
// Update, Bluetooth), recommended settings, and your themes to pick from.
Column {
    id: root
    spacing: 4
    property var info: ({})
    Component.onCompleted: Look.refresh()

    // the device
    Card {
        width: parent.width
        height: 150
        Row {
            x: 20
            anchors.verticalCenter: parent.verticalCenter
            spacing: 20
            Rectangle {
                width: 180; height: 104; radius: Theme.radiusLarge
                color: Theme.desktop
                clip: true
                Image {
                    anchors.fill: parent
                    anchors.margins: 3
                    source: Look.wallNow && !Look.isVideo(Look.wallNow) ? "file://" + Look.wallNow : ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 360
                    asynchronous: true
                }
                border.width: 3
                border.color: Theme.dark ? "#1a1a1a" : "#2b2b2b"
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Txt { text: Quickshell.env("HOSTNAME") || sys.host; size: Theme.subtitle; strong: true }
                Txt { text: sys.model; level: 2 }
                Btn { text: "Rename"; enabled: false }
            }
        }
        SysBits { id: sys }
    }

    Row {
        width: parent.width
        spacing: 8
        StatusCard {
            glyph: ""; title: Net.ssid || (Net.wifiEnabled ? "Not connected" : "Wi-Fi is off")
            sub: Net.ssid ? "Connected, secured" : "Network & internet"
            onClicked: SettingsApp.go("network")
        }
        StatusCard {
            glyph: ""; title: Updates.pending > 0 ? Updates.pending + " updates available" : "You're up to date"
            sub: "Windows Update"
            onClicked: SettingsApp.go("update")
        }
        StatusCard {
            readonly property var dev: (Bluetooth.defaultAdapter?.devices.values ?? []).find(d => d.connected)
            glyph: ""; title: dev?.name ?? (Bluetooth.defaultAdapter?.enabled ? "No devices connected" : "Bluetooth is off")
            sub: "Bluetooth & devices"
            onClicked: SettingsApp.go("bluetooth")
        }
    }

    Header { text: "Recommended settings" }
    SettingRow { width: parent.width; glyph: ""; title: "Display"; subtitle: "Brightness, resolution, arrangement"; clickable: true; onClicked: SettingsApp.go("display") }
    SettingRow { width: parent.width; glyph: ""; title: "Sound"; subtitle: "Volume levels, output, input, sound devices"; clickable: true; onClicked: SettingsApp.go("sound") }
    SettingRow { width: parent.width; glyph: ""; title: "Notifications"; subtitle: "Alerts from apps, do not disturb"; clickable: true; onClicked: SettingsApp.go("notifications") }

    Header { text: "Personalize your device" }
    Card {
        width: parent.width
        height: themeFlow.height + 32
        Flow {
            id: themeFlow
            x: 16; y: 16
            width: parent.width - 32
            spacing: 12
            Repeater {
                model: Look.themes
                ThemeChip { required property var modelData; theme: modelData }
            }
        }
    }

    component StatusCard: Card {
        id: sc
        property string glyph
        property string title
        property string sub
        signal clicked()
        width: (root.width - 16) / 3
        height: 96
        color: m.containsMouse ? Theme.cardHover : Theme.card
        Glyph { x: 16; y: 18; g: sc.glyph; size: 20; color: Theme.accentLink }
        Column {
            x: 16; y: 48
            width: parent.width - 32
            Txt { width: parent.width; text: sc.title; strong: true }
            Txt { width: parent.width; text: sc.sub; size: Theme.caption; level: 2 }
        }
        MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; onClicked: sc.clicked() }
    }
}
