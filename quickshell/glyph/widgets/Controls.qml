import QtQuick
import Quickshell.Services.Mpris
import "../theme"

// previous · play (the red circle: the live thing) · next, for a player (default: the active one)
Row {
    id: root

    property var player: Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values[0] ?? null
    property real size: 22
    property real play: 52

    spacing: root.size

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        text: "\u{F04AE}"
        font.pixelSize: root.size
        color: root.player?.canGoPrevious ? Theme.fg : Theme.mute
        TapHandler { onTapped: root.player?.previous() }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
    }
    Rectangle {
        width: root.play
        height: root.play
        radius: root.play / 2
        color: Theme.red
        Icon { anchors.centerIn: parent; text: root.player?.isPlaying ? "\u{F03E4}" : "\u{F040A}"; color: "#FFFFFF"; font.pixelSize: root.play * 0.46 }
        TapHandler { onTapped: root.player?.togglePlaying() }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
    }
    Icon {
        anchors.verticalCenter: parent.verticalCenter
        text: "\u{F04AD}"
        font.pixelSize: root.size
        color: root.player?.canGoNext ? Theme.fg : Theme.mute
        TapHandler { onTapped: root.player?.next() }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
    }
}
