import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import "../../theme"
import "../../widgets"
import "../../services"
import ".."

// 01 HELM 操縦: the everyday switches (Wi-Fi, Bluetooth, Tailscale, do not disturb, stay awake,
// lights follow the profile), the levels (speakers, mic, monitors), capture, dictation, power.
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

    // close the rig first, then act (so a screenshot doesn't catch it)
    function closeThen(fn) { RigState.open = false; later.fn = fn; later.restart(); }
    Timer { id: later; property var fn; interval: Theme.slow + 60; onTriggered: fn() }

    Section {
        title: "switches"
        jp: "開閉"
        Grid {
            width: parent.width
            columns: 2
            columnSpacing: 8
            rowSpacing: 8
            readonly property real cell: (width - 8) / 2
            Chip { width: parent.cell; name: "wi-fi"; status: !Net.wifiEnabled ? "radio off" : Net.ssid || "not connected"
                   checked: Net.wifiEnabled; more: true; onToggled: Net.toggleWifi(); onDetails: RigState.page = "comms" }
            Chip { width: parent.cell; name: "bluetooth"; enabled: root.bt !== null
                   status: !root.bt ? "no adapter" : !root.bt.enabled ? "off" : (root.bt.devices.values.filter(d => d.connected).map(d => d.name).join(", ") || "on")
                   checked: root.bt?.enabled ?? false; more: true; onToggled: root.bt.enabled = !root.bt.enabled; onDetails: RigState.page = "comms" }
            Chip { width: parent.cell; name: "tailscale"; enabled: Net.tsAvailable
                   status: !Net.tsAvailable ? "not installed" : Net.tsBusy ? Net.tsBusy.toLowerCase() : Net.tsRunning ? Net.tsPeersOnline + " peers online" : "down"
                   checked: Net.tsRunning; more: true; onToggled: Net.toggleTailscale(); onDetails: RigState.page = "comms" }
            Chip { width: parent.cell; name: "do not disturb"; status: Notifs.dnd ? "only urgent messages" : "messages on"
                   checked: Notifs.dnd; more: true; onToggled: Notifs.dnd = !Notifs.dnd; onDetails: RigState.page = "log" }
            Chip { width: parent.cell; name: "idle // hold"; status: StayAwake.on ? "no dim, lock or sleep" : "idle timers normal"
                   checked: StayAwake.on; onToggled: StayAwake.on = !StayAwake.on }
            Chip { width: parent.cell; name: "lights follow"; enabled: Rgb.available || !Rgb.scanned
                   status: !Rgb.scanned ? "scanning…" : !Rgb.available ? "openrgb not found" : Rgb.followWallpaper ? "profile accent" : "manual"
                   checked: Rgb.followWallpaper; more: true; onToggled: Rgb.setFollowWallpaper(!Rgb.followWallpaper); onDetails: RigState.page = "lamps" }
        }
        Label { visible: Net.tsError !== ""; width: parent.width; wrapMode: Text.Wrap; text: Net.tsError; color: Theme.red }
    }

    Section {
        title: "levels"
        jp: "音量"
        trailing: root.sink ? Math.round((root.sink.audio?.volume ?? 0) * 100) + "%" : ""
        Level { name: "speakers"; node: root.sink }
        Level { name: "mic"; node: root.source; color: Theme.red }
        Repeater {
            model: Brightness.displays
            Item {
                required property var modelData
                required property int index
                width: parent.width
                height: 20
                Label { width: 90; anchors.verticalCenter: parent.verticalCenter; text: (modelData.name || "display").slice(0, 10) }
                Slider { x: 96; width: parent.width - 150; anchors.verticalCenter: parent.verticalCenter; height: 12; color: Theme.yellow
                         value: modelData.value; onMoved: v => Brightness.set(index, v) }
                Label { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: Math.round(modelData.value * 100) + "%"; strong: true }
            }
        }
        Label { visible: Brightness.scanned && (!Brightness.available || Brightness.displays.length === 0)
                text: !Brightness.available ? "install ddcutil for monitor brightness" : "no ddc/ci displays" }
    }

    Section {
        title: "capture"
        jp: "撮影"
        trailing: Capture.recording ? "● rec " + Capture.elapsedText : ""
        trailingColor: Theme.red
        Flow {
            width: parent.width
            spacing: 8
            Btn { text: "region"; glyph: "\u{f019e}"; onClicked: root.closeThen(() => Capture.screenshot("region")) }
            Btn { text: "screen"; glyph: "\u{f0379}"; onClicked: root.closeThen(() => Capture.screenshot("screen")) }
            Btn { text: "ocr"; glyph: "\u{f113d}"; onClicked: root.closeThen(() => Capture.ocr()) }
            Btn { text: Capture.recording ? "stop" : "record"; glyph: Capture.recording ? "\u{f04db}" : "\u{f044b}"; on: Capture.recording
                  enabled: Capture.recording || Capture.recorder !== ""
                  onClicked: Capture.recording ? Capture.toggleRecording() : root.closeThen(() => Capture.toggleRecording()) }
        }
    }

    Section {
        visible: Voxtype.available
        title: "voice"
        jp: "音声"
        trailing: Voxtype.recording ? "● " + Voxtype.elapsedText : Voxtype.transcribing ? "decoding" : Voxtype.running ? Voxtype.model : "service off"
        trailingColor: Voxtype.recording ? Theme.red : Theme.dim
        Flow {
            width: parent.width
            spacing: 8
            Btn { text: !Voxtype.running ? "start" : Voxtype.recording ? "send" : "dictate"; glyph: "\u{f036c}"; on: Voxtype.recording; enabled: !Voxtype.transcribing
                  onClicked: Voxtype.running && !Voxtype.recording ? root.closeThen(() => Voxtype.toggle()) : Voxtype.toggle() }
            Btn { text: "cancel"; enabled: Voxtype.busy; onClicked: Voxtype.cancel() }
        }
    }

    Section {
        title: "power"
        jp: "電源"
        trailing: confirm.action ? "again to " + confirm.action : ""
        trailingColor: Theme.red
        Flow {
            width: parent.width
            spacing: 8
            Btn { text: "lock"; glyph: "\u{f033e}"; onClicked: root.closeThen(() => Quickshell.execDetached(["loginctl", "lock-session"])) }
            Btn { text: "sleep"; glyph: "\u{f04b2}"; onClicked: root.closeThen(() => Quickshell.execDetached(["systemctl", "suspend"])) }
            Btn { text: "log out"; glyph: "\u{f0343}"; on: confirm.action === "log out"; onClicked: confirm.ask("log out", ["hyprctl", "dispatch", "hl.dsp.exit()"]) }
            Btn { text: "restart"; glyph: "\u{f0709}"; on: confirm.action === "restart"; onClicked: confirm.ask("restart", ["systemctl", "reboot"]) }
            Btn { text: "shut down"; glyph: "\u{f0425}"; on: confirm.action === "shut down"; onClicked: confirm.ask("shut down", ["systemctl", "poweroff"]) }
        }
    }

    // two clicks within 3 s for the ones that end the session
    QtObject {
        id: confirm
        property string action: ""
        function ask(a, cmd) {
            if (action === a) { action = ""; Quickshell.execDetached(cmd); return; }
            action = a;
            expire.restart();
        }
    }
    Timer { id: expire; interval: 3000; onTriggered: confirm.action = "" }

    component Level: Item {
        id: lv
        property string name
        property PwNode node
        property color color: Theme.cyan
        width: parent.width
        height: 20
        Label { width: 70; anchors.verticalCenter: parent.verticalCenter; text: lv.name
                color: lv.node?.audio?.muted ? Theme.red : Theme.dim
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (lv.node?.audio) lv.node.audio.muted = !lv.node.audio.muted } }
        Slider { x: 96; width: parent.width - 150; anchors.verticalCenter: parent.verticalCenter; height: 12
                 color: lv.node?.audio?.muted ? Theme.dim : lv.color
                 value: lv.node?.audio?.volume ?? 0; onMoved: v => { if (lv.node?.audio) lv.node.audio.volume = v; } }
        Label { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; strong: true
                text: lv.node?.audio?.muted ? "MUTE" : Math.round((lv.node?.audio?.volume ?? 0) * 100) + "%" }
    }
}
