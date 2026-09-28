import QtQuick
import Quickshell
import Quickshell.Bluetooth
import "../../theme"
import "../../widgets"
import "../../services"
import ".."

// 02 COMMS 通信: Wi-Fi (networks by signal; secured ones ask for the key inline), Bluetooth
// (radio, paired devices, devices in range to pair) and Tailscale (up/down, exit node, devices:
// click one to copy its address).
Column {
    id: root

    spacing: 22
    Component.onCompleted: { Net.refresh(); if (Net.wifiEnabled) Net.scan(); }

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var btDevices: adapter?.devices.values ?? []
    readonly property var paired: btDevices.filter(d => d.paired || d.bonded).sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))
    readonly property var nearby: btDevices.filter(d => !d.paired && !d.bonded && d.name && d.name !== d.address.replace(/:/g, "-"))

    property string asking: ""
    property string copied: ""
    Timer { id: copiedReset; interval: 1500; onTriggered: root.copied = "" }
    function copy(t) { Net.copy(t); copied = t; copiedReset.restart(); }
    function bars(s) { return s >= 75 ? "▮▮▮▮" : s >= 50 ? "▮▮▮▯" : s >= 25 ? "▮▮▯▯" : "▮▯▯▯"; }

    Section {
        title: "wi-fi"
        jp: "無線"
        trailing: Net.connecting ? "linking " + Net.connecting : Net.scanning ? "scanning…" : Net.ssid ? "on " + Net.ssid : ""
        trailingColor: Net.connecting || Net.scanning ? Theme.cyan : Theme.dim
        Row {
            spacing: 10
            Switch { anchors.verticalCenter: parent.verticalCenter; checked: Net.wifiEnabled; onToggled: Net.toggleWifi() }
            Label { anchors.verticalCenter: parent.verticalCenter; text: Net.wifiEnabled ? "radio on" + (Net.wifiDevice ? "  //  " + Net.wifiDevice : "") : "radio off" }
            Btn { visible: Net.wifiEnabled; text: "scan"; enabled: !Net.scanning; onClicked: Net.scan() }
        }
        Label { visible: Net.wifiError !== ""; width: parent.width; wrapMode: Text.Wrap; text: Net.wifiError; color: Theme.red }
        Repeater {
            model: Net.wifiEnabled ? Net.networks : []
            Column {
                id: net
                required property var modelData
                width: parent.width
                spacing: 4
                Row2 {
                    glyph: net.modelData.secure ? "\u{f033e}" : "\u{f05a9}"
                    title: net.modelData.ssid
                    subtitle: (net.modelData.secure ? "secured" : "open") + (net.modelData.saved ? " // saved" : "") + " // " + root.bars(net.modelData.signal)
                    active: net.modelData.inUse
                    trailing: net.modelData.inUse ? "linked" : Net.connecting === net.modelData.ssid ? "linking…" : ""
                    trailingColor: Theme.cyan
                    onClicked: {
                        if (net.modelData.inUse) return;
                        if (net.modelData.secure && !net.modelData.saved) root.asking = root.asking === net.modelData.ssid ? "" : net.modelData.ssid;
                        else Net.connect(net.modelData, "");
                    }
                    Btn { visible: net.modelData.inUse; text: "drop"; onClicked: Net.disconnectWifi() }
                    Btn { visible: !!net.modelData.saved; text: "forget"; onClicked: Net.forget(net.modelData) }
                }
                Row {
                    visible: root.asking === net.modelData.ssid
                    spacing: 8
                    x: 36
                    Field {
                        id: pw
                        width: root.width - 150
                        password: true
                        placeholder: "key for " + net.modelData.ssid
                        onVisibleChanged: if (visible) focusField()
                        onAccepted: { Net.connect(net.modelData, text); text = ""; root.asking = ""; }
                    }
                    Btn { text: "link"; primary: true; onClicked: { Net.connect(net.modelData, pw.text); pw.text = ""; root.asking = ""; } }
                }
            }
        }
    }

    Section {
        title: "bluetooth"
        jp: "近距離"
        trailing: !root.adapter ? "no adapter" : root.adapter.discovering ? "scanning…" : ""
        Row {
            spacing: 10
            Switch { anchors.verticalCenter: parent.verticalCenter; enabled: !!root.adapter; checked: root.adapter?.enabled ?? false
                     onToggled: root.adapter.enabled = !root.adapter.enabled }
            Btn { visible: root.adapter?.enabled ?? false; text: root.adapter?.discovering ? "stop" : "scan"
                  onClicked: root.adapter.discovering = !root.adapter.discovering }
        }
        Repeater {
            model: root.adapter?.enabled ? root.paired : []
            Row2 {
                required property var modelData
                glyph: "\u{f00af}"
                title: modelData.name
                subtitle: modelData.pairing ? "pairing…" : modelData.state === BluetoothDeviceState.Connecting ? "linking…"
                    : modelData.connected ? "linked" + (modelData.batteryAvailable ? " // battery " + Math.round(modelData.battery * 100) + "%" : "") : "paired"
                active: modelData.connected
                onClicked: modelData.connected ? modelData.disconnect() : modelData.connect()
                Btn { text: "forget"; onClicked: modelData.forget() }
            }
        }
        Label { visible: (root.adapter?.enabled ?? false) && root.nearby.length > 0; text: "in range" }
        Repeater {
            model: root.adapter?.enabled ? root.nearby : []
            Row2 {
                required property var modelData
                glyph: "\u{f00b1}"
                title: modelData.name
                Btn { text: modelData.pairing ? "pairing…" : "pair"; enabled: !modelData.pairing; onClicked: { modelData.trusted = true; modelData.pair(); } }
            }
        }
    }

    Section {
        title: "tailscale"
        jp: "私設網"
        trailing: Net.tsBusy ? Net.tsBusy.toLowerCase() + "…" : !Net.tsAvailable ? "not installed" : Net.tsRunning ? Net.tsPeersOnline + " online" : "down"
        Row {
            visible: Net.tsAvailable
            spacing: 10
            Switch { anchors.verticalCenter: parent.verticalCenter; enabled: !Net.tsBusy; checked: Net.tsRunning; onToggled: Net.toggleTailscale() }
            Label { anchors.verticalCenter: parent.verticalCenter; text: Net.tsRunning ? (Net.tsName || "") + "  //  " + (root.copied === Net.tsIp ? "copied" : Net.tsIp) : "disconnected"
                    color: Net.tsRunning ? Theme.cyan : Theme.dim
                    MouseArea { anchors.fill: parent; enabled: Net.tsRunning; cursorShape: Qt.PointingHandCursor; onClicked: root.copy(Net.tsIp) } }
        }
        Label { visible: Net.tsError !== ""; width: parent.width; wrapMode: Text.Wrap; text: Net.tsError; color: Theme.red }
        Flow {
            visible: Net.tsRunning && Net.tsExitNodes.length > 0
            width: parent.width
            spacing: 6
            Label { height: 26; text: "exit node" }
            Btn { text: "none"; on: Net.tsExitNode === ""; onClicked: Net.setExitNode("") }
            Repeater {
                model: Net.tsExitNodes.filter(n => n.online && !n.mullvad)
                Btn { required property var modelData; text: modelData.name; on: Net.tsExitNode === modelData.ip; onClicked: Net.setExitNode(modelData.ip) }
            }
        }
        Row {
            visible: Net.tsRunning && Net.tsExitNode !== ""
            spacing: 10
            Switch { checked: Net.tsAllowLan; onToggled: Net.setAllowLan(!Net.tsAllowLan) }
            Label { text: "allow local network" }
        }
        Repeater {
            model: Net.tsRunning ? Net.tsDevices : []
            Row2 {
                required property var modelData
                glyph: modelData.online ? "\u{f0765}" : "\u{f0766}"
                title: modelData.name
                subtitle: (root.copied === modelData.ip ? "copied" : modelData.ip) + " // " + (modelData.os || "").toLowerCase()
                trailing: modelData.online ? "online" : "offline"
                trailingColor: modelData.online ? Theme.cyan : Theme.dim
                onClicked: root.copy(modelData.ip)
            }
        }
    }
}
