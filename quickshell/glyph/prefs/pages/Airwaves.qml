import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import "../../theme"
import "../../widgets"
import "../../services"
import ".."

// SOUND: what's playing (the art as turning dots, the track, the progress strip, the red play
// button, the spectrum as a matrix of dots), every program's level, the outputs and inputs.
Column {
    id: root

    spacing: 34

    readonly property var players: Mpris.players.values.filter(p => !p.dbusName.includes("playerctld"))
    property MprisPlayer chosen: null
    readonly property MprisPlayer player: chosen && players.includes(chosen) ? chosen : players.find(p => p.isPlaying) ?? players[0] ?? null
    function fmt(s) { s = Math.max(0, Math.floor(s)); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0"); }
    property real pos: 0
    Timer { running: !!root.player; interval: 1000; repeat: true; triggeredOnStart: true; onTriggered: root.pos = root.player?.position ?? 0 }

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream)
    readonly property PwNode source: Pipewire.defaultAudioSource
    // Track every candidate, then filter: a node's properties (media.class) only arrive once it's tracked
    readonly property var allSources: Pipewire.nodes.values.filter(n => n.audio && !n.isSink && !n.isStream)
    readonly property var sources: allSources.filter(n => n.properties?.["media.class"] === "Audio/Source")
    readonly property var allStreams: Pipewire.nodes.values.filter(n => n.audio && n.isStream)
    readonly property var streams: allStreams.filter(n => n.properties?.["media.class"] === "Stream/Output/Audio")
    PwObjectTracker { objects: [root.sink, root.source].filter(n => n).concat(root.sinks, root.allSources, root.allStreams) }
    function name(n) { return n?.nickname || n?.description || n?.name || ""; }

    Section {
        title: "now playing"
        trailing: root.player ? (root.player.identity || "") : "silence"
        Flow {
            visible: root.players.length > 1
            width: parent.width
            spacing: 8
            Repeater { model: root.players; Btn { required property var modelData; text: modelData.identity || "player"; on: modelData === root.player; onClicked: root.chosen = modelData } }
        }
        Row {
            spacing: 30
            Item {
                id: art
                width: 180
                height: 180
                property real turn: 0
                Timer { running: !!root.player?.isPlaying; interval: 33; repeat: true; onTriggered: art.turn = (art.turn + 360 / 14 / 30) % 360 }
                Art { anchors.fill: parent; rotation: art.turn; url: root.player?.trackArtUrl ?? ""; step: 6 }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: root.width - 210
                Text { width: parent.width; elide: Text.ElideRight; text: root.player?.trackTitle || "Nothing on"; color: Theme.fg
                       font { family: Theme.ui; pixelSize: 30; weight: Font.DemiBold } }
                Text { width: parent.width; elide: Text.ElideRight; text: [root.player?.trackArtist, root.player?.trackAlbum].filter(Boolean).join(" · "); color: Theme.grey
                       font { family: Theme.ui; pixelSize: 16 } }
                Item { width: 1; height: 22 }
                Item {
                    width: parent.width
                    height: 6
                    Seg { anchors.fill: parent; n: 32; f: root.player && root.player.length > 0 ? root.pos / root.player.length : 0 }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -8
                        enabled: (root.player?.canSeek ?? false) && (root.player?.length ?? 0) > 0
                        cursorShape: Qt.PointingHandCursor
                        onClicked: e => root.player.position = Math.max(0, Math.min(1, e.x / width)) * root.player.length
                    }
                }
                Item {
                    width: parent.width
                    height: 26
                    Lb { y: 10; text: root.fmt(root.pos); px: 10 }
                    Lb { y: 10; anchors.right: parent.right; text: root.fmt(root.player?.length ?? 0); px: 10 }
                }
                Row {
                    spacing: 26
                    Controls { player: root.player; size: 22; play: 52 }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 44
                        height: 44
                        radius: 22
                        color: root.player?.shuffle ? Theme.fg : Theme.s2
                        opacity: root.player?.shuffleSupported ? 1 : 0.35
                        Icon { anchors.centerIn: parent; text: "\u{F049D}"; font.pixelSize: 18; color: root.player?.shuffle ? Theme.ink : Theme.fg }
                        TapHandler { enabled: !!root.player?.shuffleSupported; onTapped: root.player.shuffle = !root.player.shuffle }
                    }
                }
            }
        }
        // the spectrum: a column of dots per band, lit from the bottom, the top one white
        Grid {
            width: root.width
            columns: Radio.count
            spacing: 0
            Repeater {
                model: Radio.count * 8
                Item {
                    required property int index
                    readonly property int c: index % Radio.count
                    readonly property int up: 8 - Math.floor(index / Radio.count)
                    readonly property int h: Math.round((Radio.bars[c] ?? 0) * Radio.gain * 8)
                    width: root.width / Radio.count
                    height: 12
                    Rectangle {
                        anchors.centerIn: parent
                        width: 6
                        height: 6
                        radius: 3
                        color: parent.up === parent.h ? Theme.fg : parent.up < parent.h ? Theme.grey : Theme.s2
                    }
                }
            }
        }
    }

    Section {
        title: "mixer"
        trailing: root.streams.length ? root.streams.length + " playing" : ""
        Level { label: "speakers"; glyph: "\u{F057E}"; node: root.sink }
        Level { label: "mic"; glyph: "\u{F036C}"; node: root.source }
        Repeater {
            model: root.streams
            Level { required property var modelData; node: modelData; glyph: "\u{F0F74}"
                    label: (modelData.properties?.["application.name"] || modelData.name || "app") }
        }
    }

    Section {
        title: "outputs"
        Repeater { model: root.sinks
            Row2 { required property var modelData; glyph: "\u{F04C3}"; title: root.name(modelData); active: modelData === root.sink
                   subtitle: modelData === root.sink ? "default" : ""
                   onClicked: Pipewire.preferredDefaultAudioSink = modelData } }
    }
    Section {
        title: "inputs"
        Repeater { model: root.sources
            Row2 { required property var modelData; glyph: "\u{F036C}"; title: root.name(modelData); active: modelData === root.source
                   subtitle: modelData === root.source ? "default" : ""
                   onClicked: Pipewire.preferredDefaultAudioSource = modelData } }
        Row {
            spacing: 18
            Btn { text: MicLevel.testing ? "stop test" : "mic test"; on: MicLevel.testing; onClicked: MicLevel.testing = !MicLevel.testing }
            Seg { anchors.verticalCenter: parent.verticalCenter; width: 360; height: 8; n: 24; on: Theme.fg
                  f: MicLevel.bars.length ? Math.min(1, MicLevel.bars.reduce((a, b) => Math.max(a, b), 0) * 1.4) : 0 }
        }
    }
    Component.onDestruction: MicLevel.testing = false

    // a level: the name over the pill slider; click the name to mute
    component Level: Column {
        id: lv
        property string label
        property string glyph
        property PwNode node
        readonly property bool muted: node?.audio?.muted ?? false
        width: parent.width
        spacing: 8
        Item {
            width: parent.width
            height: 14
            Lb { text: lv.label; px: 11; color: lv.muted ? Theme.red : Theme.grey
                 MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: if (lv.node?.audio) lv.node.audio.muted = !lv.node.audio.muted } }
            Lb { anchors.right: parent.right; text: lv.muted ? "muted" : ""; color: Theme.red; px: 10 }
        }
        Slider { width: parent.width; height: 48; glyph: lv.muted ? "\u{F075F}" : lv.glyph
                 value: lv.muted ? 0 : lv.node?.audio?.volume ?? 0
                 onMoved: v => { if (lv.node?.audio) { lv.node.audio.muted = false; lv.node.audio.volume = v; } } }
    }
}
