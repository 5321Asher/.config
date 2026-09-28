import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Widgets
import "../../theme"
import "../../widgets"
import "../../services"
import "../../menus"
import ".."

// Media Player, after 98's Windows Media Player: the black picture area (the album art, with the
// spectrum along its foot while it plays), the seek bar, the transport buttons, the black clip
// panel ("Clip: … Author: …") and the status bar. It drives whichever MPRIS player is playing
// (Play → Player picks another).
Win {
    id: root

    title: (player?.trackTitle ? player.trackTitle + " - " : "") + "Media Player"
    icon: "applications-multimedia"
    minButton: true
    onMinRequested: closeRequested()
    status: !player ? "Ready" : player.isPlaying ? "Playing" : player.playbackState === MprisPlaybackState.Paused ? "Paused" : "Stopped"
    statusParts: [player && player.length > 0 ? fmt(player.position) + " / " + fmt(player.length) : "00:00"]
    menus: [
        { title: "Play", items: () => [
            { text: player?.isPlaying ? "Pause" : "Play", bold: true, enabled: !!player, run: () => player.togglePlaying() },
            { text: "Stop", enabled: !!player?.canControl, run: () => player.stop() },
            { sep: true },
            { text: "Previous", enabled: !!player?.canGoPrevious, run: () => player.previous() },
            { text: "Next", enabled: !!player?.canGoNext, run: () => player.next() },
            { sep: true },
            { text: "Shuffle", check: player?.shuffle ?? false, enabled: !!player?.shuffleSupported, run: () => player.shuffle = !player.shuffle },
            { text: "Repeat", check: (player?.loopState ?? MprisLoopState.None) !== MprisLoopState.None, enabled: !!player?.loopSupported,
              run: () => player.loopState = player.loopState === MprisLoopState.None ? MprisLoopState.Playlist : MprisLoopState.None },
            { sep: true },
            { text: "Player", sub: players.map(p => ({ text: p.identity || p.dbusName, radio: p === player, run: () => root.chosen = p })) },
        ] },
        { title: "View", items: () => [
            { text: "Volume Control", run: () => Desk.show("volume") },
            { text: "Multimedia Properties", run: () => Desk.show("applet:multimedia", { tab: "Now Playing" }) },
        ] },
    ]
    onMenuRequested: (menu, x, y) => Menus.show(Desk.wins.media?.screen ?? Desk.focusedScreen(), "menubar", menu.items(), x, y, {})

    readonly property var players: Mpris.players.values.filter(p => !p.dbusName.includes("playerctld"))
    property MprisPlayer chosen: null
    readonly property MprisPlayer player: chosen && players.includes(chosen) ? chosen
        : players.find(p => p.isPlaying) ?? players[0] ?? null

    function fmt(s) {
        s = Math.max(0, Math.floor(s));
        return String(Math.floor(s / 60)).padStart(2, "0") + ":" + String(s % 60).padStart(2, "0");
    }
    Timer { running: root.player?.isPlaying ?? false; interval: 1000; repeat: true; onTriggered: root.player.positionChanged() }

    Column {
        anchors.fill: parent
        anchors.margins: 4
        spacing: 4

        // ---------------------------------------------------------------- picture
        Bevel {
            width: parent.width
            height: parent.height - 150
            kind: "sunken"
            fill: "#000000"

            ClippingRectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height) - 40
                height: width
                color: "transparent"
                visible: (root.player?.trackArtUrl ?? "") !== ""
                Image {
                    anchors.fill: parent
                    source: root.player?.trackArtUrl ?? ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }
            }
            Txt {
                anchors.centerIn: parent
                visible: (root.player?.trackArtUrl ?? "") === ""
                text: root.player ? "" : "No media is playing."
                color: "#c0c0c0"
            }
            // the spectrum, in the lcd colour, along the foot of the picture
            Row {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 3
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 2
                opacity: Radio.gain
                Repeater {
                    model: Radio.count
                    Rectangle {
                        required property int index
                        width: 6
                        height: Math.max(1, (Radio.bars[index] ?? 0) * 48)
                        anchors.bottom: parent.bottom
                        color: Theme.lcdText
                    }
                }
            }
        }

        // ---------------------------------------------------------------- seek
        TrackBar {
            width: parent.width
            height: 30
            ticks: 0
            enabled: (root.player?.canSeek ?? false) && (root.player?.length ?? 0) > 0
            value: root.player && root.player.length > 0 ? root.player.position / root.player.length : 0
            onMoved: v => root.player.position = v * root.player.length
        }

        // ---------------------------------------------------------------- transport
        Row {
            spacing: 2
            Btn { width: 40; implicitWidth: 40; padding: 0; glyph: root.player?.isPlaying ? "pause" : "play"; enabled: !!root.player; onClicked: root.player.togglePlaying() }
            Btn { width: 40; implicitWidth: 40; padding: 0; glyph: "stop"; enabled: !!root.player?.canControl; onClicked: root.player.stop() }
            Item { width: 8; height: 1 }
            Btn { width: 40; implicitWidth: 40; padding: 0; glyph: "prev"; enabled: !!root.player?.canGoPrevious; onClicked: root.player.previous() }
            Btn { width: 40; implicitWidth: 40; padding: 0; glyph: "next"; enabled: !!root.player?.canGoNext; onClicked: root.player.next() }
            Item { width: 8; height: 1 }
            Btn {
                width: 40; implicitWidth: 40; padding: 0; glyph: "shuffle"
                enabled: !!root.player?.shuffleSupported
                checked: root.player?.shuffle ?? false
                onClicked: root.player.shuffle = !root.player.shuffle
            }
            Btn {
                width: 40; implicitWidth: 40; padding: 0; glyph: "loop"
                enabled: !!root.player?.loopSupported
                checked: (root.player?.loopState ?? MprisLoopState.None) !== MprisLoopState.None
                onClicked: root.player.loopState = root.player.loopState === MprisLoopState.None ? MprisLoopState.Playlist
                    : root.player.loopState === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None
            }
        }

        // ---------------------------------------------------------------- clip panel
        Bevel {
            width: parent.width
            height: 64
            kind: "sunken"
            fill: "#000000"
            Column {
                x: 8; y: 6
                spacing: 1
                Repeater {
                    model: [["Clip:", root.player?.trackTitle ?? ""], ["Author:", root.player?.trackArtist ?? ""],
                            ["Show:", root.player?.trackAlbum || (root.player?.identity ?? "")]]
                    Row {
                        required property var modelData
                        spacing: 10
                        Txt { width: 64; height: 18; text: modelData[0]; color: "#808080" }
                        Txt { width: root.width - 110; height: 18; text: modelData[1]; color: "#ffffff"; elide: Text.ElideRight }
                    }
                }
            }
        }
    }
}
