import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import "../../theme"
import "../../widgets"
import "../../services"
import ".."

// III. Minstrelsy: what the minstrels play (the cover in a gilt frame, the song, seek, the
// transport, its music as a row of ink strokes), every program's voice, and where sound goes and
// comes from.
Column {
    id: root

    spacing: 22

    readonly property var players: Mpris.players.values.filter(p => !p.dbusName.includes("playerctld"))
    property MprisPlayer chosen: null
    readonly property MprisPlayer player: chosen && players.includes(chosen) ? chosen : players.find(p => p.isPlaying) ?? players[0] ?? null
    function fmt(s) { s = Math.max(0, Math.floor(s)); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0"); }
    Timer { running: root.player?.isPlaying ?? false; interval: 1000; repeat: true; onTriggered: root.player.positionChanged() }

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream)
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property var sources: Pipewire.nodes.values.filter(n => n.audio && !n.isSink && !n.isStream && n.properties?.["media.class"] === "Audio/Source")
    readonly property var streams: Pipewire.nodes.values.filter(n => n.audio && n.isStream && n.properties?.["media.class"] === "Stream/Output/Audio")
    PwObjectTracker { objects: [root.sink, root.source].filter(n => n).concat(root.sinks, root.sources, root.streams) }
    function name(n) { return n?.nickname || n?.description || n?.name || ""; }

    Section {
        title: "now playing"
        trailing: root.player ? (root.player.identity || "") : "silence"
        Flow {
            visible: root.players.length > 1
            width: parent.width
            spacing: 6
            Repeater { model: root.players; Btn { required property var modelData; text: modelData.identity || "player"; on: modelData === root.player; onClicked: root.chosen = modelData } }
        }
        Body { visible: !root.player; text: "No minstrel plays."; italic: true; color: Theme.inkDim }
        Row {
            visible: !!root.player
            spacing: 16
            Item {
                width: 112; height: 112
                Rectangle { anchors.fill: parent; color: Theme.ink; border.width: 3; border.color: Theme.gold }
                Rectangle { anchors.fill: parent; anchors.margins: 5; color: "transparent"; border.width: 1; border.color: Theme.goldDeep }
                ClippingRectangle {
                    anchors.fill: parent; anchors.margins: 7; color: Theme.alpha(Theme.ink, 0.6)
                    Image { anchors.fill: parent; source: root.player?.trackArtUrl ?? ""; fillMode: Image.PreserveAspectCrop; asynchronous: true }
                }
            }
            Column {
                width: root.width - 130
                spacing: 3
                Text { width: parent.width; elide: Text.ElideRight; text: root.player?.trackTitle || "an untitled air"; color: Theme.ink
                       font.family: Theme.uncial; font.pixelSize: 20 }
                Body { width: parent.width; elide: Text.ElideRight; text: root.player?.trackArtist ?? ""; italic: true }
                Body { width: parent.width; elide: Text.ElideRight; text: root.player?.trackAlbum ?? ""; italic: true; color: Theme.inkDim; font.pixelSize: 13 }
                Item { width: 1; height: 8 }
                Row {
                    spacing: 6
                    Btn { glyph: "\u{f04ae}"; enabled: !!root.player?.canGoPrevious; onClicked: root.player.previous() }
                    Btn { glyph: root.player?.isPlaying ? "\u{f03e4}" : "\u{f040a}"; primary: true; onClicked: root.player.togglePlaying() }
                    Btn { glyph: "\u{f04ad}"; enabled: !!root.player?.canGoNext; onClicked: root.player.next() }
                    Btn { glyph: "\u{f049d}"; on: root.player?.shuffle ?? false; enabled: !!root.player?.shuffleSupported; onClicked: root.player.shuffle = !root.player.shuffle }
                }
            }
        }
        Item {
            visible: !!root.player
            width: parent.width; height: 34
            Slider { width: parent.width; color: Theme.rubric
                     enabled: (root.player?.canSeek ?? false) && (root.player?.length ?? 0) > 0
                     value: root.player && root.player.length > 0 ? root.player.position / root.player.length : 0
                     onMoved: v => root.player.position = v * root.player.length }
            Body { y: 16; text: root.fmt(root.player?.position ?? 0); italic: true; color: Theme.inkDim; font.pixelSize: 13 }
            Body { y: 16; anchors.right: parent.right; text: root.fmt(root.player?.length ?? 0); italic: true; color: Theme.inkDim; font.pixelSize: 13 }
        }
        // the music, as strokes of ink
        Item {
            visible: Radio.active
            width: parent.width; height: 44
            Row {
                anchors.bottom: parent.bottom
                spacing: 3
                Repeater { model: Radio.count
                    Rectangle { required property int index; anchors.bottom: parent.bottom; width: (root.width - (Radio.count - 1) * 3) / Radio.count
                                radius: width / 2
                                height: Math.max(2, (Radio.bars[index] ?? 0) * Radio.gain * 44)
                                color: Theme.mix(Theme.goldDeep, Theme.rubric, index / Radio.count) } }
            }
        }
    }

    Section {
        title: "the mixer"
        trailing: root.sink ? "the voice at " + Math.round((root.sink.audio?.volume ?? 0) * 100) + "%" : ""
        Level { label: "voice"; node: root.sink }
        Level { label: "ear"; node: root.source; tint: Theme.rubric }
        Repeater {
            model: root.streams
            Level { required property var modelData; node: modelData
                    label: (modelData.properties?.["application.name"] || modelData.name || "a program") }
        }
        Body { visible: root.streams.length === 0; text: "No program is singing."; italic: true; color: Theme.inkDim }
    }

    Section {
        title: "where sound goes"
        Repeater { model: root.sinks
            Row2 { required property var modelData; glyph: "\u{f04c3}"; title: root.name(modelData); active: modelData === root.sink
                   onClicked: Pipewire.preferredDefaultAudioSink = modelData } }
    }
    Section {
        title: "where it's heard"
        Repeater { model: root.sources
            Row2 { required property var modelData; glyph: "\u{f036c}"; title: root.name(modelData); active: modelData === root.source
                   onClicked: Pipewire.preferredDefaultAudioSource = modelData } }
        Row {
            spacing: 12
            Btn { text: MicLevel.testing ? "enough" : "test the ear"; on: MicLevel.testing; onClicked: MicLevel.testing = !MicLevel.testing }
            Meter { anchors.verticalCenter: parent.verticalCenter; width: root.width - 170; height: 10; color: Theme.rubric
                    value: MicLevel.bars.length ? Math.min(1, MicLevel.bars.reduce((a, b) => Math.max(a, b), 0) * 1.4) : 0 }
        }
    }
    Component.onDestruction: MicLevel.testing = false

    component Level: Item {
        id: lv
        property string label
        property PwNode node
        property color tint: Theme.gold
        width: parent.width
        height: 24
        Caps { width: 100; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter; text: lv.label
               color: lv.node?.audio?.muted ? Theme.rubric : Theme.inkDim
               MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (lv.node?.audio) lv.node.audio.muted = !lv.node.audio.muted } }
        Slider { x: 108; width: parent.width - 166; anchors.verticalCenter: parent.verticalCenter
                 color: lv.node?.audio?.muted ? Theme.inkDim : lv.tint
                 value: lv.node?.audio?.volume ?? 0; onMoved: v => { if (lv.node?.audio) lv.node.audio.volume = v; } }
        Body { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; strong: true
               text: lv.node?.audio?.muted ? "hushed" : Math.round((lv.node?.audio?.volume ?? 0) * 100) + "%" }
    }
}
