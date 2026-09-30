import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Widgets
import "../theme"
import "../widgets"
import "../services"
import "../settings"

// Quick Settings (Windows + A): what's playing, on its own card above; then the tiles (Wi-Fi,
// Bluetooth and VPN open their lists with the chevron), brightness and volume, and the battery
// and Settings along the bottom. Pages slide in for Wi-Fi, Bluetooth, VPN (Tailscale) and sound
// output (with the volume mixer), as they do on Windows.
Item {
    id: root

    required property string screenName
    property bool active: false
    property string page: ""                    // "" | wifi | bluetooth | vpn | sound
    onActiveChanged: if (active) { page = Flyouts.opts.page ?? ""; Net.refresh(); }
    onPageChanged: if (page === "wifi" && Net.wifiEnabled) Net.scan()

    implicitHeight: (media.visible ? media.height + 12 : 0) + main.height

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream)
    // Track every stream, then filter: a node's properties (media.class) only arrive once it's tracked
    readonly property var allStreams: Pipewire.nodes.values.filter(n => n.audio && n.isStream)
    readonly property var streams: allStreams.filter(n => n.properties?.["media.class"] === "Stream/Output/Audio")
    PwObjectTracker { objects: [root.sink].filter(n => n).concat(root.sinks, root.allStreams) }
    readonly property var players: Mpris.players.values.filter(p => !p.dbusName.includes("playerctld"))
    readonly property var player: players.find(p => p.isPlaying) ?? players[0] ?? null
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery?.isLaptopBattery ?? false
    readonly property real batteryPct: !battery ? 0 : battery.percentage > 1 ? battery.percentage : battery.percentage * 100

    function open(p) { page = p; }
    function settings(id) { Flyouts.close(); SettingsApp.open(id); }

    // ---------------------------------------------------------------- media (its own card)
    Acrylic {
        id: media
        visible: root.player !== null
        width: parent.width
        height: 128
        Item {
            anchors.fill: parent
            anchors.margins: 16
            ClippingRectangle {
                id: art
                width: 64; height: 64
                radius: Theme.radius
                color: Theme.subtle
                Image { anchors.fill: parent; source: root.player?.trackArtUrl ?? ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 128 }
                Glyph { anchors.centerIn: parent; visible: !(root.player?.trackArtUrl); g: ""; size: 24; color: Theme.text2 }
            }
            Column {
                x: art.width + 12
                width: parent.width - x
                Txt { width: parent.width; text: root.player?.trackTitle || "Unknown title"; strong: true }
                Txt { width: parent.width; text: root.player?.trackArtist ?? ""; level: 2; size: Theme.caption }
                Txt { width: parent.width; text: root.player?.identity ?? ""; level: 3; size: Theme.caption }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                spacing: 8
                Btn { kind: "subtle"; glyph: ""; width: 40; enabled: !!root.player?.canGoPrevious; onClicked: root.player.previous() }
                Btn { kind: "subtle"; glyph: root.player?.isPlaying ? "" : ""; width: 40; onClicked: root.player.togglePlaying() }
                Btn { kind: "subtle"; glyph: ""; width: 40; enabled: !!root.player?.canGoNext; onClicked: root.player.next() }
            }
        }
    }

    // ---------------------------------------------------------------- the main card
    Acrylic {
        id: main
        y: media.visible ? media.height + 12 : 0
        width: parent.width
        height: (root.page === "" ? home.height + 40 : 420) + 48
        Behavior on height { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
        clip: true

        // ---------------------------------------------------- tiles and sliders
        Column {
            id: home
            x: 20; y: 20
            width: parent.width - 40
            spacing: 0
            opacity: root.page === "" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.fast } }

            Grid {
                id: tiles
                columns: 3
                columnSpacing: 12
                rowSpacing: 4
                Tile {
                    glyph: Net.wifiEnabled ? "\ue701" : "\ueb5d"
                    label: Net.ssid || "Wi-Fi"
                    on: Net.wifiEnabled
                    split: true
                    onToggled: Net.toggleWifi()
                    onMore: root.open("wifi")
                }
                Tile {
                    glyph: ""
                    label: (root.adapter?.devices.values ?? []).find(d => d.connected)?.name ?? "Bluetooth"
                    on: root.adapter?.enabled ?? false
                    enabled: !!root.adapter
                    split: true
                    onToggled: root.adapter.enabled = !root.adapter.enabled
                    onMore: root.open("bluetooth")
                }
                Tile {
                    glyph: ""
                    label: Net.tsRunning ? (Net.tsExitNode ? "VPN · exit node" : "Tailscale") : "VPN"
                    on: Net.tsRunning
                    enabled: Net.tsAvailable && Net.tsBusy === ""
                    split: true
                    onToggled: Net.toggleTailscale()
                    onMore: root.open("vpn")
                }
                Tile { glyph: ""; label: "Do not disturb"; on: Notifs.dnd; onToggled: Notifs.dnd = !Notifs.dnd }
                Tile { glyph: ""; label: "Stay awake"; on: StayAwake.on; onToggled: StayAwake.on = !StayAwake.on }
                Tile { glyph: ""; label: "Dynamic lighting"; on: Rgb.followWallpaper; enabled: Rgb.available || !Rgb.scanned; onToggled: Rgb.setFollowWallpaper(!Rgb.followWallpaper) }
                Tile { glyph: ""; label: "Snip"; onToggled: { Flyouts.close(); snipLater.restart(); } }
                Tile { glyph: ""; label: Capture.recording ? Capture.elapsedText : "Record"; on: Capture.recording; onToggled: { Flyouts.close(); recLater.restart(); } }
                Tile { glyph: ""; label: "Voice typing"; on: Voxtype.recording; enabled: Voxtype.available; onToggled: Voxtype.toggle() }
            }
            Item { width: 1; height: 16 }
            Column {
                id: sliders
                width: parent.width
                // brightness: the laptop panel, else the first monitor that takes it over DDC/CI
                Row {
                    visible: Backlight.available || Brightness.displays.length > 0
                    height: 48
                    spacing: 8
                    Glyph { width: 40; anchors.verticalCenter: parent.verticalCenter; g: ""; size: 16 }
                    Slider {
                        width: home.width - 48
                        anchors.verticalCenter: parent.verticalCenter
                        value: Backlight.available ? Backlight.value : (Brightness.displays[0]?.value ?? 0)
                        onMoved: v => Backlight.available ? Backlight.set(v) : Brightness.set(0, v)
                    }
                }
                Row {
                    height: 48
                    spacing: 8
                    Btn {
                        kind: "subtle"; width: 40; height: 40
                        anchors.verticalCenter: parent.verticalCenter
                        readonly property real v: root.sink?.audio?.volume ?? 0
                        glyph: root.sink?.audio?.muted ? "" : v > 0.66 ? "" : v > 0.33 ? "" : v > 0 ? "" : ""
                        onClicked: if (root.sink?.audio) root.sink.audio.muted = !root.sink.audio.muted
                    }
                    Slider {
                        width: home.width - 96
                        anchors.verticalCenter: parent.verticalCenter
                        value: root.sink?.audio?.volume ?? 0
                        onMoved: v => { if (root.sink?.audio) { root.sink.audio.volume = v; root.sink.audio.muted = false; } }
                    }
                    Btn { kind: "subtle"; width: 40; height: 40; anchors.verticalCenter: parent.verticalCenter; glyph: ""; glyphSize: 12; onClicked: root.open("sound") }
                }
            }
        }

        // ---------------------------------------------------- pages
        Item {
            id: pageArea
            x: 0; y: 0
            width: parent.width
            height: 420
            visible: root.page !== ""
            opacity: root.page !== "" ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.fast } }

            Row {
                x: 12; y: 12
                spacing: 4
                Btn { kind: "subtle"; glyph: ""; width: 36; height: 36; onClicked: root.page = "" }
                Txt {
                    height: 36
                    strong: true
                    text: ({ wifi: "Wi-Fi", bluetooth: "Bluetooth", vpn: "VPN", sound: "Sound output" })[root.page] ?? ""
                }
            }
            Toggle {
                visible: root.page === "wifi" || root.page === "bluetooth" || root.page === "vpn"
                anchors.right: parent.right; anchors.rightMargin: 20
                y: 20
                showState: false
                checked: root.page === "wifi" ? Net.wifiEnabled : root.page === "bluetooth" ? (root.adapter?.enabled ?? false) : Net.tsRunning
                onToggled: root.page === "wifi" ? Net.toggleWifi() : root.page === "bluetooth" ? (root.adapter.enabled = !root.adapter.enabled) : Net.toggleTailscale()
            }

            Scroll {
                x: 12; y: 60
                width: parent.width - 24
                height: parent.height - 60 - 44

                // Wi-Fi: the networks; the chosen one opens to ask for a password or connect
                Column {
                    visible: root.page === "wifi"
                    width: parent.width
                    spacing: 2
                    Txt { visible: !Net.wifiEnabled; x: 12; height: 40; text: "Wi-Fi is turned off"; level: 2 }
                    Txt { visible: Net.wifiEnabled && Net.networks.length === 0; x: 12; height: 40; text: Net.scanning ? "Looking for networks…" : "No networks found"; level: 2 }
                    Repeater {
                        model: Net.wifiEnabled ? Net.networks : []
                        NetRow {}
                    }
                    Txt { visible: Net.wifiError !== ""; x: 12; width: parent.width - 24; wrapMode: Text.Wrap; color: Theme.danger; text: Net.wifiError; size: Theme.caption }
                }

                // Bluetooth: your devices (click to connect / disconnect), then new ones in range
                Column {
                    visible: root.page === "bluetooth"
                    width: parent.width
                    spacing: 2
                    readonly property var devs: (root.adapter?.devices.values ?? []).filter(d => d.name && d.name !== d.address.replace(/:/g, "-"))
                    Txt { visible: !(root.adapter?.enabled ?? false); x: 12; height: 40; text: "Bluetooth is turned off"; level: 2 }
                    Repeater {
                        model: root.adapter?.enabled ? parent.devs.filter(d => d.paired || d.bonded) : []
                        PageRow {
                            required property var modelData
                            glyph: ""
                            title: modelData.name
                            sub: modelData.connected ? "Connected" + (modelData.batteryAvailable ? " · " + Math.round(modelData.battery * 100) + "%" : "")
                                : modelData.state === BluetoothDeviceState.Connecting ? "Connecting…" : "Paired"
                            lit: modelData.connected
                            onClicked: modelData.connected ? modelData.disconnect() : modelData.connect()
                        }
                    }
                    Txt { visible: root.adapter?.enabled ?? false; x: 12; height: 36; text: root.adapter?.discovering ? "Looking for new devices…" : "New devices"; strong: true; size: Theme.caption }
                    Repeater {
                        model: root.adapter?.enabled ? parent.devs.filter(d => !d.paired && !d.bonded) : []
                        PageRow {
                            required property var modelData
                            glyph: ""
                            title: modelData.name
                            sub: modelData.pairing ? "Pairing…" : "Select to pair"
                            onClicked: { modelData.trusted = true; modelData.pair(); }
                        }
                    }
                }

                // VPN: the Tailscale connection, its exit nodes (None = straight out; offline ones
                // greyed), local network access while one is in use, and your devices (select one to
                // copy its address)
                Column {
                    visible: root.page === "vpn"
                    width: parent.width
                    spacing: 2
                    Txt { visible: !Net.tsAvailable; x: 12; height: 40; text: "Tailscale isn't installed"; level: 2 }
                    PageRow {
                        visible: Net.tsAvailable
                        glyph: "\ue705"
                        title: "Tailscale"
                        sub: Net.tsBusy ? Net.tsBusy + "…" : Net.tsRunning ? "Connected · " + (Net.tsName ? Net.tsName + " · " : "") + Net.tsIp : "Not connected · select to connect"
                        lit: Net.tsRunning
                        onClicked: Net.toggleTailscale()
                    }
                    Txt { visible: Net.tsError !== ""; x: 12; width: parent.width - 24; wrapMode: Text.Wrap; color: Theme.danger; text: Net.tsError; size: Theme.caption }

                    Txt { visible: Net.tsRunning; x: 12; height: 36; verticalAlignment: Text.AlignBottom; text: "Exit node"; strong: true; size: Theme.caption }
                    Repeater {
                        model: Net.tsRunning ? [{ name: "None", ip: "", online: true, city: "" }].concat(Net.tsExitNodes.filter(n => !n.mullvad || n.ip === Net.tsExitNode)) : []
                        PageRow {
                            required property var modelData
                            glyph: modelData.ip === "" ? "\ue774" : "\ue909"
                            title: modelData.name
                            sub: modelData.ip === Net.tsExitNode ? (modelData.ip === "" ? "In use · straight to the internet" : "In use · traffic goes through " + (modelData.host ?? modelData.name))
                                : !modelData.online ? "Offline"
                                : modelData.ip === "" ? "Straight to the internet" : modelData.ip
                            lit: modelData.ip === Net.tsExitNode
                            opacity: modelData.online ? 1 : 0.5
                            onClicked: if (modelData.online && modelData.ip !== Net.tsExitNode) Net.setExitNode(modelData.ip)
                        }
                    }
                    Txt {
                        visible: Net.tsRunning && Net.tsExitNodes.length === 0
                        x: 44; width: parent.width - 56; wrapMode: Text.Wrap; level: 2; size: Theme.caption
                        text: "No device on your tailnet offers itself as an exit node"
                    }
                    PageRow {
                        visible: Net.tsRunning && Net.tsExitNode !== ""
                        glyph: "\ue839"
                        title: "Allow local network access"
                        sub: Net.tsAllowLan ? "On · printers and other devices here stay reachable" : "Off"
                        lit: Net.tsAllowLan
                        onClicked: Net.setAllowLan(!Net.tsAllowLan)
                    }

                    Txt { visible: Net.tsRunning && Net.tsDevices.length > 0; x: 12; height: 36; verticalAlignment: Text.AlignBottom; text: "Devices · " + Net.tsPeersOnline + " online"; strong: true; size: Theme.caption }
                    Repeater {
                        model: Net.tsRunning ? Net.tsDevices : []
                        PageRow {
                            required property var modelData
                            glyph: modelData.os === "windows" ? "\ue7f8" : modelData.os === "android" || modelData.os === "iOS" ? "\ue8ea" : "\ue977"
                            title: modelData.name
                            sub: copied ? "Address copied" : (modelData.online ? "Online · " : "Offline · ") + modelData.ip
                            opacity: modelData.online ? 1 : 0.6
                            property bool copied: false
                            Timer { id: copiedTimer; interval: 1500; onTriggered: parent.copied = false }
                            onClicked: { Quickshell.execDetached(["wl-copy", modelData.ip]); copied = true; copiedTimer.restart(); }
                        }
                    }
                }

                // Sound output: the devices, then each app's volume (the mixer)
                Column {
                    visible: root.page === "sound"
                    width: parent.width
                    spacing: 2
                    Repeater {
                        model: root.sinks
                        PageRow {
                            required property var modelData
                            glyph: (modelData.description ?? "").toLowerCase().includes("head") ? "" : ""
                            title: modelData.nickname || modelData.description || modelData.name
                            lit: modelData === root.sink
                            onClicked: Pipewire.preferredDefaultAudioSink = modelData
                        }
                    }
                    Txt { visible: root.streams.length > 0; x: 12; height: 40; text: "Volume mixer"; strong: true; size: Theme.caption }
                    Repeater {
                        model: root.streams
                        Item {
                            required property var modelData
                            width: parent.width; height: 48
                            AppIcon { x: 12; anchors.verticalCenter: parent.verticalCenter; size: 20
                                      name: modelData.properties?.["application.icon-name"] || (modelData.properties?.["application.name"] ?? "").toLowerCase() }
                            Txt { x: 44; width: 90; height: parent.height; size: Theme.caption; text: modelData.properties?.["application.name"] || modelData.name }
                            Slider { x: 140; width: parent.width - 150; anchors.verticalCenter: parent.verticalCenter
                                     value: modelData.audio?.volume ?? 0; onMoved: v => { if (modelData.audio) modelData.audio.volume = v; } }
                        }
                    }
                }
            }

            // "More … settings", as Windows ends each page
            Btn {
                x: 20
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 6
                kind: "subtle"
                textColor: Theme.accentLink
                text: ({ wifi: "More Wi-Fi settings", bluetooth: "More Bluetooth settings", vpn: "More VPN settings", sound: "More volume settings" })[root.page] ?? ""
                padding: 8
                onClicked: root.settings(({ wifi: "network", bluetooth: "bluetooth", vpn: "vpn", sound: "sound" })[root.page])
            }
            Btn {
                visible: root.page === "wifi" || root.page === "bluetooth"
                anchors.right: parent.right; anchors.rightMargin: 16
                anchors.bottom: parent.bottom; anchors.bottomMargin: 6
                kind: "subtle"; glyph: ""; width: 36
                onClicked: root.page === "wifi" ? Net.scan() : (root.adapter.discovering = !root.adapter.discovering)
            }
        }

        // ---------------------------------------------------- the bottom strip
        Item {
            id: strip
            y: parent.height - 48
            width: parent.width
            height: 48
            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                color: Theme.dark ? Qt.alpha("#000000", 0.18) : Qt.alpha("#000000", 0.03)
                bottomLeftRadius: Theme.radiusLarge - 1
                bottomRightRadius: Theme.radiusLarge - 1
            }
            Rectangle { width: parent.width; height: 1; color: Theme.divider }
            Btn {
                visible: root.hasBattery
                x: 12; anchors.verticalCenter: parent.verticalCenter
                kind: "subtle"
                height: 36
                padding: 10
                readonly property bool charging: root.battery?.state === UPowerDeviceState.Charging || root.battery?.state === UPowerDeviceState.FullyCharged
                glyph: String.fromCharCode((charging ? 0xebab : 0xeba0) + Math.round(root.batteryPct / 10))
                text: Math.round(root.batteryPct) + "%"
                onClicked: root.settings("power")
            }
            Row {
                anchors.right: parent.right; anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Btn { kind: "subtle"; glyph: ""; width: 36; height: 36; onClicked: root.settings("notifications") }
                Btn { kind: "subtle"; glyph: ""; width: 36; height: 36; onClicked: root.settings("home") }
            }
        }
    }
    Timer { id: snipLater; interval: 250; onTriggered: Capture.screenshot("region") }
    Timer { id: recLater; interval: 250; onTriggered: Capture.toggleRecording() }

    // ---------------------------------------------------------------- pieces
    // A tile: a 96 x 48 button, the accent when on; split tiles have a chevron half that opens a page
    component Tile: Column {
        id: tile
        property string glyph
        property string label
        property bool on: false
        property bool split: false
        signal toggled()
        signal more()
        width: 96
        spacing: 6
        opacity: enabled ? 1 : 0.45
        Item {
            width: 96; height: 48
            Rectangle {
                anchors.fill: parent
                radius: Theme.radius
                color: tile.on ? (leftMouse.pressed ? Theme.accentPressed : leftMouse.containsMouse || rightMouse.containsMouse ? Theme.accentHover : Theme.accent)
                     : (leftMouse.pressed ? Theme.controlPressed : leftMouse.containsMouse || rightMouse.containsMouse ? Theme.controlHover : Theme.control)
                border.width: tile.on ? 0 : 1
                border.color: Theme.controlStroke
            }
            Glyph {
                x: tile.split ? 0 : 0
                width: tile.split ? 60 : parent.width
                height: parent.height
                g: tile.glyph
                color: tile.on ? Theme.accentText : Theme.text
            }
            Rectangle { visible: tile.split; x: 60; y: 12; width: 1; height: 24; color: tile.on ? Qt.alpha(Theme.accentText, 0.3) : Theme.controlStroke }
            Glyph {
                visible: tile.split
                x: 61; width: 35; height: parent.height
                g: ""; size: 12
                color: tile.on ? Theme.accentText : Theme.text
            }
            MouseArea { id: leftMouse; width: tile.split ? 60 : parent.width; height: parent.height; hoverEnabled: true; onClicked: tile.toggled() }
            MouseArea { id: rightMouse; visible: tile.split; x: 60; width: 36; height: parent.height; hoverEnabled: true; onClicked: tile.more() }
        }
        Txt { width: 96; horizontalAlignment: Text.AlignHCenter; text: tile.label; size: Theme.caption }
        Item { width: 1; height: 6 }
    }

    // A row on a page: icon, name, a line under it; lit = the accent pill (connected, chosen)
    component PageRow: Item {
        id: pr
        property string glyph
        property string title
        property string sub: ""
        property bool lit: false
        signal clicked()
        width: parent ? parent.width : 300
        height: sub ? 52 : 44
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Theme.radius
            color: pm.pressed ? Theme.subtle2 : pm.containsMouse || pr.lit ? Theme.subtle : "transparent"
            Rectangle { visible: pr.lit; width: 3; height: 16; radius: 1.5; anchors.verticalCenter: parent.verticalCenter; color: Theme.accent }
        }
        Glyph { x: 14; anchors.verticalCenter: parent.verticalCenter; g: pr.glyph; size: 16 }
        Column {
            x: 44
            width: parent.width - 56
            anchors.verticalCenter: parent.verticalCenter
            Txt { width: parent.width; text: pr.title }
            Txt { visible: pr.sub !== ""; width: parent.width; text: pr.sub; size: Theme.caption; level: 2 }
        }
        MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; onClicked: pr.clicked() }
    }

    // A Wi-Fi network: signal bars, name, "Secured" / "Connected, secured"; selected, it opens to
    // Connect (asking for the password in place when it needs one) or Disconnect
    component NetRow: Item {
        id: nr
        required property var modelData
        readonly property bool expanded: open === modelData.ssid
        width: parent ? parent.width : 300
        height: expanded ? (asking ? 148 : 100) : 52
        property bool asking: false
        Behavior on height { NumberAnimation { duration: Theme.fast } }
        clip: true
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Theme.radius
            color: nr.expanded || nm.containsMouse || nr.modelData.inUse ? Theme.subtle : "transparent"
            Rectangle { visible: nr.modelData.inUse; y: 18; width: 3; height: 16; radius: 1.5; color: Theme.accent }
        }
        Glyph {
            x: 14; y: 14
            readonly property int s: nr.modelData.signal
            g: s >= 75 ? "" : s >= 50 ? "" : s >= 25 ? "" : ""
            size: 16
            Glyph { visible: nr.modelData.secure; x: 8; y: 8; g: ""; size: 8 }
        }
        Column {
            x: 44; y: 8
            width: parent.width - 56
            Txt { width: parent.width; text: nr.modelData.ssid }
            Txt {
                width: parent.width; size: Theme.caption; level: 2
                text: Net.connecting === nr.modelData.ssid ? "Connecting…" : (nr.modelData.inUse ? "Connected, " : "") + (nr.modelData.secure ? "secured" : "open")
            }
        }
        MouseArea { id: nm; width: parent.width; height: 52; hoverEnabled: true; onClicked: { root.openNet = nr.expanded ? "" : nr.modelData.ssid; nr.asking = false; } }
        Field {
            id: pw
            visible: nr.asking
            x: 44; y: 60
            width: parent.width - 56
            password: true
            placeholder: "Enter the network security key"
            onAccepted: { Net.connect(nr.modelData, text); text = ""; root.openNet = ""; }
        }
        Row {
            anchors.right: parent.right; anchors.rightMargin: 12
            y: nr.asking ? 104 : 58
            spacing: 8
            Btn {
                visible: nr.asking
                text: "Cancel"
                onClicked: nr.asking = false
            }
            Btn {
                kind: nr.modelData.inUse ? "standard" : "accent"
                text: nr.modelData.inUse ? "Disconnect" : nr.asking ? "Next" : "Connect"
                enabled: Net.connecting === ""
                onClicked: {
                    if (nr.modelData.inUse) { Net.disconnectWifi(); return; }
                    if (nr.asking) { Net.connect(nr.modelData, pw.text); pw.text = ""; root.openNet = ""; return; }
                    if (nr.modelData.secure && !nr.modelData.saved) { nr.asking = true; pw.focusField(); return; }
                    Net.connect(nr.modelData, "");
                    root.openNet = "";
                }
            }
        }
        readonly property string open: root.openNet
    }
    property string openNet: ""
}
