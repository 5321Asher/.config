import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "../../theme"
import "../../widgets"
import "../../services"
import ".."

// Power & battery: the battery, Stay awake (no dimming, locking or sleep while on), the idle timers
// as hypridle has them, and the power buttons (from the shared Power menu).
Column {
    id: root
    spacing: 4
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery?.isLaptopBattery ?? false
    readonly property real pct: !battery ? 0 : battery.percentage > 1 ? battery.percentage : battery.percentage * 100
    readonly property bool charging: battery?.state === UPowerDeviceState.Charging
    property var idle: []
    Process {
        running: true
        command: ["sh", "-c", "grep -E '^\\s*timeout\\s*=' \"$HOME/.config/hypr/hypridle.conf\" | grep -oE '[0-9]+'"]
        stdout: StdioCollector { onStreamFinished: root.idle = text.split("\n").filter(l => l).map(Number) }
    }
    function mins(s) { return !s ? "—" : s >= 60 ? Math.round(s / 60) + " minute" + (s >= 120 ? "s" : "") : s + " seconds"; }
    function hm(s) { const h = Math.floor(s / 3600), m = Math.round(s % 3600 / 60); return (h ? h + " hr " : "") + m + " min"; }
    property var power: []
    Component.onCompleted: Elephant.query("menus:power", l => root.power = l)

    Card {
        visible: root.hasBattery
        width: parent.width
        height: 110
        Glyph { x: 24; anchors.verticalCenter: parent.verticalCenter; g: String.fromCharCode((root.charging ? 0xebab : 0xeba0) + Math.round(root.pct / 10)); size: 40 }
        Column {
            x: 90
            anchors.verticalCenter: parent.verticalCenter
            Txt { text: Math.round(root.pct) + "%"; size: Theme.title; strong: true }
            Txt {
                level: 2
                text: root.charging ? "Charging" + (root.battery.timeToFull > 0 ? " · full in " + root.hm(root.battery.timeToFull) : "")
                    : root.battery?.state === UPowerDeviceState.FullyCharged ? "Fully charged"
                    : (root.battery?.timeToEmpty > 0 ? "About " + root.hm(root.battery.timeToEmpty) + " left" : "On battery")
            }
        }
    }
    Header { text: "Power"; topPadding: root.hasBattery ? 16 : 0 }
    SettingRow {
        width: parent.width
        glyph: ""; title: "Stay awake"; subtitle: "Don't dim, lock or turn off the screen while this is on"
        Toggle { checked: StayAwake.on; onToggled: StayAwake.on = !StayAwake.on }
    }
    SettingRow { width: parent.width; glyph: ""; title: "Dim the screen after"; subtitle: "Set in hypridle.conf"
        Txt { height: 32; text: StayAwake.on ? "Never" : root.mins(root.idle[0]); level: 2 } }
    SettingRow { width: parent.width; glyph: ""; title: "Lock after"
        Txt { height: 32; text: StayAwake.on ? "Never" : root.mins(root.idle[1]); level: 2 } }
    SettingRow { width: parent.width; glyph: ""; title: "Turn off the screen after"
        Txt { height: 32; text: StayAwake.on ? "Never" : root.mins(root.idle[2]); level: 2 } }

    Header { text: "Shut down or sign out" }
    Card {
        width: parent.width
        height: 72
        Row {
            x: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Repeater {
                model: root.power
                Btn {
                    required property var modelData
                    readonly property string t: (modelData.text ?? "").toLowerCase()
                    glyph: t.includes("lock") ? "" : t.includes("suspend") ? "" : t.includes("log") ? "" : t.includes("reboot") ? "" : ""
                    text: t.includes("lock") ? "Lock" : t.includes("suspend") ? "Sleep" : t.includes("log") ? "Sign out" : t.includes("reboot") ? "Restart" : t.includes("shut") ? "Shut down" : modelData.text
                    onClicked: Elephant.activate(modelData)
                }
            }
        }
    }
}
