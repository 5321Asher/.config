import QtQuick
import Quickshell
import Quickshell.Bluetooth
import "../../theme"
import "../../services"
import ".."

// Comms: Wi-Fi (networks by signal; secured ones ask for the password inline), Bluetooth (power,
// scan, pair, connect, forget) and Tailscale (connection, your devices, exit nodes, LAN access).
// Wi-Fi and Tailscale go through services/Net.qml (nmcli, tailscale); Bluetooth through Quickshell.
Column {
    id: root

    spacing: 22

    Component.onCompleted: { Net.refresh(); if (Net.wifiEnabled) Net.scan(); }
    Component.onDestruction: if (adapter?.discovering) adapter.discovering = false

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var btDevices: adapter?.devices.values ?? []
    readonly property var paired: btDevices.filter(d => d.paired || d.bonded)
        .sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))
    readonly property var nearby: btDevices.filter(d => !d.paired && !d.bonded && d.name && d.name !== d.address.replace(/:/g, "-"))

    property string asking: ""          // ssid waiting for a password
    property string copied: ""
    Timer { id: copiedReset; interval: 1500; onTriggered: root.copied = "" }
    function copy(text) { Net.copy(text); copied = text; copiedReset.restart(); }

    // signal strength as 1-4 bars
    function bars(s) { return s >= 75 ? 4 : s >= 50 ? 3 : s >= 25 ? 2 : 1; }

    // ---------------------------------------------------------------- wi-fi
    Section {
        title: "wi-fi"
        trailing: Net.connecting ? "connecting to " + Net.connecting : Net.scanning ? "scanning…" : Net.ssid ? "on " + Net.ssid : ""
        trailingColor: Net.connecting || Net.scanning ? Theme.phosphor : Theme.dim

        Item {
            width: parent.width
            height: 28
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Net.wifiEnabled ? (Net.wifiDevice ? "radio on · " + Net.wifiDevice : "radio on") : "radio off"
                color: Theme.fg
                font.family: Theme.fontData
                font.pixelSize: Theme.dataSizeSmall
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                Link { visible: Net.wifiEnabled; text: "scan"; enabled: !Net.scanning; onClicked: Net.scan() }
                Toggle { anchors.verticalCenter: parent.verticalCenter; checked: Net.wifiEnabled; onToggled: Net.toggleWifi() }
            }
        }
        Text {
            visible: Net.wifiError !== ""
            width: parent.width
            wrapMode: Text.Wrap
            text: Net.wifiError
            color: Theme.signal
            font.family: Theme.fontData
            font.pixelSize: Theme.dataSizeSmall
        }
        Repeater {
            model: Net.wifiEnabled ? Net.networks : []
            Column {
                id: net
                required property var modelData
                width: parent.width
                spacing: 4
                ListRow {
                    glyph: ["", "\u{f092f}", "\u{f091f}", "\u{f0922}", "\u{f0925}"][root.bars(net.modelData.signal)]
                    title: net.modelData.ssid
                    subtitle: (net.modelData.secure ? "secured" : "open") + (net.modelData.saved ? " · saved" : "") + " · " + net.modelData.signal + "%"
                    active: net.modelData.inUse
                    trailing: net.modelData.inUse ? "connected" : Net.connecting === net.modelData.ssid ? "connecting…" : ""
                    trailingColor: Theme.phosphor
                    onClicked: {
                        if (net.modelData.inUse) return;
                        if (net.modelData.secure && !net.modelData.saved) root.asking = root.asking === net.modelData.ssid ? "" : net.modelData.ssid;
                        else Net.connect(net.modelData, "");
                    }
                    Link { visible: net.modelData.inUse; text: "disconnect"; onClicked: Net.disconnectWifi() }
                    Link { visible: !!net.modelData.saved; text: "forget"; danger: true; onClicked: Net.forget(net.modelData) }
                }
                // password, inline
                Row {
                    visible: root.asking === net.modelData.ssid
                    x: 40
                    spacing: 8
                    Rectangle {
                        width: 240; height: 28; radius: 4
                        color: Theme.alpha(Theme.bgDark, 0.9)
                        border.width: 1
                        border.color: pw.activeFocus ? Theme.brassBright : Theme.border
                        Text {
                            anchors.left: parent.left; anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            visible: pw.text === ""
                            text: "password"
                            color: Theme.dim
                            font.family: Theme.fontData
                            font.pixelSize: Theme.dataSizeSmall
                        }
                        TextInput {
                            id: pw
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: TextInput.Password
                            color: Theme.phosphor
                            font.family: Theme.fontData
                            font.pixelSize: Theme.dataSize
                            onVisibleChanged: if (visible) forceActiveFocus()
                            onAccepted: { Net.connect(net.modelData, text); text = ""; root.asking = ""; }
                        }
                    }
                    Link { text: "connect"; primary: true; onClicked: { Net.connect(net.modelData, pw.text); pw.text = ""; root.asking = ""; } }
                }
            }
        }
    }

    // ---------------------------------------------------------------- bluetooth
    Section {
        title: "bluetooth"
        trailing: !root.adapter ? "no adapter" : root.adapter.discovering ? "scanning…" : root.adapter.enabled ? "visible as " + root.adapter.name : ""
        trailingColor: root.adapter?.discovering ? Theme.phosphor : Theme.dim

        Item {
            width: parent.width
            height: 28
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.adapter?.enabled ? "radio on" : "radio off"
                color: Theme.fg
                font.family: Theme.fontData
                font.pixelSize: Theme.dataSizeSmall
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                Link {
                    visible: root.adapter?.enabled ?? false
                    text: root.adapter?.discovering ? "stop" : "scan"
                    onClicked: root.adapter.discovering = !root.adapter.discovering
                }
                Toggle {
                    anchors.verticalCenter: parent.verticalCenter
                    enabled: !!root.adapter
                    checked: root.adapter?.enabled ?? false
                    onToggled: root.adapter.enabled = !root.adapter.enabled
                }
            }
        }
        Label { visible: root.adapter?.enabled ?? false; text: "paired" }
        Repeater {
            model: root.adapter?.enabled ? root.paired : []
            ListRow {
                required property var modelData
                icon: modelData.icon ?? ""
                glyph: "\u{f00af}"
                title: modelData.name
                subtitle: modelData.pairing ? "pairing…" : modelData.state === BluetoothDeviceState.Connecting ? "connecting…"
                    : modelData.connected ? "connected" + (modelData.batteryAvailable ? " · battery " + Math.round(modelData.battery * 100) + "%" : "") : "paired"
                active: modelData.connected
                onClicked: modelData.connected ? modelData.disconnect() : modelData.connect()
                Link { text: modelData.connected ? "disconnect" : "connect"; onClicked: modelData.connected ? modelData.disconnect() : modelData.connect() }
                Link { text: "forget"; danger: true; onClicked: modelData.forget() }
            }
        }
        Label { visible: (root.adapter?.enabled ?? false) && root.nearby.length > 0; text: "in range" }
        Repeater {
            model: root.adapter?.enabled ? root.nearby : []
            ListRow {
                required property var modelData
                icon: modelData.icon ?? ""
                glyph: "\u{f00af}"
                title: modelData.name
                subtitle: modelData.address
                Link {
                    text: modelData.pairing ? "pairing…" : "pair"
                    enabled: !modelData.pairing
                    onClicked: { modelData.trusted = true; modelData.pair(); }
                }
            }
        }
        Text {
            visible: (root.adapter?.enabled ?? false) && root.nearby.length === 0 && !root.adapter.discovering
            text: "scan to find devices in range"
            color: Theme.dim
            font.family: Theme.fontData
            font.pixelSize: Theme.dataSizeSmall
        }
    }

    // ---------------------------------------------------------------- tailscale
    Section {
        title: "tailscale"
        trailing: Net.tsBusy ? Net.tsBusy.toLowerCase() + "…" : !Net.tsAvailable ? "not installed" : Net.tsRunning ? Net.tsPeersOnline + " online" : "down"
        trailingColor: Net.tsBusy ? Theme.phosphor : Theme.dim

        Item {
            width: parent.width
            height: 30
            visible: Net.tsAvailable
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    text: Net.tsName || "tailscale"
                    color: Theme.fg
                    font.family: Theme.fontData
                    font.pixelSize: Theme.dataSize
                }
                Text {
                    text: Net.tsRunning ? (root.copied === Net.tsIp ? "copied" : Net.tsIp + " · click to copy") : "disconnected"
                    color: root.copied === Net.tsIp ? Theme.phosphor : Theme.dim
                    font.family: Theme.fontData
                    font.pixelSize: Theme.dataSizeSmall
                    MouseArea { anchors.fill: parent; enabled: Net.tsRunning; cursorShape: Qt.PointingHandCursor; onClicked: root.copy(Net.tsIp) }
                }
            }
            Toggle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                enabled: !Net.tsBusy
                checked: Net.tsRunning
                onToggled: Net.toggleTailscale()
            }
        }
        Text {
            visible: Net.tsError !== ""
            width: parent.width
            wrapMode: Text.Wrap
            text: Net.tsError
            color: Theme.signal
            font.family: Theme.fontData
            font.pixelSize: Theme.dataSizeSmall
        }
        Label { visible: Net.tsRunning; text: "devices" }
        Repeater {
            model: Net.tsRunning ? Net.tsDevices : []
            ListRow {
                required property var modelData
                glyph: modelData.online ? "\u{f0765}" : "\u{f0766}"
                title: modelData.name
                subtitle: (root.copied === modelData.ip ? "copied" : modelData.ip) + " · " + (modelData.os || "").toLowerCase()
                trailing: modelData.online ? "online" : "offline"
                trailingColor: modelData.online ? Theme.phosphor : Theme.dim
                onClicked: root.copy(modelData.ip)
            }
        }
        Label { visible: Net.tsRunning && Net.tsExitNodes.length > 0; text: "exit node" }
        Flow {
            visible: Net.tsRunning && Net.tsExitNodes.length > 0
            width: parent.width
            spacing: 6
            Link { text: "none"; mono: true; primary: Net.tsExitNode === ""; onClicked: Net.setExitNode("") }
            Repeater {
                model: Net.tsExitNodes.filter(n => n.online && !n.mullvad)
                Link {
                    required property var modelData
                    mono: true
                    text: modelData.name
                    primary: Net.tsExitNode === modelData.ip
                    onClicked: Net.setExitNode(modelData.ip)
                }
            }
        }
        Item {
            visible: Net.tsRunning && Net.tsExitNode !== ""
            width: parent.width
            height: 28
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "allow local network while using an exit node"
                color: Theme.fg
                font.family: Theme.fontData
                font.pixelSize: Theme.dataSizeSmall
            }
            Toggle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                checked: Net.tsAllowLan
                onToggled: Net.setAllowLan(!Net.tsAllowLan)
            }
        }
    }

    component Label: Text {
        color: Theme.brass
        font.family: Theme.fontLabel
        font.pixelSize: Theme.labelSize - 1
        font.capitalization: Font.SmallCaps
        font.letterSpacing: Theme.labelSpacing
        font.weight: Font.DemiBold
    }
}
