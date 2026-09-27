import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../../theme"
import "../../services"
import ".."

// Helm: the everyday switches. Systems (Wi-Fi, Bluetooth, Tailscale, do not disturb, stay awake,
// lights follow theme), levels (speakers, microphone, monitor brightness), capture, dictation, session.
Column {
    id: root

    spacing: 22

    readonly property var bt: Bluetooth.defaultAdapter
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    PwObjectTracker { objects: [root.sink, root.source].filter(n => n) }

    Component.onCompleted: {
        Net.refresh();
        if (!Brightness.scanned) Brightness.scan();
        if (!Rgb.scanned) Rgb.scan();
    }

    // Close the deck, then act (so a screenshot doesn't catch it)
    function closeThen(fn) {
        DeckState.open = false;
        later.fn = fn;
        later.restart();
    }
    Timer { id: later; property var fn; interval: Theme.slow; onTriggered: fn() }

    // ---------------------------------------------------------------- systems
    Section {
        title: "systems"

        Grid {
            width: parent.width
            columns: 2
            columnSpacing: 10
            rowSpacing: 10

            readonly property real cell: (width - columnSpacing) / 2

            Tile {
                width: parent.cell
                glyph: Net.wifiEnabled ? "\u{f05a9}" : "\u{f05aa}"
                title: "wi-fi"
                status: !Net.wifiEnabled ? "off" : Net.ssid || "not connected"
                active: Net.wifiEnabled
                more: true
                onClicked: Net.toggleWifi()
                onDetails: DeckState.page = "comms"
            }
            Tile {
                width: parent.cell
                enabled: root.bt !== null
                glyph: root.bt?.enabled ? "\u{f00af}" : "\u{f00b2}"
                title: "bluetooth"
                status: !root.bt ? "no adapter" : !root.bt.enabled ? "off"
                    : (root.bt.devices.values.filter(d => d.connected).map(d => d.name).join(", ") || "on")
                active: root.bt?.enabled ?? false
                more: true
                onClicked: root.bt.enabled = !root.bt.enabled
                onDetails: DeckState.page = "comms"
            }
            Tile {
                width: parent.cell
                enabled: Net.tsAvailable
                glyph: "\u{f0582}"
                title: "tailscale"
                status: !Net.tsAvailable ? "unavailable" : Net.tsBusy ? Net.tsBusy.toLowerCase()
                    : Net.tsRunning ? Net.tsPeersOnline + " peers online" : "off"
                active: Net.tsRunning
                more: true
                onClicked: Net.toggleTailscale()
                onDetails: DeckState.page = "comms"
            }
            Tile {
                width: parent.cell
                glyph: Transmissions.dnd ? "\u{f009b}" : "\u{f009a}"
                title: "do not disturb"
                status: Transmissions.dnd ? "only priority transmissions" : "transmissions on"
                active: Transmissions.dnd
                more: true
                onClicked: Transmissions.dnd = !Transmissions.dnd
                onDetails: DeckState.page = "log"
            }
            Tile {
                width: parent.cell
                glyph: "\u{f0176}"
                title: "stay awake"
                status: awake.running ? "no dimming, locking or sleep" : "idle timers normal"
                active: awake.running
                onClicked: awake.running = !awake.running
            }
            Tile {
                width: parent.cell
                enabled: Rgb.available || !Rgb.scanned
                glyph: "\u{f0335}"
                title: "lights follow"
                status: !Rgb.scanned ? "checking…" : !Rgb.available ? "openrgb not found" : Rgb.followWallpaper ? "colour theme accent" : "manual"
                active: Rgb.followWallpaper
                more: true
                onClicked: Rgb.setFollowWallpaper(!Rgb.followWallpaper)
                onDetails: DeckState.page = "lamps"
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
    }

    // ---------------------------------------------------------------- levels
    Section {
        title: "levels"
        trailing: root.sink ? Math.round((root.sink.audio?.volume ?? 0) * 100) + "%" : ""

        Level {
            glyph: root.sink?.audio?.muted ? "\u{f0581}" : "\u{f057e}"
            label: "speakers"
            detail: root.sink?.nickname || root.sink?.description || ""
            node: root.sink
        }
        Level {
            glyph: root.source?.audio?.muted ? "\u{f036d}" : "\u{f036c}"
            label: "microphone"
            detail: root.source?.nickname || root.source?.description || ""
            node: root.source
        }
        Repeater {
            model: Brightness.displays
            Item {
                required property var modelData
                required property int index
                width: parent.width
                height: 40
                Text {
                    id: bg
                    width: 26
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\u{f00df}"
                    color: Theme.brass
                    font.family: Theme.fontData
                    font.pixelSize: 16
                }
                Column {
                    anchors.left: bg.right
                    anchors.leftMargin: 8
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text {
                        text: (modelData.name || "display").toLowerCase() + "  ·  " + Math.round(modelData.value * 100) + "%"
                        color: Theme.fg
                        font.family: Theme.fontData
                        font.pixelSize: Theme.dataSizeSmall
                    }
                    Dial {
                        width: parent.width
                        value: modelData.value
                        ink: Theme.brassBright
                        onMoved: v => Brightness.set(index, v)
                    }
                }
            }
        }
        Text {
            visible: Brightness.scanned && (!Brightness.available || Brightness.displays.length === 0)
            text: !Brightness.available ? "install ddcutil for monitor brightness" : "no ddc/ci displays found"
            color: Theme.dim
            font.family: Theme.fontData
            font.pixelSize: Theme.dataSizeSmall
        }
    }

    // ---------------------------------------------------------------- capture
    Section {
        title: "capture"
        trailing: Capture.recording ? "● rec " + Capture.elapsedText : ""
        trailingColor: Theme.signal

        Row {
            spacing: 18
            Knob { glyph: "\u{f019e}"; label: "region"; onClicked: root.closeThen(() => Capture.screenshot("region")) }
            Knob { glyph: "\u{f0379}"; label: "screen"; onClicked: root.closeThen(() => Capture.screenshot("screen")) }
            Knob { glyph: "\u{f113d}"; label: "text"; onClicked: root.closeThen(() => Capture.ocr()) }
            Knob {
                glyph: Capture.recording ? "\u{f04db}" : "\u{f044b}"
                label: Capture.recording ? "stop" : "record"
                danger: Capture.recording
                active: Capture.recording
                enabled: Capture.recording || Capture.recorder !== ""
                onClicked: Capture.recording ? Capture.toggleRecording() : root.closeThen(() => Capture.toggleRecording())
            }
        }
    }

    // ---------------------------------------------------------------- dictation
    Section {
        visible: Voxtype.available
        title: "dictation"
        trailing: Voxtype.recording ? "● " + Voxtype.elapsedText : Voxtype.transcribing ? "decoding"
            : Voxtype.running ? Voxtype.model : "service off"
        trailingColor: Voxtype.recording ? Theme.signal : Voxtype.running ? Theme.dim : Theme.warn

        Row {
            spacing: 18
            Knob {
                glyph: Voxtype.recording ? "\u{f04db}" : "\u{f036c}"
                label: !Voxtype.running ? "start" : Voxtype.recording ? "send" : "dictate"
                danger: Voxtype.recording
                active: Voxtype.recording
                enabled: !Voxtype.transcribing
                onClicked: Voxtype.running && !Voxtype.recording ? root.closeThen(() => Voxtype.toggle()) : Voxtype.toggle()
            }
            Knob { glyph: "\u{f0156}"; label: "cancel"; enabled: Voxtype.busy; onClicked: Voxtype.cancel() }
        }
    }

    // ---------------------------------------------------------------- session
    Section {
        title: "session"
        trailing: confirm.action ? "again to " + confirm.action : ""
        trailingColor: Theme.signal

        Row {
            spacing: 18
            Knob { glyph: "\u{f033e}"; label: "lock"; onClicked: root.closeThen(() => Quickshell.execDetached(["loginctl", "lock-session"])) }
            Knob { glyph: "\u{f04b2}"; label: "sleep"; onClicked: root.closeThen(() => Quickshell.execDetached(["systemctl", "suspend"])) }
            Knob {
                glyph: "\u{f0343}"; label: "log out"
                danger: confirm.action === "log out"; active: danger
                onClicked: confirm.ask("log out", ["hyprctl", "dispatch", "hl.dsp.exit()"])
            }
            Knob {
                glyph: "\u{f0709}"; label: "restart"
                danger: confirm.action === "restart"; active: danger
                onClicked: confirm.ask("restart", ["systemctl", "reboot"])
            }
            Knob {
                glyph: "\u{f0425}"; label: "shut down"
                danger: confirm.action === "shut down"; active: danger
                onClicked: confirm.ask("shut down", ["systemctl", "poweroff"])
            }
        }
    }

    // Two clicks within 3 s for the ones that end the session
    QtObject {
        id: confirm
        property string action: ""
        property var command: []
        function ask(a, cmd) {
            if (action === a) { action = ""; Quickshell.execDetached(cmd); return; }
            action = a;
            command = cmd;
            expire.restart();
        }
    }
    Timer { id: expire; interval: 3000; onTriggered: confirm.action = "" }

    // Stay awake: hold a systemd idle inhibitor (hypridle respects it) while on
    Process {
        id: awake
        command: ["systemd-inhibit", "--what=idle", "--who=Observatory", "--why=Stay awake (control deck)", "sleep", "infinity"]
    }

    // A volume row: mute knob, name, dial
    component Level: Item {
        id: lv
        property string glyph
        property string label
        property string detail
        property PwNode node
        width: parent.width
        height: 44
        Knob {
            id: mute
            size: 32
            anchors.verticalCenter: parent.verticalCenter
            glyph: lv.glyph
            danger: lv.node?.audio?.muted ?? false
            active: danger
            onClicked: if (lv.node?.audio) lv.node.audio.muted = !lv.node.audio.muted
        }
        Column {
            anchors.left: mute.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: lv.label + (lv.detail ? "  ·  " + lv.detail : "") + "  ·  " + Math.round((lv.node?.audio?.volume ?? 0) * 100) + "%"
                color: Theme.fg
                font.family: Theme.fontData
                font.pixelSize: Theme.dataSizeSmall
            }
            Dial {
                width: parent.width
                value: lv.node?.audio?.volume ?? 0
                ink: lv.node?.audio?.muted ? Theme.dim : Theme.phosphor
                onMoved: v => { if (lv.node?.audio) lv.node.audio.volume = v; }
            }
        }
    }
}
