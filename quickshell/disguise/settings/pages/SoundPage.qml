import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import "../../theme"
import "../../widgets"
import "../../services"
import ".."

// Sound: Output (where to play sound, its volume), Input (the microphone, its volume, a live
// test meter), the volume mixer (every app playing), and what's playing with the visualiser.
Column {
    id: root
    spacing: 4
    Component.onDestruction: MicLevel.testing = false

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream)
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property var sources: Pipewire.nodes.values.filter(n => n.audio && !n.isSink && !n.isStream && n.properties?.["media.class"] === "Audio/Source")
    readonly property var streams: Pipewire.nodes.values.filter(n => n.audio && n.isStream && n.properties?.["media.class"] === "Stream/Output/Audio")
    PwObjectTracker { objects: [root.sink, root.source].filter(n => n).concat(root.sinks, root.sources, root.streams) }
    function name(n) { return n?.nickname || n?.description || n?.name || ""; }
    readonly property var players: Mpris.players.values.filter(p => !p.dbusName.includes("playerctld"))
    readonly property var player: players.find(p => p.isPlaying) ?? players[0] ?? null

    Header { text: "Output"; topPadding: 0 }
    SettingRow {
        width: parent.width
        glyph: ""; title: "Choose where to play sound"; subtitle: root.name(root.sink)
        Combo { width: 280; model: root.sinks; textOf: n => root.name(n); currentIndex: root.sinks.indexOf(root.sink); onChosen: i => Pipewire.preferredDefaultAudioSink = root.sinks[i] }
    }
    SettingRow {
        width: parent.width
        glyph: root.sink?.audio?.muted ? "" : ""; title: "Volume"
        Row {
            spacing: 8
            Btn { kind: "subtle"; width: 36; glyph: root.sink?.audio?.muted ? "" : ""; onClicked: root.sink.audio.muted = !root.sink.audio.muted }
            Slider { width: 220; anchors.verticalCenter: parent.verticalCenter; value: root.sink?.audio?.volume ?? 0; onMoved: v => { if (root.sink?.audio) root.sink.audio.volume = v; } }
            Txt { width: 36; height: 32; text: Math.round((root.sink?.audio?.volume ?? 0) * 100) }
        }
    }

    Header { text: "Input" }
    SettingRow {
        width: parent.width
        glyph: ""; title: "Choose a device for speaking or recording"; subtitle: root.name(root.source)
        Combo { width: 280; model: root.sources; textOf: n => root.name(n); currentIndex: root.sources.indexOf(root.source); onChosen: i => Pipewire.preferredDefaultAudioSource = root.sources[i] }
    }
    SettingRow {
        width: parent.width
        glyph: root.source?.audio?.muted ? "" : ""; title: "Volume"
        Row {
            spacing: 8
            Btn { kind: "subtle"; width: 36; glyph: root.source?.audio?.muted ? "" : ""; onClicked: root.source.audio.muted = !root.source.audio.muted }
            Slider { width: 220; anchors.verticalCenter: parent.verticalCenter; value: root.source?.audio?.volume ?? 0; onMoved: v => { if (root.source?.audio) root.source.audio.volume = v; } }
            Txt { width: 36; height: 32; text: Math.round((root.source?.audio?.volume ?? 0) * 100) }
        }
    }
    SettingRow {
        width: parent.width
        glyph: ""; title: "Test your microphone"; subtitle: MicLevel.testing ? "Speak: the bar follows your voice" : "Start a test and speak"
        Row {
            spacing: 12
            Progress {
                width: 200
                anchors.verticalCenter: parent.verticalCenter
                value: MicLevel.bars.length ? Math.min(1, MicLevel.bars.reduce((a, b) => Math.max(a, b), 0) * 1.4) : 0
            }
            Btn { text: MicLevel.testing ? "Stop test" : "Start test"; onClicked: MicLevel.testing = !MicLevel.testing }
        }
    }

    Header { text: "Volume mixer" }
    SettingRow {
        visible: root.streams.length === 0
        width: parent.width
        glyph: ""; title: "No apps are playing sound"
    }
    Repeater {
        model: root.streams
        SettingRow {
            required property var modelData
            width: root.width
            glyph: ""
            title: modelData.properties?.["application.name"] || modelData.name || "App"
            subtitle: modelData.properties?.["media.name"] ?? ""
            Row {
                spacing: 8
                Btn { kind: "subtle"; width: 36; glyph: modelData.audio?.muted ? "" : ""; onClicked: modelData.audio.muted = !modelData.audio.muted }
                Slider { width: 200; anchors.verticalCenter: parent.verticalCenter; value: modelData.audio?.volume ?? 0; onMoved: v => { if (modelData.audio) modelData.audio.volume = v; } }
                Txt { width: 36; height: 32; text: Math.round((modelData.audio?.volume ?? 0) * 100) }
            }
        }
    }

    Header { text: "Now playing"; visible: root.player !== null }
    Card {
        visible: root.player !== null
        width: parent.width
        height: 150
        Image {
            id: art
            x: 16; y: 16
            width: 72; height: 72
            source: root.player?.trackArtUrl ?? ""
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 144
            asynchronous: true
        }
        Column {
            x: 104; y: 18
            width: parent.width - 120
            Txt { width: parent.width; text: root.player?.trackTitle || "Unknown title"; strong: true }
            Txt { width: parent.width; text: root.player?.trackArtist ?? ""; level: 2 }
            Txt { width: parent.width; text: root.player?.identity ?? ""; level: 3; size: Theme.caption }
        }
        Row {
            x: 104; y: 90
            spacing: 4
            Btn { kind: "subtle"; glyph: ""; width: 40; enabled: !!root.player?.canGoPrevious; onClicked: root.player.previous() }
            Btn { kind: "subtle"; glyph: root.player?.isPlaying ? "" : ""; width: 40; onClicked: root.player.togglePlaying() }
            Btn { kind: "subtle"; glyph: ""; width: 40; enabled: !!root.player?.canGoNext; onClicked: root.player.next() }
        }
        // the visualiser (cava), in the accent
        Row {
            anchors.right: parent.right; anchors.rightMargin: 16
            anchors.bottom: parent.bottom; anchors.bottomMargin: 16
            spacing: 3
            Repeater {
                model: Radio.count
                Rectangle {
                    required property int index
                    width: 5
                    height: Math.max(2, (Radio.bars[index] ?? 0) * Radio.gain * 90)
                    anchors.bottom: parent.bottom
                    radius: 2
                    color: Theme.accent
                    opacity: 0.85
                }
            }
        }
    }
}
