import QtQuick
import Quickshell
import Quickshell.Bluetooth
import "../../theme"
import "../../widgets"
import "../../services"
import ".."

// Network Properties:
//   Wi-Fi       the networks in range (signal, security); Connect asks for a password in 98's
//               "Enter Network Password" box when the network needs one; Disconnect, Forget, Refresh
//   Bluetooth   the radio, your paired devices (connect, disconnect, forget) and devices in range (pair)
//   Tailscale   up / down, this machine's address, the exit node, your devices (select to copy an address)
// Wi-Fi and Tailscale go through services/Net.qml (nmcli, tailscale); Bluetooth through Quickshell.
Props {
    id: root

    title: "Network Properties"
    icon: "network-workgroup"
    tabs: ["Wi-Fi", "Bluetooth", "Tailscale"]

    Component.onCompleted: { Net.refresh(); if (Net.wifiEnabled) Net.scan(); }

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var btDevices: adapter?.devices.values ?? []
    readonly property var paired: btDevices.filter(d => d.paired || d.bonded)
        .sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))
    readonly property var nearby: btDevices.filter(d => !d.paired && !d.bonded && d.name && d.name !== d.address.replace(/:/g, "-"))

    property int wifiSel: 0
    readonly property var net: Net.networks[wifiSel] ?? null
    property var asking: null           // the network waiting for its password
    property int btSel: 0
    property int nearSel: -1
    property int tsSel: -1
    property string note: ""
    Timer { id: noteReset; interval: 2000; onTriggered: root.note = "" }

    function bars(sig) { return sig >= 75 ? "████" : sig >= 50 ? "███" : sig >= 25 ? "██" : "█"; }
    function connectSel() {
        const n = root.net;
        if (!n || n.inUse) return;
        if (n.secure && !n.saved) { root.asking = n; }
        else Net.connect(n, "");
    }

    // ---------------------------------------------------------------- Wi-Fi
    Item {
        Column {
            width: parent.width
            spacing: 8
            Row {
                spacing: 18
                Check { text: "Use Wi-Fi"; checked: Net.wifiEnabled; onToggled: Net.toggleWifi() }
                Txt {
                    height: 22
                    text: Net.connecting ? "Connecting to " + Net.connecting + "…" : Net.scanning ? "Looking for networks…"
                        : Net.ssid ? "Connected to " + Net.ssid : Net.wifiEnabled ? "Not connected" : ""
                }
            }
            Txt { text: "Networks in range:" }
            ListBox {
                width: parent.width
                height: 300
                enabled: Net.wifiEnabled
                model: Net.wifiEnabled ? Net.networks : []
                currentIndex: root.wifiSel
                onClicked: i => root.wifiSel = i
                onActivated: i => { root.wifiSel = i; root.connectSel(); }
                iconOf: n => n.inUse ? "network-wireless" : n.secure ? "network-wireless-encrypted" : "network-wireless"
                columns: [
                    { title: "Name", width: 0, text: n => n.ssid + (n.inUse ? "  (connected)" : "") },
                    { title: "Signal", width: 78, text: n => root.bars(n.signal) },
                    { title: "Security", width: 104, text: n => (n.secure ? "Secured" : "Open") + (n.saved ? " ✓" : "") },
                ]
            }
            Row {
                spacing: 6
                Btn { text: "Connect"; enabled: !!root.net && !root.net.inUse && Net.connecting === ""; onClicked: root.connectSel() }
                Btn { text: "Disconnect"; enabled: !!root.net?.inUse; onClicked: Net.disconnectWifi() }
                Btn { text: "Forget"; enabled: !!root.net?.saved; onClicked: Net.forget(root.net) }
                Btn { text: "Refresh"; enabled: Net.wifiEnabled && !Net.scanning; onClicked: Net.scan() }
            }
            Txt { visible: Net.wifiError !== ""; width: parent.width; wrapMode: Text.Wrap; color: Theme.danger; text: Net.wifiError }
        }

        // "Enter Network Password"
        Rectangle {
            anchors.fill: parent
            visible: root.asking !== null
            color: Theme.alpha(Theme.face, 0.6)
            MouseArea { anchors.fill: parent }
            Win {
                anchors.centerIn: parent
                width: 420
                height: 190
                title: "Enter Network Password"
                onCloseRequested: root.asking = null
                onVisibleChanged: if (visible) pw.focusField()
                Icon { x: 12; y: 12; name: "dialog-password"; fallback: "network-wireless-encrypted"; size: 40 }
                Column {
                    x: 66; y: 10
                    width: parent.width - 80
                    spacing: 8
                    Txt { width: parent.width; wrapMode: Text.Wrap; text: "Please enter the password for " + (root.asking?.ssid ?? "") + "." }
                    Row {
                        spacing: 8
                        Txt { height: Theme.field; text: "Password:" }
                        Field {
                            id: pw
                            width: 200
                            password: true
                            onAccepted: { Net.connect(root.asking, text); text = ""; root.asking = null; }
                        }
                    }
                }
                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    spacing: 8
                    Btn { text: "OK"; isDefault: true; onClicked: { Net.connect(root.asking, pw.text); pw.text = ""; root.asking = null; } }
                    Btn { text: "Cancel"; onClicked: { pw.text = ""; root.asking = null; } }
                }
            }
        }
    }

    // ---------------------------------------------------------------- Bluetooth
    Column {
        spacing: 8
        Row {
            spacing: 18
            Check {
                text: "Use Bluetooth"
                enabled: !!root.adapter
                checked: root.adapter?.enabled ?? false
                onToggled: root.adapter.enabled = !root.adapter.enabled
            }
            Txt { height: 22; text: !root.adapter ? "No Bluetooth adapter" : root.adapter.discovering ? "Looking for devices…" : "" }
        }
        Txt { text: "Your devices:" }
        ListBox {
            width: parent.width
            height: 150
            enabled: root.adapter?.enabled ?? false
            model: root.adapter?.enabled ? root.paired : []
            currentIndex: root.btSel
            onClicked: i => root.btSel = i
            onActivated: i => { const d = root.paired[i]; d.connected ? d.disconnect() : d.connect(); }
            iconOf: d => d.icon || "bluetooth"
            columns: [
                { title: "Name", width: 0, text: d => d.name },
                { title: "Status", width: 180, text: d => d.pairing ? "Pairing…" : d.state === BluetoothDeviceState.Connecting ? "Connecting…"
                    : d.connected ? "Connected" + (d.batteryAvailable ? ", " + Math.round(d.battery * 100) + "%" : "") : "Paired" },
            ]
        }
        Row {
            spacing: 6
            readonly property var d: root.paired[root.btSel] ?? null
            Btn { text: parent.d?.connected ? "Disconnect" : "Connect"; enabled: !!parent.d; onClicked: parent.d.connected ? parent.d.disconnect() : parent.d.connect() }
            Btn { text: "Forget"; enabled: !!parent.d; onClicked: parent.d.forget() }
        }
        Txt { text: "Devices in range:" }
        ListBox {
            width: parent.width
            height: 120
            enabled: root.adapter?.enabled ?? false
            model: root.adapter?.enabled ? root.nearby : []
            currentIndex: root.nearSel
            onClicked: i => root.nearSel = i
            onActivated: i => { root.nearby[i].trusted = true; root.nearby[i].pair(); }
            iconOf: d => d.icon || "bluetooth"
            textOf: d => d.name + (d.pairing ? "  (pairing…)" : "")
        }
        Row {
            spacing: 6
            Btn {
                text: root.adapter?.discovering ? "Stop Looking" : "Look for Devices"
                enabled: root.adapter?.enabled ?? false
                onClicked: root.adapter.discovering = !root.adapter.discovering
            }
            Btn {
                text: "Pair"
                readonly property var d: root.nearby[root.nearSel] ?? null
                enabled: !!d && !d.pairing
                onClicked: { d.trusted = true; d.pair(); }
            }
        }
    }

    // ---------------------------------------------------------------- Tailscale
    Column {
        spacing: 8
        Txt { visible: !Net.tsAvailable; text: "Tailscale isn't installed." }
        Row {
            visible: Net.tsAvailable
            spacing: 18
            Check { text: "Connected to Tailscale"; enabled: Net.tsBusy === ""; checked: Net.tsRunning; onToggled: Net.toggleTailscale() }
            Txt { height: 22; text: Net.tsBusy ? Net.tsBusy + "…" : "" }
        }
        Group {
            visible: Net.tsRunning
            title: "This computer"
            width: parent.width
            Txt { text: "Name:  " + (Net.tsName || "") }
            Row {
                spacing: 10
                Txt { height: Theme.button; text: "Address:  " + Net.tsIp }
                Btn { text: "Copy"; onClicked: { Net.copy(Net.tsIp); root.note = "Copied " + Net.tsIp; noteReset.restart(); } }
            }
        }
        Row {
            visible: Net.tsRunning && Net.tsExitNodes.length > 0
            spacing: 8
            Txt { height: Theme.field; text: "Exit node:" }
            Combo {
                width: 250
                readonly property var nodes: [{ name: "(None)", ip: "" }].concat(Net.tsExitNodes.filter(n => n.online && !n.mullvad))
                model: nodes
                textOf: n => n.name
                currentIndex: nodes.findIndex(n => n.ip === Net.tsExitNode)
                onChosen: i => Net.setExitNode(nodes[i].ip)
            }
        }
        Check {
            visible: Net.tsRunning && Net.tsExitNode !== ""
            text: "Allow local network access"
            checked: Net.tsAllowLan
            onToggled: Net.setAllowLan(!Net.tsAllowLan)
        }
        Txt { visible: Net.tsRunning; text: "Devices (double-click to copy the address):" }
        ListBox {
            visible: Net.tsRunning
            width: parent.width
            height: 170
            model: Net.tsRunning ? Net.tsDevices : []
            currentIndex: root.tsSel
            onClicked: i => root.tsSel = i
            onActivated: i => { const d = Net.tsDevices[i]; Net.copy(d.ip); root.note = "Copied " + d.ip; noteReset.restart(); }
            iconOf: d => d.online ? "computer" : "network-offline"
            columns: [
                { title: "Name", width: 0, text: d => d.name },
                { title: "Address", width: 130, text: d => d.ip },
                { title: "Status", width: 80, text: d => d.online ? "Online" : "Offline" },
            ]
        }
        Txt { visible: Net.tsError !== ""; width: parent.width; wrapMode: Text.Wrap; color: Theme.danger; text: Net.tsError }
        Txt { text: root.note }
    }
}
