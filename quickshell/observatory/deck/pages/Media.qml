import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import "../../theme"
import "../../services"
import ".."

// Radio: what's playing (the cover as a slowly turning planet in a brass ring), seek and transport,
// the spectrum while it plays, then the speakers, every app's volume, and the outputs and inputs.
Column {
    id: root

    spacing: 22

    // ---------------------------------------------------------------- players
    readonly property var players: Mpris.players.values.filter(p => !p.dbusName.includes("playerctld"))
    property MprisPlayer chosen: null
    readonly property MprisPlayer player: chosen && players.includes(chosen) ? chosen
        : players.find(p => p.isPlaying) ?? players[0] ?? null

    function fmt(s) {
        s = Math.max(0, Math.floor(s));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }
    // Position only updates when asked
    Timer {
        running: root.player?.isPlaying ?? false
        interval: 1000
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    // ---------------------------------------------------------------- audio nodes
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream)
    readonly property PwNode source: Pipewire.defaultAudioSource
    // Track every candidate, then filter: a node's properties (media.class) only arrive once it's tracked
    readonly property var allSources: Pipewire.nodes.values.filter(n => n.audio && !n.isSink && !n.isStream)
    readonly property var sources: allSources.filter(n => n.properties?.["media.class"] === "Audio/Source")
    readonly property var allStreams: Pipewire.nodes.values.filter(n => n.audio && n.isStream)
    readonly property var streams: allStreams.filter(n => n.properties?.["media.class"] === "Stream/Output/Audio")
    PwObjectTracker { objects: [root.sink, root.source].filter(n => n).concat(root.sinks, root.allSources, root.allStreams) }

    function deviceName(n) { return n?.nickname || n?.description || n?.name || ""; }

    // ---------------------------------------------------------------- now playing
    Section {
        title: "now playing"
        trailing: root.player ? (root.player.identity || "").toLowerCase() : ""

        // Player chips when there's more than one
        Flow {
            width: parent.width
            spacing: 8
            visible: root.players.length > 1
            Repeater {
                model: root.players
                Link {
                    required property var modelData
                    text: (modelData.identity || "player").toLowerCase()
                    primary: modelData === root.player
                    onClicked: root.chosen = modelData
                }
            }
        }

        Text {
            visible: !root.player
            text: "no signal · nothing is playing"
            color: Theme.dim
            font.family: Theme.fontData
            font.pixelSize: Theme.dataSize
        }

        Item {
            visible: !!root.player
            width: parent.width
            height: Theme.coverSize + 12

            // Cover art as a planet: round, in a brass ring, turning slowly while it plays
            Item {
                id: planet
                width: Theme.coverSize
                height: Theme.coverSize
                anchors.verticalCenter: parent.verticalCenter
                ClippingRectangle {
                    anchors.fill: parent
                    anchors.margins: 5
                    radius: width / 2
                    color: Theme.surface
                    Image {
                        anchors.fill: parent
                        source: root.player?.trackArtUrl ?? ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        RotationAnimation on rotation {
                            from: 0; to: 360; duration: 40000
                            loops: Animation.Infinite
                            running: root.player?.isPlaying ?? false
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: (root.player?.trackArtUrl ?? "") === ""
                        text: "\u{f075a}"
                        color: Theme.brass
                        font.family: Theme.fontData
                        font.pixelSize: 34
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    border.width: 1.5
                    border.color: Theme.brass
                }
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -5
                    radius: width / 2
                    color: "transparent"
                    border.width: 0.8
                    border.color: Theme.alpha(Theme.brass, 0.35)
                }
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true; shadowColor: Theme.brass; shadowBlur: 0.5; shadowOpacity: 0.5
                    shadowHorizontalOffset: 0; shadowVerticalOffset: 0; blurMax: 16
                }
            }

            Column {
                anchors.left: planet.right
                anchors.leftMargin: 18
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                    text: root.player?.trackTitle || "untitled"
                    color: Theme.brassBright
                    font.family: Theme.fontLabel
                    font.pixelSize: Theme.labelSizeLarge + 6
                    font.weight: Font.DemiBold
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: root.player?.trackArtist ?? ""
                    color: Theme.fg
                    font.family: Theme.fontData
                    font.pixelSize: Theme.dataSize
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    visible: text !== ""
                    text: root.player?.trackAlbum ?? ""
                    color: Theme.dim
                    font.family: Theme.fontData
                    font.pixelSize: Theme.dataSizeSmall
                }
            }
        }

        // Seek
        Column {
            visible: root.player?.lengthSupported ?? false
            width: parent.width
            spacing: 2
            Dial {
                width: parent.width
                enabled: root.player?.canSeek ?? false
                value: root.player && root.player.length > 0 ? root.player.position / root.player.length : 0
                ink: Theme.brassBright
                onMoved: v => root.player.position = v * root.player.length
            }
            Item {
                width: parent.width
                height: 14
                Text {
                    text: root.fmt(root.player?.position ?? 0)
                    color: Theme.dim
                    font.family: Theme.fontData
                    font.pixelSize: Theme.dataSizeSmall
                }
                Text {
                    anchors.right: parent.right
                    text: root.fmt(root.player?.length ?? 0)
                    color: Theme.dim
                    font.family: Theme.fontData
                    font.pixelSize: Theme.dataSizeSmall
                }
            }
        }

        // Transport
        Row {
            visible: !!root.player
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 22
            Knob {
                anchors.verticalCenter: parent.verticalCenter
                glyph: "\u{f049d}"; size: 34
                enabled: root.player?.shuffleSupported ?? false
                active: root.player?.shuffle ?? false
                onClicked: root.player.shuffle = !root.player.shuffle
            }
            Knob {
                anchors.verticalCenter: parent.verticalCenter
                glyph: "\u{f04ae}"; size: 40
                enabled: root.player?.canGoPrevious ?? false
                onClicked: root.player.previous()
            }
            Knob {
                anchors.verticalCenter: parent.verticalCenter
                glyph: root.player?.isPlaying ? "\u{f03e4}" : "\u{f040a}"; size: 54
                active: root.player?.isPlaying ?? false
                onClicked: root.player.togglePlaying()
            }
            Knob {
                anchors.verticalCenter: parent.verticalCenter
                glyph: "\u{f04ad}"; size: 40
                enabled: root.player?.canGoNext ?? false
                onClicked: root.player.next()
            }
            Knob {
                anchors.verticalCenter: parent.verticalCenter
                glyph: root.player?.loopState === MprisLoopState.Track ? "\u{f0458}" : "\u{f0456}"; size: 34
                enabled: root.player?.loopSupported ?? false
                active: (root.player?.loopState ?? MprisLoopState.None) !== MprisLoopState.None
                onClicked: root.player.loopState = root.player.loopState === MprisLoopState.None ? MprisLoopState.Playlist
                    : root.player.loopState === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None
            }
        }
    }

    // ---------------------------------------------------------------- mixer
    Section {
        title: "mixer"
        trailing: root.sink ? Math.round((root.sink.audio?.volume ?? 0) * 100) + "%" : ""

        Vol { node: root.sink; label: "speakers"; detail: root.deviceName(root.sink); glyph: "\u{f057e}" }
        Repeater {
            model: root.streams
            Vol {
                required property var modelData
                node: modelData
                label: (modelData.properties?.["application.name"] || modelData.name || "app").toLowerCase()
                detail: modelData.properties?.["media.name"] ?? ""
                icon: modelData.properties?.["application.icon-name"] ?? ""
                glyph: "\u{f075a}"
            }
        }
        Text {
            visible: root.streams.length === 0
            text: "no apps playing sound"
            color: Theme.dim
            font.family: Theme.fontData
            font.pixelSize: Theme.dataSizeSmall
        }
    }

    // ---------------------------------------------------------------- devices
    Section {
        title: "outputs"
        Repeater {
            model: root.sinks
            ListRow {
                required property var modelData
                glyph: "\u{f04c3}"
                title: root.deviceName(modelData)
                subtitle: modelData.properties?.["device.profile.description"] ?? ""
                active: modelData === root.sink
                trailing: active ? "in use" : ""
                trailingColor: Theme.phosphor
                onClicked: Pipewire.preferredDefaultAudioSink = modelData
            }
        }
    }
    Section {
        title: "inputs"
        trailing: root.source ? Math.round((root.source.audio?.volume ?? 0) * 100) + "%" : ""
        Vol { node: root.source; label: "microphone"; detail: root.deviceName(root.source); glyph: "\u{f036c}" }
        Repeater {
            model: root.sources
            ListRow {
                required property var modelData
                glyph: "\u{f036c}"
                title: root.deviceName(modelData)
                active: modelData === root.source
                trailing: active ? "in use" : ""
                trailingColor: Theme.phosphor
                onClicked: Pipewire.preferredDefaultAudioSource = modelData
            }
        }
    }

    // A volume row: mute knob (the app icon when there is one), name, dial
    component Vol: Item {
        id: v
        property PwNode node
        property string label
        property string detail
        property string glyph
        property string icon: ""
        readonly property bool muted: node?.audio?.muted ?? false
        width: parent.width
        height: 44
        Knob {
            id: mute
            size: 32
            anchors.verticalCenter: parent.verticalCenter
            glyph: v.muted ? "\u{f0581}" : (appIcon.visible ? "" : v.glyph)
            danger: v.muted
            active: v.muted
            onClicked: if (v.node?.audio) v.node.audio.muted = !v.node.audio.muted
            IconImage {
                id: appIcon
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -((parent.implicitHeight - 32) / 2)
                visible: !v.muted && v.icon !== "" && Quickshell.hasThemeIcon(v.icon)
                implicitSize: 16
                source: visible ? Quickshell.iconPath(v.icon) : ""
            }
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
                text: v.label + (v.detail ? "  ·  " + v.detail : "") + "  ·  " + Math.round((v.node?.audio?.volume ?? 0) * 100) + "%"
                color: Theme.fg
                font.family: Theme.fontData
                font.pixelSize: Theme.dataSizeSmall
            }
            Dial {
                width: parent.width
                value: v.node?.audio?.volume ?? 0
                ink: v.muted ? Theme.dim : Theme.phosphor
                onMoved: x => { if (v.node?.audio) v.node.audio.volume = x; }
            }
        }
    }
}
