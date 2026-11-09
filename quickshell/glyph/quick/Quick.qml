import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Services.Notifications
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import "../theme"
import "../widgets"
import "../services"
import "../prefs"
import "../power"

// Quick settings (click the rail's status glyphs, or `deck open helm`): a 470 panel at the right edge,
// sliding in from the right over windows dimmed 35 %. The clock, the Wi-Fi and Bluetooth pills (the
// chevron opens their list under them), round tiles (do not disturb, stay awake, Tailscale, lights
// follow the theme, mic, record, screenshot, dark), the levels (filled = a white pill, empty = dots),
// the player, and the notifications. Esc or a click outside closes. State: QuickState.
PanelWindow {
    id: root

    Binding on screen {
        when: !root.visible
        value: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        restoreMode: Binding.RestoreNone
    }
    readonly property real s: Theme.scaleFor(screen)

    property real t: QuickState.open ? 1 : 0
    Behavior on t { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
    visible: t > 0

    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: QuickState.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.namespace: "glyph-quick"

    readonly property var bt: Bluetooth.defaultAdapter
    readonly property var btDev: bt?.devices.values.find(d => d.connected) ?? null
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    PwObjectTracker { objects: [root.sink, root.source].filter(n => n) }
    readonly property var player: Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values[0] ?? null
    SystemClock { id: clock; precision: SystemClock.Minutes }

    function close() { QuickState.open = false; }
    // close first, then act (a screenshot shouldn't catch the panel)
    function closeThen(fn) { close(); later.fn = fn; later.restart(); }
    Timer { id: later; property var fn; interval: Theme.t + 60; onTriggered: fn() }

    Connections {
        target: QuickState
        function onOpenChanged() {
            if (!QuickState.open) return;
            Net.refresh();
            if (!Brightness.scanned) Brightness.scan();
            panel.forceActiveFocus();
        }
    }
    function ago(n) {
        const t = Notifs.times[n.id];
        if (!t) return "";
        const m = Math.floor((clock.date.getTime() - t) / 60000);
        return m < 1 ? "now" : m < 60 ? m + " min" : Math.floor(m / 60) + " h";
    }

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.35 * root.t
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    Stage {
        id: stage
        s: root.s

        Rectangle {
            id: panel
            anchors { right: parent.right; rightMargin: 14 - 24 * (1 - root.t); bottom: parent.bottom; bottomMargin: 14 }
            width: 470
            height: Math.min(stage.height - 28, col.height + 44)
            opacity: root.t
            radius: 36
            color: Theme.s1
            border { width: 1; color: Theme.s2 }
            focus: true
            Keys.onEscapePressed: root.close()
            MouseArea { anchors.fill: parent }

            Flickable {
                anchors.fill: parent
                contentHeight: col.height + 44
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: col
                    x: 22
                    y: 22
                    width: panel.width - 44
                    spacing: 16

                    // the clock; settings and power
                    Item {
                        width: parent.width
                        height: 54
                        Row {
                            x: 6
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 14
                            Num { anchors.verticalCenter: parent.verticalCenter; text: Qt.formatTime(clock.date, "HH:mm"); font.pixelSize: 44 }
                            Lb { anchors.verticalCenter: parent.verticalCenter; text: Qt.locale("en_US").toString(clock.date, "ddd d MMM") }
                        }
                        Row {
                            anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                            spacing: 14
                            Round { icon: "\u{F0493}"; onClicked: { root.close(); PrefsState.show(PrefsState.page); } }
                            Round { icon: "\u{F0425}"; onClicked: { root.close(); PowerState.open = true; } }
                        }
                    }

                    // Wi-Fi and Bluetooth
                    Row {
                        width: parent.width
                        spacing: 12
                        Chip {
                            width: (parent.width - 12) / 2
                            glyph: Net.wifiEnabled ? "\u{F05A9}" : "\u{F05AA}"
                            name: "Wi-Fi"
                            status: !Net.wifiEnabled ? "off" : Net.connecting ? "joining…" : Net.ssid || "no network"
                            checked: Net.wifiEnabled
                            more: true
                            onToggled: Net.toggleWifi()
                            onDetails: { QuickState.pick = QuickState.pick === "wifi" ? "" : "wifi"; if (QuickState.pick === "wifi" && Net.wifiEnabled) Net.scan(); }
                        }
                        Chip {
                            width: (parent.width - 12) / 2
                            enabled: !!root.bt
                            glyph: root.bt?.enabled ? "\u{F00AF}" : "\u{F00B2}"
                            name: "Bluetooth"
                            status: !root.bt ? "no adapter" : !root.bt.enabled ? "off" : root.btDev?.name ?? "on"
                            checked: root.bt?.enabled ?? false
                            more: true
                            onToggled: if (root.bt) root.bt.enabled = !root.bt.enabled
                            onDetails: QuickState.pick = QuickState.pick === "bt" ? "" : "bt"
                        }
                    }

                    // the list under the pills
                    Column {
                        visible: QuickState.pick === "wifi"
                        width: parent.width
                        spacing: 4
                        property string asking: ""
                        id: wifiList
                        Lb { x: 6; text: Net.scanning ? "scanning…" : "networks"; bottomPadding: 4 }
                        Repeater {
                            model: Net.wifiEnabled ? Net.networks.slice(0, 7) : []
                            Column {
                                id: net
                                required property var modelData
                                width: wifiList.width
                                spacing: 6
                                Row2 {
                                    glyph: net.modelData.secure ? "\u{F0920}" : "\u{F05A9}"
                                    title: net.modelData.ssid
                                    subtitle: (net.modelData.secure ? "secured" : "open") + (net.modelData.saved ? " · saved" : "") + " · " + net.modelData.signal + "%"
                                    active: net.modelData.inUse
                                    trailing: Net.connecting === net.modelData.ssid ? "joining…" : ""
                                    onClicked: {
                                        if (net.modelData.inUse) return;
                                        if (net.modelData.secure && !net.modelData.saved) wifiList.asking = wifiList.asking === net.modelData.ssid ? "" : net.modelData.ssid;
                                        else Net.connect(net.modelData, "");
                                    }
                                }
                                Field {
                                    visible: wifiList.asking === net.modelData.ssid
                                    width: parent.width
                                    password: true
                                    glyph: "\u{F0306}"
                                    placeholder: "Password"
                                    onVisibleChanged: if (visible) focusField()
                                    onAccepted: { Net.connect(net.modelData, text); text = ""; wifiList.asking = ""; }
                                }
                            }
                        }
                        Lb { visible: Net.wifiError !== ""; width: parent.width; wrapMode: Text.Wrap; text: Net.wifiError; color: Theme.red }
                    }
                    Column {
                        visible: QuickState.pick === "bt"
                        width: parent.width
                        spacing: 4
                        Lb { x: 6; text: "paired devices"; bottomPadding: 4 }
                        Repeater {
                            model: root.bt?.enabled ? root.bt.devices.values.filter(d => d.paired || d.bonded) : []
                            Row2 {
                                required property var modelData
                                glyph: "\u{F00AF}"
                                title: modelData.name
                                subtitle: modelData.state === BluetoothDeviceState.Connecting ? "connecting…" : modelData.connected
                                          ? "connected" + (modelData.batteryAvailable ? " · " + Math.round(modelData.battery * 100) + "%" : "") : "paired"
                                active: modelData.connected
                                onClicked: modelData.connected ? modelData.disconnect() : modelData.connect()
                            }
                        }
                        Btn { text: "more in settings"; onClicked: { root.close(); PrefsState.show("comms"); } }
                    }

                    // round tiles
                    Grid {
                        width: parent.width
                        columns: 4
                        rowSpacing: 14
                        Tile { icon: "\u{F009B}"; name: "dnd"; on: Notifs.dnd; onClicked: Notifs.dnd = !Notifs.dnd }
                        Tile { icon: "\u{F0176}"; name: "awake"; on: StayAwake.on; onClicked: StayAwake.on = !StayAwake.on }
                        Tile { icon: "\u{F0483}"; name: "tailscale"; on: Net.tsRunning; enabled: Net.tsAvailable && !Net.tsBusy; onClicked: Net.toggleTailscale() }
                        Tile { icon: "\u{F06E8}"; name: "lights"; on: Rgb.followWallpaper; enabled: Rgb.available || !Rgb.scanned; onClicked: Rgb.setFollowWallpaper(!Rgb.followWallpaper) }
                        Tile {
                            icon: on ? "\u{F036C}" : "\u{F036D}"
                            name: "mic"
                            on: !(root.source?.audio?.muted ?? true)
                            onClicked: if (root.source?.audio) root.source.audio.muted = !root.source.audio.muted
                        }
                        Tile {
                            icon: "\u{F044A}"
                            name: Capture.recording ? Capture.elapsedText : "record"
                            on: Capture.recording
                            live: Capture.recording
                            enabled: Capture.recording || Capture.recorder !== ""
                            onClicked: Capture.recording ? Capture.toggleRecording() : root.closeThen(() => Capture.toggleRecording())
                        }
                        Tile { icon: "\u{F019E}"; name: "shot"; onClicked: root.closeThen(() => Capture.screenshot("region")) }
                        Tile {
                            icon: "\u{F050E}"
                            name: "dark"
                            on: !Theme.light
                            onClicked: Quickshell.execDetached([Quickshell.env("HOME") + "/.config/theme/theme", "set", Theme.light ? "dark" : "light"])
                        }
                    }

                    // levels
                    Slider {
                        width: parent.width
                        visible: Backlight.available
                        glyph: "\u{F00E0}"
                        value: Backlight.value
                        onMoved: v => Backlight.set(v)
                    }
                    Repeater {
                        model: Backlight.available ? [] : Brightness.displays
                        Slider {
                            required property var modelData
                            required property int index
                            width: col.width
                            glyph: "\u{F00E0}"
                            value: modelData.value
                            onMoved: v => Brightness.set(index, v)
                        }
                    }
                    Slider {
                        width: parent.width
                        glyph: root.sink?.audio?.muted ? "\u{F075F}" : "\u{F057E}"
                        value: root.sink?.audio?.muted ? 0 : root.sink?.audio?.volume ?? 0
                        onMoved: v => { if (root.sink?.audio) { root.sink.audio.muted = false; root.sink.audio.volume = v; } }
                    }

                    // the player
                    Rectangle {
                        visible: !!root.player
                        width: parent.width
                        height: 86
                        radius: 30
                        color: Theme.s2
                        Art { id: mart; x: 12; anchors.verticalCenter: parent.verticalCenter; width: 62; height: 62; step: 4; url: root.player?.trackArtUrl ?? "" }
                        Column {
                            anchors { left: mart.right; leftMargin: 16; right: mctl.left; rightMargin: 16; verticalCenter: parent.verticalCenter }
                            Text { width: parent.width; elide: Text.ElideRight; text: root.player?.trackTitle || "Nothing on"; font { family: Theme.ui; pixelSize: 16; weight: Font.DemiBold } color: Theme.fg }
                            Text { width: parent.width; elide: Text.ElideRight; text: root.player?.trackArtist ?? ""; font { family: Theme.ui; pixelSize: 13 } color: Theme.grey }
                        }
                        Controls { id: mctl; player: root.player; anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter } size: 20; play: 44 }
                    }

                    // notifications
                    Item {
                        width: parent.width
                        height: 20
                        Lb { x: 6; text: `notifications · ${Notifs.history.length}` }
                        Lb {
                            anchors.right: parent.right
                            rightPadding: 6
                            visible: Notifs.history.length > 0
                            text: "clear all"
                            color: Theme.fg
                            TapHandler { onTapped: Notifs.clearAll() }
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                        }
                    }
                    Repeater {
                        model: Notifs.history.slice(0, 6)
                        Rectangle {
                            required property var modelData
                            readonly property var n: modelData
                            width: col.width
                            height: nbody.height + 32
                            radius: 26
                            color: Theme.s2
                            border { width: n.urgency === NotificationUrgency.Critical ? 1 : 0; color: Theme.red }
                            Rectangle {
                                x: 18
                                y: 16
                                width: 42
                                height: 42
                                radius: 21
                                color: Theme.s3
                                Icon { anchors.centerIn: parent; text: "\u{F009A}"; visible: !nicon.visible }
                                Image {
                                    id: nicon
                                    anchors.centerIn: parent
                                    width: 24
                                    height: 24
                                    visible: status === Image.Ready
                                    source: n.appIcon ? (n.appIcon.startsWith("/") ? "file://" + n.appIcon : Quickshell.iconPath(n.appIcon, true)) : ""
                                    sourceSize: Qt.size(48, 48)
                                    layer.enabled: true
                                    layer.effect: Dm { step: 2 }
                                }
                            }
                            Column {
                                id: nbody
                                x: 74
                                y: 16
                                width: parent.width - x - 18
                                Lb { width: parent.width; elide: Text.ElideRight; text: `${n.appName || "app"} · ${root.ago(n)}`; px: 11 }
                                Text { width: parent.width; elide: Text.ElideRight; text: n.summary; font { family: Theme.ui; pixelSize: 15; weight: Font.DemiBold } color: Theme.fg }
                                Text {
                                    width: parent.width
                                    visible: !!n.body
                                    topPadding: 2
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                    textFormat: Text.PlainText
                                    text: (n.body ?? "").replace(/<[^>]*>/g, "")
                                    font { family: Theme.ui; pixelSize: 14 }
                                    color: Theme.grey
                                }
                            }
                            TapHandler {
                                onTapped: {
                                    const it = n;
                                    it.actions.find(a => a.identifier === "default")?.invoke();
                                    it.dismiss();
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // a round button (settings, power)
    component Round: Rectangle {
        id: rb
        property string icon
        signal clicked()
        width: 54
        height: 54
        radius: 27
        color: rbh.hovered ? Theme.s3 : Theme.s2
        Icon { anchors.centerIn: parent; text: rb.icon; font.pixelSize: 20 }
        HoverHandler { id: rbh; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: rb.clicked() }
    }
    // a round tile with its name under it; white when on (red while `live`)
    component Tile: Item {
        id: tl
        property string icon
        property string name
        property bool on
        property bool live
        signal clicked()
        width: (col.width) / 4
        height: 96
        opacity: enabled ? 1 : 0.4
        Rectangle {
            id: disc
            anchors.horizontalCenter: parent.horizontalCenter
            width: 70
            height: 70
            radius: 35
            color: tl.live ? Theme.red : tl.on ? Theme.fg : th.hovered ? Theme.s3 : Theme.s2
            Behavior on color { ColorAnimation { duration: Theme.t } }
            Icon { anchors.centerIn: parent; text: tl.icon; font.pixelSize: 24; color: tl.live ? "#FFFFFF" : tl.on ? Theme.ink : Theme.fg }
            HoverHandler { id: th; cursorShape: Qt.PointingHandCursor }
            TapHandler { enabled: tl.enabled; onTapped: tl.clicked() }
        }
        Lb { anchors { horizontalCenter: parent.horizontalCenter; top: disc.bottom; topMargin: 10 } text: tl.name; px: 10 }
    }
}
