import QtQuick
import Quickshell
import "../../theme"
import "../../widgets"
import "../../services"
import ".."

// VPN (Tailscale): connect, this device's address, the exit node, local network access, and
// your other devices (Copy their addresses).
Column {
    id: root
    spacing: 4
    property string note: ""
    Timer { id: noteReset; interval: 2000; onTriggered: root.note = "" }
    function copy(ip) { Net.copy(ip); note = "Copied " + ip; noteReset.restart(); }

    SettingRow {
        width: parent.width
        glyph: ""; title: "Tailscale"
        subtitle: !Net.tsAvailable ? "Tailscale isn't installed" : Net.tsBusy ? Net.tsBusy + "…" : Net.tsRunning ? "Connected as " + Net.tsName + " · " + Net.tsIp : "Disconnected"
        Row {
            spacing: 8
            Btn { visible: Net.tsRunning; text: "Copy address"; onClicked: root.copy(Net.tsIp) }
            Toggle { enabled: Net.tsAvailable && Net.tsBusy === ""; checked: Net.tsRunning; onToggled: Net.toggleTailscale() }
        }
    }
    SettingRow {
        visible: Net.tsRunning && Net.tsExitNodes.length > 0
        width: parent.width
        glyph: ""; title: "Exit node"; subtitle: "Send all your internet traffic through another device"
        Combo {
            width: 260
            readonly property var nodes: [{ name: "None", ip: "" }].concat(Net.tsExitNodes.filter(n => n.online && !n.mullvad))
            model: nodes
            textOf: n => n.name
            currentIndex: nodes.findIndex(n => n.ip === Net.tsExitNode)
            onChosen: i => Net.setExitNode(nodes[i].ip)
        }
    }
    SettingRow {
        visible: Net.tsRunning && Net.tsExitNode !== ""
        width: parent.width
        glyph: ""; title: "Allow local network access"
        Toggle { checked: Net.tsAllowLan; onToggled: Net.setAllowLan(!Net.tsAllowLan) }
    }
    Header { text: "Devices"; visible: Net.tsRunning }
    Repeater {
        model: Net.tsRunning ? Net.tsDevices : []
        SettingRow {
            required property var modelData
            width: root.width
            glyph: modelData.online ? "" : ""
            title: modelData.name
            subtitle: modelData.ip + (modelData.online ? " · online" : " · offline")
            Btn { text: "Copy"; onClicked: root.copy(modelData.ip) }
        }
    }
    Txt { visible: root.note !== ""; text: root.note; level: 2 }
    Txt { visible: Net.tsError !== ""; width: parent.width; wrapMode: Text.Wrap; color: Theme.danger; text: Net.tsError }
}
