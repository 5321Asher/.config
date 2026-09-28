import QtQuick
import Quickshell
import "../theme"
import "../widgets"
import "../services"

// VULN WATCH 脆弱性: packages with known vulnerabilities (arch-audit): the count, by severity,
// and the worst of them with their CVE count and whether an update fixes them yet. SWEEP re-scans
// (and re-checks for updates); FIX READY rows open a terminal to update.
Panel {
    id: root

    title: "VULN WATCH"
    jp: "脆弱性"

    readonly property int minsAgo: Status.auditAt ? Math.floor((clock.date - Status.auditAt) / 60000) : -1
    SystemClock { id: clock; precision: SystemClock.Minutes }

    Column {
        width: parent.width
        spacing: 10

        Text {
            visible: !Status.auditAvailable
            width: parent.width
            wrapMode: Text.Wrap
            text: "ARCH-AUDIT NOT INSTALLED  //  pacman -S arch-audit"
            color: Theme.yellow
            font.family: Theme.mono
            font.pixelSize: Theme.label
        }

        Row {
            visible: Status.auditAvailable
            spacing: 22
            Text {
                text: Status.vulnCount
                color: Status.vulnCount > 0 ? Theme.red : Theme.cyan
                font.family: Theme.display
                font.pixelSize: 46
                font.weight: Font.Bold
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Label { text: "PACKAGES AFFECTED"; strong: true; color: Theme.fg }
                Row {
                    spacing: 12
                    Label { anchors.verticalCenter: parent.verticalCenter
                            text: "arch-audit  //  " + (root.minsAgo < 0 ? "syncing" : "synced " + root.minsAgo + " min ago") }
                    Btn { text: "SWEEP"; onClicked: Status.sweep() }
                }
            }
        }

        Row {
            visible: Status.auditAvailable
            width: parent.width
            spacing: 8
            Repeater {
                model: [["HIGH", Status.vulnHigh, Theme.red], ["MED", Status.vulnBySeverity.Medium ?? 0, Theme.yellow],
                        ["LOW", Status.vulnBySeverity.Low ?? 0, Theme.dim]]
                Item {
                    required property var modelData
                    width: (parent.width - 16) / 3
                    height: 26
                    Rectangle {
                        anchors.fill: parent
                        color: modelData[1] > 0 ? Theme.alpha(modelData[2], 0.14) : "transparent"
                        border.width: 1
                        border.color: modelData[1] > 0 ? modelData[2] : Theme.line
                    }
                    Label { anchors.centerIn: parent; text: modelData[0] + "   " + modelData[1]; color: modelData[1] > 0 ? modelData[2] : Theme.dim; strong: true }
                }
            }
        }

        Label {
            visible: Status.auditAvailable
            readonly property int waiting: Status.vulns.filter(v => !v.fix).length
            text: waiting + " AWAITING UPSTREAM  //  " + (Status.vulnCount - waiting) + " FIX READY"
        }
        Rectangle { visible: Status.auditAvailable; width: parent.width; height: 1; color: Theme.line }

        Repeater {
            model: Status.vulns.slice(0, 4)
            Item {
                required property var modelData
                width: parent.width
                height: 18
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 6; height: 6
                            color: modelData.severity === "Critical" || modelData.severity === "High" ? Theme.red
                                 : modelData.severity === "Medium" ? Theme.yellow : Theme.dim }
                Text {
                    x: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.name
                    color: Theme.fg
                    font.family: Theme.mono
                    font.pixelSize: Theme.data - 1
                }
                Label { x: 150; anchors.verticalCenter: parent.verticalCenter; text: modelData.type; width: parent.width - 330; elide: Text.ElideRight }
                Label { anchors.right: fixLabel.left; anchors.rightMargin: 24; anchors.verticalCenter: parent.verticalCenter; text: modelData.cves + " CVE" }
                Label {
                    id: fixLabel
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 72
                    horizontalAlignment: Text.AlignRight
                    text: modelData.fix ? "FIX READY" : "NO FIX"
                    color: modelData.fix ? Theme.cyan : Theme.dim
                    MouseArea { anchors.fill: parent; enabled: modelData.fix; cursorShape: Qt.PointingHandCursor
                                onClicked: Quickshell.execDetached(["kitty", "-e", "sh", "-c", "sudo pacman -Syu; echo; read -p 'done. enter to close '"]) }
                }
            }
        }
        Label { visible: Status.vulnCount > 4; text: "+" + (Status.vulnCount - 4) + " MORE" }
    }
}
