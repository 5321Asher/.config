import QtQuick
import Quickshell
import Quickshell.Bluetooth
import "../../theme"
import "../../widgets"
import "../../services"
import ".."

// II. Sendings: Wi-Fi (networks by strength; guarded ones ask for their key on the page), Bluetooth
// (the radio, familiar devices, strangers in range to pair) and Tailscale (up or down, the far gate
// (exit node), your kin: click one to copy its address).
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
    function strength(s) { return s >= 75 ? "strong" : s >= 50 ? "fair" : s >= 25 ? "faint" : "barely there"; }
    function bars(s) { return s >= 75 ? "\u{f0928}" : s >= 50 ? "\u{f0925}" : s >= 25 ? "\u{f0922}" : "\u{f091f}"; }

    Section {
        title: "wi-fi"
        trailing: Net.connecting ? "binding to " + Net.connecting + "…" : Net.scanning ? "listening…" : Net.ssid ? "bound to " + Net.ssid : ""
        Row {
            spacing: 10
            Seal { anchors.verticalCenter: parent.verticalCenter; checked: Net.wifiEnabled; onToggled: Net.toggleWifi() }
            Body { anchors.verticalCenter: parent.verticalCenter; italic: true; color: Theme.inkDim
                   text: Net.wifiEnabled ? "the radio is awake" + (Net.wifiDevice ? " · " + Net.wifiDevice : "") : "the radio sleeps" }
            Btn { visible: Net.wifiEnabled; text: "listen"; enabled: !Net.scanning; onClicked: Net.scan() }
        }
        Body { visible: Net.wifiError !== ""; width: parent.width; wrapMode: Text.Wrap; text: Net.wifiError; color: Theme.danger; italic: true }
        Repeater {
            model: Net.wifiEnabled ? Net.networks : []
            Column {
                id: net
                required property var modelData
                width: parent.width
                spacing: 4
                Row2 {
                    glyph: net.modelData.secure ? "\u{f033e}" : root.bars(net.modelData.signal)
                    title: net.modelData.ssid
                    subtitle: (net.modelData.secure ? "guarded" : "open") + (net.modelData.saved ? " · known" : "") + " · " + root.strength(net.modelData.signal)
                    active: net.modelData.inUse
                    trailing: net.modelData.inUse ? "bound" : Net.connecting === net.modelData.ssid ? "binding…" : ""
                    onClicked: {
                        if (net.modelData.inUse) return;
                        if (net.modelData.secure && !net.modelData.saved) root.asking = root.asking === net.modelData.ssid ? "" : net.modelData.ssid;
                        else Net.connect(net.modelData, "");
                    }
                    Btn { visible: net.modelData.inUse; text: "unbind"; onClicked: Net.disconnectWifi() }
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
                        placeholder: "the key to " + net.modelData.ssid
                        onVisibleChanged: if (visible) focusField()
                        onAccepted: { Net.connect(net.modelData, text); text = ""; root.asking = ""; }
                    }
                    Btn { text: "bind"; primary: true; onClicked: { Net.connect(net.modelData, pw.text); pw.text = ""; root.asking = ""; } }
                }
            }
        }
    }

    Section {
        title: "bluetooth"
        trailing: !root.adapter ? "no adapter" : root.adapter.discovering ? "seeking…" : ""
        Row {
            spacing: 10
            Seal { anchors.verticalCenter: parent.verticalCenter; enabled: !!root.adapter; checked: root.adapter?.enabled ?? false
                   onToggled: root.adapter.enabled = !root.adapter.enabled }
            Btn { visible: root.adapter?.enabled ?? false; text: root.adapter?.discovering ? "stop seeking" : "seek"
                  onClicked: root.adapter.discovering = !root.adapter.discovering }
        }
        Repeater {
            model: root.adapter?.enabled ? root.paired : []
            Row2 {
                required property var modelData
                glyph: "\u{f00af}"
                title: modelData.name
                subtitle: modelData.pairing ? "pairing…" : modelData.state === BluetoothDeviceState.Connecting ? "binding…"
                    : modelData.connected ? "bound" + (modelData.batteryAvailable ? " · " + Math.round(modelData.battery * 100) + "% charged" : "") : "familiar"
                active: modelData.connected
                onClicked: modelData.connected ? modelData.disconnect() : modelData.connect()
                Btn { text: "forget"; onClicked: modelData.forget() }
            }
        }
        Caps { visible: (root.adapter?.enabled ?? false) && root.nearby.length > 0; text: "strangers in range" }
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
        trailing: Net.tsBusy ? Net.tsBusy.toLowerCase() + "…" : !Net.tsAvailable ? "not installed" : Net.tsRunning ? Net.tsPeersOnline + " kin awake" : "down"
        Row {
            visible: Net.tsAvailable
            spacing: 10
            Seal { anchors.verticalCenter: parent.verticalCenter; enabled: !Net.tsBusy; checked: Net.tsRunning; onToggled: Net.toggleTailscale() }
            Body { anchors.verticalCenter: parent.verticalCenter; italic: true
                   text: Net.tsRunning ? (Net.tsName || "") + " · " + (root.copied === Net.tsIp ? "copied" : Net.tsIp) : "the gate is shut"
                   color: Net.tsRunning ? Theme.ink : Theme.inkDim
                   MouseArea { anchors.fill: parent; enabled: Net.tsRunning; cursorShape: Qt.PointingHandCursor; onClicked: root.copy(Net.tsIp) } }
        }
        Body { visible: Net.tsError !== ""; width: parent.width; wrapMode: Text.Wrap; text: Net.tsError; color: Theme.danger; italic: true }
        Flow {
            visible: Net.tsRunning && Net.tsExitNodes.length > 0
            width: parent.width
            spacing: 6
            Caps { height: 28; verticalAlignment: Text.AlignVCenter; text: "the far gate" }
            Btn { text: "none"; on: Net.tsExitNode === ""; onClicked: Net.setExitNode("") }
            Repeater {
                model: Net.tsExitNodes.filter(n => n.online && !n.mullvad)
                Btn { required property var modelData; text: modelData.name; on: Net.tsExitNode === modelData.ip; onClicked: Net.setExitNode(modelData.ip) }
            }
        }
        Row {
            visible: Net.tsRunning && Net.tsExitNode !== ""
            spacing: 10
            Seal { checked: Net.tsAllowLan; onToggled: Net.setAllowLan(!Net.tsAllowLan) }
            Body { anchors.verticalCenter: parent.verticalCenter; text: "let the near network through"; italic: true }
        }
        Repeater {
            model: Net.tsRunning ? Net.tsDevices : []
            Row2 {
                required property var modelData
                glyph: modelData.online ? "\u{f0765}" : "\u{f0766}"
                title: modelData.name
                subtitle: (root.copied === modelData.ip ? "copied" : modelData.ip) + " · " + (modelData.os || "").toLowerCase()
                trailing: modelData.online ? "awake" : "asleep"
                trailingColor: modelData.online ? Theme.green : Theme.inkDim
                onClicked: root.copy(modelData.ip)
            }
        }
    }
}
