import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"
import "../widgets"
import "../services"
import "../rig"

// SYS.DIAG システム診断: host and uplink, the profile, every CPU thread as a bar, load, temperature
// and clock; memory as blocks; the network trace (up in red, down in cyan); the daemons (ping,
// shield, trace, ICE, SSH); and a footer with ICE, uptime, pending packages and the kernel.
Panel {
    id: root

    title: "SYS.DIAG"
    jp: "システム診断"
    big: true
    brackets: true

    readonly property var d: SysStats.data
    Component.onCompleted: SysStats.active = true

    property int uptime: 0
    FileView { id: up; path: "/proc/uptime"; printErrors: false }
    Timer { running: true; repeat: true; interval: 1000; triggeredOnStart: true
            onTriggered: { up.reload(); root.uptime = Math.floor(parseFloat(up.text()) || 0); } }
    function hms(s) { return [Math.floor(s / 3600), Math.floor(s % 3600 / 60), s % 60].map(n => String(n).padStart(2, "0")).join(":"); }
    function rate(b) { return b >= 1048576 ? (b / 1048576).toFixed(1) + " MB/s" : (b / 1024).toFixed(1) + " KB/s"; }

    Column {
        width: parent.width
        spacing: 12

        Label { text: "HOST " + Status.host + "  //  UPLINK " + (Net.ssid || SysStats.data?.net?.iface || "offline") }
        Hazard { width: 96; height: 10 }
        Rectangle { width: parent.width; height: 1; color: Theme.line }

        Label { text: "PROFILE  //  " + (Status.profile || "—") }

        // CPU: a bar per thread
        Label { text: "CPU  //  " + (root.d?.cpu?.name ?? "") }
        Item {
            width: parent.width
            height: 50
            Row {
                anchors.fill: parent
                spacing: 0
                Repeater {
                    model: root.d?.cpu?.threads ?? []
                    Item {
                        required property var modelData
                        width: parent.width / Math.max(1, (root.d?.cpu?.threads ?? []).length)
                        height: parent.height
                        Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 2; height: parent.height; color: Theme.alpha(Theme.dim, 0.25) }
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            width: 2
                            height: Math.max(2, parent.height * modelData / 100)
                            color: modelData > 85 ? Theme.red : Theme.cyan
                            Behavior on height { NumberAnimation { duration: Theme.normal } }
                        }
                    }
                }
            }
        }
        Item {
            width: parent.width
            height: 16
            Row { spacing: 6; Label { text: "LOAD" } Label { text: Math.round(root.d?.cpu?.usage ?? 0) + "%"; color: Theme.cyan } }
            Row { anchors.horizontalCenter: parent.horizontalCenter; spacing: 6
                  Label { text: "TEMP" } Label { text: Math.round(root.d?.cpu?.temp ?? 0) + "°C"; color: SysStats.tempColor(root.d?.cpu?.temp ?? 0) } }
            Row { anchors.right: parent.right; spacing: 6
                  Label { text: "FREQ" } Label { text: (root.d?.cpu?.freq ?? 0).toFixed(2) + " GHZ"; color: Theme.cyan } }
        }

        // memory
        Item {
            width: parent.width
            height: 16
            Label { text: "MEM  //  " + (root.d ? (root.d.mem.used / 1073741824).toFixed(1) + " / " + (root.d.mem.total / 1073741824).toFixed(1) + " GB" : "") }
            Label { anchors.right: parent.right; text: root.d ? Math.round(root.d.mem.used / root.d.mem.total * 100) + "%" : ""; strong: true }
        }
        Blocks {
            count: 26
            blockWidth: (parent.width - 25 * 2) / 26
            blockHeight: 10
            value: root.d ? root.d.mem.used / root.d.mem.total : 0
        }

        // network trace
        Label { text: "NET  //  " + (root.d?.net?.iface ?? "") }
        Item {
            width: parent.width
            height: 60
            Spark { anchors.fill: parent; values: SysStats.txHistory; color: Theme.red; base: Theme.alpha(Theme.red, 0.5); points: 60 }
            Spark { anchors.fill: parent; values: SysStats.rxHistory; color: Theme.cyan; points: 60 }
        }
        Item {
            width: parent.width
            height: 16
            Row { spacing: 6; Label { text: "▲ UP" } Label { text: root.rate(root.d?.net?.tx ?? 0); color: Theme.red } }
            Row { anchors.right: parent.right; spacing: 6; Label { text: "▼ DOWN" } Label { text: root.rate(root.d?.net?.rx ?? 0); color: Theme.cyan } }
        }

        // daemons
        Row { spacing: 8; Label { text: "DAEMONS  //  LOADED" } Jp { text: "常駐" } }
        Repeater {
            model: [
                ["PING", Status.ping >= 0 ? Status.ping + " MS" : "NO UPLINK", Status.ping >= 0 ? Theme.cyan : Theme.red],
                ["SHIELD", Status.shield || "NONE", Status.shield ? Theme.cyan : Theme.yellow],
                ["TRACE", Net.tsExitNode ? "VIA " + Net.tsExitNode : Net.tsRunning ? "TAILNET" : "NO PROXY", Theme.fg],
                ["ICE", Status.ice, Status.ice === "NOMINAL" ? Theme.cyan : Status.ice === "BREACHED" ? Theme.red : Theme.yellow],
                ["SSH", Status.ssh ? "ON" : "OFF", Status.ssh ? Theme.yellow : Theme.fg],
            ]
            Item {
                required property var modelData
                width: parent.width
                height: 16
                Label { text: modelData[0] }
                Label { anchors.right: parent.right; text: modelData[1]; color: modelData[2] }
            }
        }
    }

    // footer
    Column {
        anchors.bottom: parent.bottom
        width: parent.width
        spacing: 8
        Item {
            width: parent.width
            height: 16
            Row {
                spacing: 6
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 7; height: 7
                            color: Status.ice === "NOMINAL" ? Theme.cyan : Status.ice === "BREACHED" ? Theme.red : Theme.yellow }
                Label { text: "ICE  //  " + Status.ice + "   " + Status.failedUnits + " FAILED"; strong: true }
            }
            Label { anchors.right: parent.right; text: "UPTIME " + root.hms(root.uptime) }
        }
        Item {
            width: parent.width
            height: 16
            // a strip of barcode, as on the reference
            Row {
                spacing: 1
                Repeater {
                    model: 26
                    Rectangle { required property int index; width: [1, 2, 1, 3][(index * 7) % 4]; height: 14; color: Theme.dim }
                }
            }
            Label { anchors.right: parent.right; text: Status.pkgAvailable ? "PKG  //  " + Status.pkgPending + " PENDING" : "PKG  //  NO FEED" }
        }
        Label { anchors.right: parent.right; text: "KRN " + Status.kernel; color: Theme.alpha(Theme.dim, 0.8) }
    }

    MouseArea { anchors.fill: parent; z: -1; onClicked: RigState.toggleTo("telemetry") }
}
