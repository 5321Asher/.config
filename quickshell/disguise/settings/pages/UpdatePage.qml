import QtQuick
import Quickshell
import "../../theme"
import "../../widgets"
import "../../services"
import ".."

// Windows Update: pacman updates waiting (checkupdates), Check for updates, Install all (opens a
// terminal running the upgrade), and the vulnerability summary.
Column {
    id: root
    spacing: 4
    Card {
        width: parent.width
        height: 120
        Item {
            x: 24; width: 56; height: 56
            anchors.verticalCenter: parent.verticalCenter
            Glyph { anchors.centerIn: parent; g: ""; size: 44; color: Updates.pending > 0 ? Theme.accentLink : Theme.green
                    RotationAnimation on rotation { running: Updates.checking; from: 0; to: 360; duration: 1600; loops: Animation.Infinite } }
        }
        Column {
            x: 100
            anchors.verticalCenter: parent.verticalCenter
            Txt {
                size: Theme.subtitle; strong: true
                text: !Updates.pendingAvailable ? "Updates can't be checked" : Updates.checking ? "Checking for updates…"
                    : Updates.pending > 0 ? "Updates available" : "You're up to date"
            }
            Txt {
                level: 2
                text: !Updates.pendingAvailable ? "Install pacman-contrib (checkupdates)" : Updates.pending > 0 ? Updates.pending + " packages are ready to install"
                    : "Last checked: " + (Updates.auditAt ? Updates.ago() : "just now")
            }
        }
        Row {
            anchors.right: parent.right; anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Btn { text: Updates.checking ? "Checking…" : "Check for updates"; enabled: !Updates.checking; onClicked: Updates.sweep() }
            Btn { kind: "accent"; visible: Updates.pending > 0; text: "Install all"; onClicked: { SettingsApp.close(); Updates.update(); } }
        }
    }
    Header { text: "More options" }
    SettingRow {
        width: parent.width
        glyph: ""; title: "Security"
        subtitle: !Updates.auditAvailable ? "arch-audit isn't installed" : Updates.count === 0 ? "No known vulnerabilities" : Updates.count + " vulnerable packages (" + Updates.high + " high risk)"
        clickable: true
        onClicked: SettingsApp.go("security")
    }
    SettingRow { width: parent.width; glyph: ""; title: "Update history"; subtitle: "pacman's log"; clickable: true; chevron: ""
                 onClicked: Quickshell.execDetached(["kitty", "--hold", "sh", "-c", "grep -E 'upgraded|installed' /var/log/pacman.log | tail -60"]) }
}
