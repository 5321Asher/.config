import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import "../../theme"
import "../../widgets"
import "../../services"
import ".."

// 03 RADIO 音響: what's playing (cover, seek, transport, the spectrum), every program's volume,
// and the outputs and inputs.
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
    // Track every candidate, then filter: a node's properties (media.class) only arrive once it's tracked
    readonly property var allSources: Pipewire.nodes.values.filter(n => n.audio && !n.isSink && !n.isStream)
    readonly property var sources: allSources.filter(n => n.properties?.["media.class"] === "Audio/Source")
    readonly property var allStreams: Pipewire.nodes.values.filter(n => n.audio && n.isStream)
    readonly property var streams: allStreams.filter(n => n.properties?.["media.class"] === "Stream/Output/Audio")
    PwObjectTracker { objects: [root.sink, root.source].filter(n => n).concat(root.sinks, root.allSources, root.allStreams) }
    function name(n) { return n?.nickname || n?.description || n?.name || ""; }

    Section {
        title: "now playing"
        jp: "再生中"
        trailing: root.player ? (root.player.identity || "") : "no carrier"
        Flow {
            visible: root.players.length > 1
            width: parent.width
            spacing: 6
            Repeater { model: root.players; Btn { required property var modelData; text: modelData.identity || "player"; on: modelData === root.player; onClicked: root.chosen = modelData } }
        }
        Row {
            visible: !!root.player
            spacing: 14
            Item {
                width: 110; height: 110
                Chamfer { anchors.fill: parent; cut: 10; corners: "tr bl"; fill: Theme.bgDark; stroke: Theme.alpha(Theme.cyan, 0.6) }
                ClippingRectangle {
                    anchors.fill: parent; anchors.margins: 4; color: "transparent"
                    Image { anchors.fill: parent; source: root.player?.trackArtUrl ?? ""; fillMode: Image.PreserveAspectCrop; asynchronous: true }
                }
            }
            Column {
                width: root.width - 130
                spacing: 4
                Text { width: parent.width; elide: Text.ElideRight; text: root.player?.trackTitle || "unknown"; color: Theme.bright
                       font.family: Theme.display; font.pixelSize: 20; font.weight: Font.Bold }
                Label { width: parent.width; elide: Text.ElideRight; text: root.player?.trackArtist ?? ""; color: Theme.cyan }
                Label { width: parent.width; elide: Text.ElideRight; text: root.player?.trackAlbum ?? "" }
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
            width: parent.width; height: 26
            Slider { width: parent.width; height: 6; blocks: 60; color: Theme.red
                     enabled: (root.player?.canSeek ?? false) && (root.player?.length ?? 0) > 0
                     value: root.player && root.player.length > 0 ? root.player.position / root.player.length : 0
                     onMoved: v => root.player.position = v * root.player.length }
            Label { y: 10; text: root.fmt(root.player?.position ?? 0) }
            Label { y: 10; anchors.right: parent.right; text: root.fmt(root.player?.length ?? 0) }
        }
        // A fixed 40 px strip: a Row as tall as its tallest bar resized every frame and bounced the
        // page below it (and appearing / vanishing with playback shifted it too)
        Item {
            width: root.width
            height: 40
            Row {
                anchors.bottom: parent.bottom
                spacing: 2
                Repeater { model: Radio.count
                    Rectangle { required property int index; anchors.bottom: parent.bottom; width: (root.width - (Radio.count - 1) * 2) / Radio.count
                                height: Math.max(1, (Radio.bars[index] ?? 0) * Radio.gain * 40); color: Theme.cyan } }
            }
        }
    }

    Section {
        title: "mixer"
        jp: "混合"
        trailing: root.sink ? Math.round((root.sink.audio?.volume ?? 0) * 100) + "%" : ""
        Level { label: "speakers"; node: root.sink }
        Level { label: "mic"; node: root.source; tint: Theme.red }
        Repeater {
            model: root.streams
            Level { required property var modelData; node: modelData
                    label: (modelData.properties?.["application.name"] || modelData.name || "app") }
        }
        Label { visible: root.streams.length === 0; text: "no programs playing" }
    }

    Section {
        title: "outputs"
        jp: "出力"
        Repeater { model: root.sinks
            Row2 { required property var modelData; glyph: "\u{f04c3}"; title: root.name(modelData); active: modelData === root.sink
                   onClicked: Pipewire.preferredDefaultAudioSink = modelData } }
    }
    Section {
        title: "inputs"
        jp: "入力"
        Repeater { model: root.sources
            Row2 { required property var modelData; glyph: "\u{f036c}"; title: root.name(modelData); active: modelData === root.source
                   onClicked: Pipewire.preferredDefaultAudioSource = modelData } }
        Row {
            spacing: 10
            Btn { text: MicLevel.testing ? "stop test" : "mic test"; on: MicLevel.testing; onClicked: MicLevel.testing = !MicLevel.testing }
            Blocks { anchors.verticalCenter: parent.verticalCenter; count: 24; blockWidth: 8; blockHeight: 12; color: Theme.red
                     value: MicLevel.bars.length ? Math.min(1, MicLevel.bars.reduce((a, b) => Math.max(a, b), 0) * 1.4) : 0 }
        }
    }
    Component.onDestruction: MicLevel.testing = false

    component Level: Item {
        id: lv
        property string label
        property PwNode node
        property color tint: Theme.cyan
        width: parent.width
        height: 20
        Label { width: 100; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter; text: lv.label
                color: lv.node?.audio?.muted ? Theme.red : Theme.dim
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (lv.node?.audio) lv.node.audio.muted = !lv.node.audio.muted } }
        Slider { x: 108; width: parent.width - 160; height: 12; anchors.verticalCenter: parent.verticalCenter
                 color: lv.node?.audio?.muted ? Theme.dim : lv.tint
                 value: lv.node?.audio?.volume ?? 0; onMoved: v => { if (lv.node?.audio) lv.node.audio.volume = v; } }
        Label { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; strong: true
                text: lv.node?.audio?.muted ? "MUTE" : Math.round((lv.node?.audio?.volume ?? 0) * 100) + "%" }
    }
}
