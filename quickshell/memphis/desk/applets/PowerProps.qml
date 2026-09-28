import QtQuick
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../widgets"
import "../../services"
import ".."

// Power Management Properties:
//   Power Schemes   98's scheme list: "Home/Office Desk" (the idle timers as hypridle has them) or
//                   "Always On" (Stay awake: no dimming, locking or sleep)
//   Shut Down       lock, stand by, log off, restart, shut down
Props {
    id: root

    title: "Power Management Properties"
    icon: "preferences-system-power"
    tabs: ["Power Schemes", "Shut Down"]

    // hypridle's timeouts, for the scheme's "Turn off monitors: after …" lines
    property var idle: []
    Process {
        running: true
        command: ["sh", "-c", "grep -E '^\\s*timeout\\s*=' \"$HOME/.config/hypr/hypridle.conf\" | grep -oE '[0-9]+'"]
        stdout: StdioCollector { onStreamFinished: root.idle = text.split("\n").filter(l => l).map(Number) }
    }
    function mins(s) { return s >= 60 ? "After " + Math.round(s / 60) + " min" + (s >= 120 ? "s" : "") : "After " + s + " secs"; }

    // ---------------------------------------------------------------- Power Schemes
    Column {
        spacing: 10
        Row {
            spacing: 12
            Icon { name: "preferences-system-power"; size: 40 }
            Txt { width: 380; wrapMode: Text.Wrap; text: "Select the power scheme with the most appropriate settings for this computer." }
        }
        Txt { text: "Power schemes" }
        Combo {
            width: parent.width
            model: ["Home/Office Desk", "Always On"]
            currentIndex: StayAwake.on ? 1 : 0
            onChosen: i => StayAwake.on = i === 1
        }
        Group {
            title: "Settings for " + (StayAwake.on ? "Always On" : "Home/Office Desk") + " power scheme"
            width: parent.width
            Repeater {
                model: [["Dim the screen:", 0], ["Lock the computer:", 1], ["Turn off monitors:", 2]]
                Row {
                    required property var modelData
                    spacing: 10
                    Txt { width: 170; height: Theme.field; text: modelData[0] }
                    Combo {
                        width: 200
                        enabled: false
                        model: [StayAwake.on ? "Never" : root.idle[modelData[1]] ? root.mins(root.idle[modelData[1]]) : "—"]
                        currentIndex: 0
                    }
                }
            }
            Txt { width: parent.width; wrapMode: Text.Wrap; color: Theme.grayText; text: "The times come from ~/.config/hypr/hypridle.conf." }
        }
    }

    // ---------------------------------------------------------------- Shut Down
    Column {
        spacing: 8
        Txt { text: "What do you want the computer to do?" }
        Repeater {
            model: [
                ["Lock the computer", "system-lock-screen", ["loginctl", "lock-session"]],
                ["Stand by", "system-suspend", ["systemctl", "suspend"]],
            ]
            Row {
                required property var modelData
                spacing: 10
                Icon { name: modelData[1]; size: 32; anchors.verticalCenter: parent.verticalCenter }
                Btn {
                    text: modelData[0]
                    implicitWidth: 240
                    align: Qt.AlignLeft
                    onClicked: { root.closeRequested(); Quickshell.execDetached(modelData[2]); }
                }
            }
        }
        Row {
            spacing: 10
            Icon { name: "system-log-out"; size: 32; anchors.verticalCenter: parent.verticalCenter }
            Btn { text: "Log off…"; implicitWidth: 240; align: Qt.AlignLeft; onClicked: Desk.show("logoff") }
        }
        Row {
            spacing: 10
            Icon { name: "system-shutdown"; size: 32; anchors.verticalCenter: parent.verticalCenter }
            Btn { text: "Restart or shut down…"; implicitWidth: 240; align: Qt.AlignLeft; onClicked: Desk.show("shutdown") }
        }
    }
}
