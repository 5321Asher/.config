import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import "../../theme"
import "../../widgets"
import "../../services"
import ".."

// Multimedia Properties:
//   Now Playing   the playing track (cover, title, artist), seek, transport, and the spectrum
//   Audio         the playback and recording devices (98's "Preferred device"), their volumes, and
//                 a microphone test with a live meter
//   Programs      the volume of every program making sound
Props {
    id: root

    title: "Multimedia Properties"
    icon: "applications-multimedia"
    tabs: ["Now Playing", "Audio", "Programs"]

    onActiveChanged: if (!active) MicLevel.testing = false
    Component.onDestruction: MicLevel.testing = false

    readonly property var players: Mpris.players.values.filter(p => !p.dbusName.includes("playerctld"))
    property MprisPlayer chosen: null
    readonly property MprisPlayer player: chosen && players.includes(chosen) ? chosen
        : players.find(p => p.isPlaying) ?? players[0] ?? null
    Timer { running: root.player?.isPlaying ?? false; interval: 1000; repeat: true; onTriggered: root.player.positionChanged() }
    function fmt(s) { s = Math.max(0, Math.floor(s)); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0"); }

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream)
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property var sources: Pipewire.nodes.values.filter(n => n.audio && !n.isSink && !n.isStream
        && n.properties?.["media.class"] === "Audio/Source")
    readonly property var streams: Pipewire.nodes.values.filter(n => n.audio && n.isStream
        && n.properties?.["media.class"] === "Stream/Output/Audio")
    PwObjectTracker { objects: [root.sink, root.source].filter(n => n).concat(root.sinks, root.sources, root.streams) }
    function deviceName(n) { return n?.nickname || n?.description || n?.name || ""; }

    // ---------------------------------------------------------------- Now Playing
    Column {
        spacing: 10
        Txt { visible: !root.player; text: "Nothing is playing." }
        Row {
            visible: root.players.length > 1
            spacing: 8
            Txt { height: Theme.field; text: "Player:" }
            Combo {
                width: 260
                model: root.players
                textOf: p => p.identity || p.dbusName
                currentIndex: root.players.indexOf(root.player)
                onChosen: i => root.chosen = root.players[i]
            }
        }
        Row {
            visible: !!root.player
            spacing: 14
            Bevel {
                kind: "sunken"
                fill: "#000000"
                width: 132; height: 132
                ClippingRectangle {
                    anchors.fill: parent
                    anchors.margins: 2
                    color: "transparent"
                    Image { anchors.fill: parent; source: root.player?.trackArtUrl ?? ""; fillMode: Image.PreserveAspectCrop; asynchronous: true }
                }
                Icon { anchors.centerIn: parent; visible: !(root.player?.trackArtUrl); name: "media-optical-audio"; size: 48 }
            }
            Column {
                width: root.width - 190
                spacing: 4
                Txt { width: parent.width; elide: Text.ElideRight; bold: true; text: root.player?.trackTitle || "Unknown title" }
                Txt { width: parent.width; elide: Text.ElideRight; text: root.player?.trackArtist ?? "" }
                Txt { width: parent.width; elide: Text.ElideRight; text: root.player?.trackAlbum ?? ""; color: Theme.grayText }
                Txt { text: root.player?.identity ?? ""; color: Theme.grayText }
            }
        }
        TrackBar {
            visible: !!root.player
            width: parent.width
            ticks: 0
            enabled: (root.player?.canSeek ?? false) && (root.player?.length ?? 0) > 0
            value: root.player && root.player.length > 0 ? root.player.position / root.player.length : 0
            onMoved: v => root.player.position = v * root.player.length
        }
        Item {
            visible: !!root.player
            width: parent.width; height: 20
            Txt { text: root.fmt(root.player?.position ?? 0) }
            Txt { anchors.right: parent.right; text: root.fmt(root.player?.length ?? 0) }
        }
        Row {
            visible: !!root.player
            spacing: 4
            Btn { width: 48; implicitWidth: 48; padding: 0; glyph: "prev"; enabled: !!root.player?.canGoPrevious; onClicked: root.player.previous() }
            Btn { width: 64; implicitWidth: 64; padding: 0; glyph: root.player?.isPlaying ? "pause" : "play"; isDefault: true; onClicked: root.player.togglePlaying() }
            Btn { width: 48; implicitWidth: 48; padding: 0; glyph: "stop"; enabled: !!root.player?.canControl; onClicked: root.player.stop() }
            Btn { width: 48; implicitWidth: 48; padding: 0; glyph: "next"; enabled: !!root.player?.canGoNext; onClicked: root.player.next() }
        }
        // the spectrum (cava), in 98's LCD green on black
        Bevel {
            width: parent.width
            height: 70
            kind: "sunken"
            fill: Theme.lcd
            Row {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 3
                Repeater {
                    model: Radio.count
                    Rectangle {
                        required property int index
                        width: 9
                        height: Math.max(1, (Radio.bars[index] ?? 0) * Radio.gain * 58)
                        anchors.bottom: parent.bottom
                        color: Theme.lcdText
                    }
                }
            }
        }
        Btn { text: "Media Player…"; onClicked: Desk.show("media") }
    }

    // ---------------------------------------------------------------- Audio
    Column {
        spacing: 10
        Group {
            title: "Playback"
            width: parent.width
            Row {
                spacing: 10
                Icon { name: "audio-speakers"; size: 32 }
                Column {
                    spacing: 4
                    Txt { text: "Preferred device:" }
                    Combo {
                        width: 380
                        model: root.sinks
                        textOf: n => root.deviceName(n)
                        currentIndex: root.sinks.indexOf(root.sink)
                        onChosen: i => Pipewire.preferredDefaultAudioSink = root.sinks[i]
                    }
                }
            }
            Row {
                spacing: 10
                Txt { width: 64; height: 34; text: "Volume:" }
                TrackBar {
                    width: 300
                    value: root.sink?.audio?.volume ?? 0
                    onMoved: v => { if (root.sink?.audio) root.sink.audio.volume = v; }
                }
                Check { text: "Mute"; checked: root.sink?.audio?.muted ?? false; onToggled: root.sink.audio.muted = !root.sink.audio.muted }
            }
        }
        Group {
            title: "Recording"
            width: parent.width
            Row {
                spacing: 10
                Icon { name: "audio-input-microphone"; size: 32 }
                Column {
                    spacing: 4
                    Txt { text: "Preferred device:" }
                    Combo {
                        width: 380
                        model: root.sources
                        textOf: n => root.deviceName(n)
                        currentIndex: root.sources.indexOf(root.source)
                        onChosen: i => Pipewire.preferredDefaultAudioSource = root.sources[i]
                    }
                }
            }
            Row {
                spacing: 10
                Txt { width: 64; height: 34; text: "Volume:" }
                TrackBar {
                    width: 300
                    value: root.source?.audio?.volume ?? 0
                    onMoved: v => { if (root.source?.audio) root.source.audio.volume = v; }
                }
                Check { text: "Mute"; checked: root.source?.audio?.muted ?? false; onToggled: root.source.audio.muted = !root.source.audio.muted }
            }
            Row {
                spacing: 10
                Btn {
                    text: MicLevel.testing ? "Stop Test" : "Test"
                    onClicked: MicLevel.testing = !MicLevel.testing
                }
                // the meter: 98's green LED blocks
                Progress {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 330
                    height: 22
                    color: "#00a000"
                    value: MicLevel.bars.length ? Math.min(1, MicLevel.bars.reduce((a, b) => Math.max(a, b), 0) * 1.4) : 0
                }
            }
        }
        Btn { text: "Volume Control…"; onClicked: Desk.show("volume") }
    }

    // ---------------------------------------------------------------- Programs
    Column {
        spacing: 6
        Txt { visible: root.streams.length === 0; text: "No programs are playing sound right now." }
        Repeater {
            model: root.streams
            Row {
                required property var modelData
                spacing: 8
                Icon { name: modelData.properties?.["application.icon-name"] || "audio-x-generic"; size: 24; anchors.verticalCenter: parent.verticalCenter }
                Txt {
                    width: 150
                    height: 34
                    elide: Text.ElideRight
                    text: modelData.properties?.["application.name"] || modelData.name || "Program"
                }
                TrackBar {
                    width: 220
                    ticks: 0
                    value: modelData.audio?.volume ?? 0
                    onMoved: v => { if (modelData.audio) modelData.audio.volume = v; }
                }
                Check { text: "Mute"; anchors.verticalCenter: parent.verticalCenter; checked: modelData.audio?.muted ?? false; onToggled: modelData.audio.muted = !modelData.audio.muted }
            }
        }
    }
}
