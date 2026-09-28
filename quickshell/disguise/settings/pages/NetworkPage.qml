import QtQuick
import Quickshell
import "../../theme"
import "../../widgets"
import "../../services"
import ".."

// Network & internet: the connection card, Wi-Fi (on/off, the networks: connect with a password
// right in the row, disconnect, forget), and VPN.
Column {
    id: root
    spacing: 4
    Component.onCompleted: { Net.refresh(); if (Net.wifiEnabled) Net.scan(); }
    property string asking: ""

    Card {
        width: parent.width
        height: 96
        Glyph { x: 24; anchors.verticalCenter: parent.verticalCenter; g: Net.ssid ? "" : ""; size: 36 }
        Column {
            x: 84
            anchors.verticalCenter: parent.verticalCenter
            Txt { text: Net.ssid || (Net.wifiEnabled ? "Not connected" : "Wi-Fi is off"); size: Theme.subtitle; strong: true }
            Txt { text: Net.ssid ? "Connected, secured" + (Net.tsRunning ? " · Tailscale on" : "") : "Pick a network below"; level: 2 }
        }
    }
    SettingRow {
        width: parent.width
        glyph: ""; title: "Wi-Fi"; subtitle: Net.connecting ? "Connecting to " + Net.connecting + "…" : Net.scanning ? "Looking for networks…" : ""
        Row {
            spacing: 8
            Btn { kind: "subtle"; glyph: ""; width: 36; enabled: Net.wifiEnabled && !Net.scanning; onClicked: Net.scan() }
            Toggle { checked: Net.wifiEnabled; onToggled: Net.toggleWifi() }
        }
    }
    Repeater {
        model: Net.wifiEnabled ? Net.networks : []
        Card {
            id: nrow
            required property var modelData
            readonly property bool open: root.asking === modelData.ssid
            width: root.width
            height: open ? 112 : 60
            Glyph {
                x: 20; y: 20
                readonly property int s: nrow.modelData.signal
                g: s >= 75 ? "" : s >= 50 ? "" : s >= 25 ? "" : ""
                size: 18
            }
            Column {
                x: 56; y: 12
                Txt { text: nrow.modelData.ssid; strong: nrow.modelData.inUse }
                Txt { text: (nrow.modelData.inUse ? "Connected, " : "") + (nrow.modelData.secure ? "secured" : "open") + (nrow.modelData.saved && !nrow.modelData.inUse ? " · saved" : ""); size: Theme.caption; level: 2 }
            }
            Row {
                visible: !nrow.open
                anchors.right: parent.right; anchors.rightMargin: 16
                y: 14
                spacing: 6
                Btn { visible: nrow.modelData.saved; kind: "subtle"; text: "Forget"; onClicked: Net.forget(nrow.modelData) }
                Btn {
                    kind: nrow.modelData.inUse ? "standard" : "accent"
                    text: nrow.modelData.inUse ? "Disconnect" : "Connect"
                    enabled: Net.connecting === ""
                    onClicked: {
                        if (nrow.modelData.inUse) Net.disconnectWifi();
                        else if (nrow.modelData.secure && !nrow.modelData.saved) { root.asking = nrow.modelData.ssid; pw.focusField(); }
                        else Net.connect(nrow.modelData, "");
                    }
                }
            }
            Row {
                visible: nrow.open
                x: 56; y: 64
                spacing: 8
                Field { id: pw; width: 280; password: true; placeholder: "Enter the network security key"
                        onAccepted: { Net.connect(nrow.modelData, text); text = ""; root.asking = ""; } }
                Btn { kind: "accent"; text: "Next"; onClicked: { Net.connect(nrow.modelData, pw.text); pw.text = ""; root.asking = ""; } }
                Btn { text: "Cancel"; onClicked: { pw.text = ""; root.asking = ""; } }
            }
        }
    }
    Txt { visible: Net.wifiError !== ""; width: parent.width; wrapMode: Text.Wrap; color: Theme.danger; text: Net.wifiError }
    Header { text: "More" }
    SettingRow { width: parent.width; glyph: ""; title: "VPN"; subtitle: Net.tsRunning ? "Tailscale · connected" : "Tailscale"; clickable: true; onClicked: SettingsApp.open("vpn") }
}
