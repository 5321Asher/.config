import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import "../../theme"
import "../../widgets"
import "../../services"
import ".."

// I. Sanctum: the everyday charms (Wi-Fi, Bluetooth, Tailscale, do not disturb, keep vigil, lights
// that follow the theme), the levels (the voice, the ear, the screens' light), capture, the scribe
// (dictation) and the ways to close the book (power).
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

    // close the codex first, then act (so a screenshot doesn't catch it)
    function closeThen(fn) { CodexState.open = false; later.fn = fn; later.restart(); }
    Timer { id: later; property var fn; interval: Theme.slow + 80; onTriggered: fn() }

    Section {
        title: "charms"
        Grid {
            width: parent.width
            columns: 2
            columnSpacing: 8
            rowSpacing: 8
            readonly property real cell: (width - 8) / 2
            Charm { width: parent.cell; name: "Wi-Fi"; status: !Net.wifiEnabled ? "the radio sleeps" : Net.ssid || "not bound"
                    checked: Net.wifiEnabled; more: true; onToggled: Net.toggleWifi(); onDetails: CodexState.turnTo("comms") }
            Charm { width: parent.cell; name: "Bluetooth"; enabled: root.bt !== null
                    status: !root.bt ? "no adapter" : !root.bt.enabled ? "silent" : (root.bt.devices.values.filter(d => d.connected).map(d => d.name).join(", ") || "listening")
                    checked: root.bt?.enabled ?? false; more: true; onToggled: root.bt.enabled = !root.bt.enabled; onDetails: CodexState.turnTo("comms") }
            Charm { width: parent.cell; name: "Tailscale"; enabled: Net.tsAvailable
                    status: !Net.tsAvailable ? "not installed" : Net.tsBusy ? Net.tsBusy.toLowerCase() + "…" : Net.tsRunning ? Net.tsPeersOnline + " kin awake" : "down"
                    checked: Net.tsRunning; more: true; onToggled: Net.toggleTailscale(); onDetails: CodexState.turnTo("comms") }
            Charm { width: parent.cell; name: "Do not disturb"; status: Notifs.dnd ? "only urgent sendings" : "letters welcome"
                    checked: Notifs.dnd; more: true; onToggled: Notifs.dnd = !Notifs.dnd; onDetails: CodexState.turnTo("log") }
            Charm { width: parent.cell; name: "Keep vigil"; status: StayAwake.on ? "no dimming, no sleep" : "rests when idle"
                    checked: StayAwake.on; onToggled: StayAwake.on = !StayAwake.on }
            Charm { width: parent.cell; name: "Lanterns follow"; enabled: Rgb.available || !Rgb.scanned
                    status: !Rgb.scanned ? "looking…" : !Rgb.available ? "openrgb not found" : Rgb.followWallpaper ? "the theme's gold" : "set by hand"
                    checked: Rgb.followWallpaper; more: true; onToggled: Rgb.setFollowWallpaper(!Rgb.followWallpaper); onDetails: CodexState.turnTo("lamps") }
        }
        Body { visible: Net.tsError !== ""; width: parent.width; wrapMode: Text.Wrap; text: Net.tsError; color: Theme.danger; italic: true }
    }

    Section {
        title: "levels"
        trailing: root.sink ? "the voice at " + Math.round((root.sink.audio?.volume ?? 0) * 100) + "%" : ""
        Level { name: "voice"; node: root.sink }
        Level { name: "ear"; node: root.source; tint: Theme.rubric }
        Item {
            visible: Backlight.available
            width: parent.width
            height: 24
            Caps { width: 90; anchors.verticalCenter: parent.verticalCenter; text: "light" }
            Slider { x: 96; width: parent.width - 150; anchors.verticalCenter: parent.verticalCenter; color: Theme.warn
                     value: Backlight.value; onMoved: v => Backlight.set(v) }
            Body { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: Math.round(Backlight.value * 100) + "%"; strong: true }
        }
        Repeater {
            model: Brightness.displays
            Item {
                required property var modelData
                required property int index
                width: parent.width
                height: 24
                Caps { width: 90; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter; text: (modelData.name || "screen") }
                Slider { x: 96; width: parent.width - 150; anchors.verticalCenter: parent.verticalCenter; color: Theme.warn
                         value: modelData.value; onMoved: v => Brightness.set(index, v) }
                Body { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: Math.round(modelData.value * 100) + "%"; strong: true }
            }
        }
    }

    Section {
        title: "capture"
        trailing: Capture.recording ? "scrying · " + Capture.elapsedText : ""
        trailingColor: Theme.rubric
        Flow {
            width: parent.width
            spacing: 8
            Btn { text: "region"; glyph: "\u{f019e}"; onClicked: root.closeThen(() => Capture.screenshot("region")) }
            Btn { text: "screen"; glyph: "\u{f0379}"; onClicked: root.closeThen(() => Capture.screenshot("screen")) }
            Btn { text: "read text"; glyph: "\u{f113d}"; onClicked: root.closeThen(() => Capture.ocr()) }
            Btn { text: Capture.recording ? "stop" : "record"; glyph: Capture.recording ? "\u{f04db}" : "\u{f044b}"; on: Capture.recording
                  enabled: Capture.recording || Capture.recorder !== ""
                  onClicked: Capture.recording ? Capture.toggleRecording() : root.closeThen(() => Capture.toggleRecording()) }
        }
    }

    Section {
        visible: Voxtype.available
        title: "the scribe"
        trailing: Voxtype.recording ? "listening · " + Voxtype.elapsedText : Voxtype.transcribing ? "writing…" : Voxtype.running ? Voxtype.model : "asleep"
        trailingColor: Voxtype.recording ? Theme.rubric : Theme.inkDim
        Flow {
            width: parent.width
            spacing: 8
            Btn { text: !Voxtype.running ? "wake" : Voxtype.recording ? "send" : "dictate"; glyph: "\u{f036c}"; on: Voxtype.recording; enabled: !Voxtype.transcribing
                  onClicked: Voxtype.running && !Voxtype.recording ? root.closeThen(() => Voxtype.toggle()) : Voxtype.toggle() }
            Btn { text: "cancel"; enabled: Voxtype.busy; onClicked: Voxtype.cancel() }
        }
    }

    Section {
        title: "closing the book"
        trailing: confirm.action ? "again to " + confirm.action : ""
        trailingColor: Theme.rubric
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
        property color tint: Theme.gold
        width: parent.width
        height: 24
        Caps { width: 90; anchors.verticalCenter: parent.verticalCenter; text: lv.name
               color: lv.node?.audio?.muted ? Theme.rubric : Theme.inkDim
               MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (lv.node?.audio) lv.node.audio.muted = !lv.node.audio.muted } }
        Slider { x: 96; width: parent.width - 150; anchors.verticalCenter: parent.verticalCenter
                 color: lv.node?.audio?.muted ? Theme.inkDim : lv.tint
                 value: lv.node?.audio?.volume ?? 0; onMoved: v => { if (lv.node?.audio) lv.node.audio.volume = v; } }
        Body { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; strong: true
               text: lv.node?.audio?.muted ? "hushed" : Math.round((lv.node?.audio?.volume ?? 0) * 100) + "%" }
    }
}
