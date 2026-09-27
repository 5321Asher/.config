import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris

// Now playing: art, track info, seek bar and controls
Item {
    id: root

    // playerctld mirrors other players; hide it
    readonly property var players: Mpris.players.values.filter(p => !p.dbusName.includes("playerctld"))
    property MprisPlayer chosen: null
    readonly property MprisPlayer player: chosen && players.includes(chosen) ? chosen
        : players.find(p => p.isPlaying) ?? players[0] ?? null

    function fmt(secs) {
        const s = Math.max(0, Math.floor(secs));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    width: 360
    height: player ? content.height : empty.height

    // Position only updates when asked
    Timer {
        running: root.player?.isPlaying ?? false
        interval: 500
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    // Nothing playing
    Column {
        id: empty
        visible: !root.player
        width: parent.width
        topPadding: 16
        bottomPadding: 16
        spacing: 10

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: ""
            font.family: Theme.font
            font.pixelSize: 32
            color: Theme.border
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Nothing playing"
            font.family: Theme.font
            font.pixelSize: 14
            color: Theme.dim
        }
    }

    Column {
        id: content
        visible: !!root.player
        width: parent.width
        spacing: 18

        // Player switcher, only when there's a choice
        Row {
            visible: root.players.length > 1
            spacing: 6

            Repeater {
                model: root.players

                Rectangle {
                    required property MprisPlayer modelData
                    readonly property bool current: modelData === root.player

                    width: chipText.implicitWidth + 20
                    height: 24
                    radius: 0
                    color: current || chipMouse.containsMouse ? Theme.surface : "transparent"
                    border.width: 1
                    border.color: current ? Theme.accent : Theme.border

                    Text {
                        id: chipText
                        anchors.centerIn: parent
                        text: parent.modelData.identity
                        font.family: Theme.font
                        font.pixelSize: 11
                        font.bold: parent.current
                        color: parent.current ? Theme.accent : Theme.dim
                    }

                    MouseArea {
                        id: chipMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.chosen = parent.modelData
                    }
                }
            }
        }

        // Art + track info
        Row {
            spacing: 16

            ClippingRectangle {
                width: 104
                height: 104
                radius: 0
                color: Theme.surface

                Text {
                    anchors.centerIn: parent
                    visible: art.status !== Image.Ready
                    text: ""
                    font.family: Theme.font
                    font.pixelSize: 30
                    color: Theme.border
                }

                Image {
                    id: art
                    anchors.fill: parent
                    source: root.player?.trackArtUrl ?? ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 208
                    sourceSize.height: 208
                    opacity: status === Image.Ready ? 1 : 0

                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: root.width - 104 - 16
                spacing: 4

                Text {
                    width: parent.width
                    text: (root.player?.identity ?? "").toUpperCase()
                    elide: Text.ElideRight
                    font.family: Theme.font
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 2
                    color: Theme.accent
                    bottomPadding: 4
                }

                Text {
                    width: parent.width
                    text: root.player?.trackTitle || "Unknown title"
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    font.family: Theme.font
                    font.pixelSize: 17
                    font.bold: true
                    color: Theme.fg
                }

                Text {
                    width: parent.width
                    visible: text !== ""
                    text: root.player?.trackArtist ?? ""
                    elide: Text.ElideRight
                    font.family: Theme.font
                    font.pixelSize: 13
                    color: Theme.dim
                }

                Text {
                    width: parent.width
                    visible: text !== ""
                    text: root.player?.trackAlbum ?? ""
                    elide: Text.ElideRight
                    font.family: Theme.font
                    font.pixelSize: 12
                    color: Theme.border
                }
            }
        }

        // Seek bar
        Column {
            width: parent.width
            spacing: 6
            visible: root.player?.lengthSupported ?? false

            Item {
                id: seek

                readonly property real ratio: root.player && root.player.length > 0
                    ? Math.min(1, root.player.position / root.player.length) : 0

                width: parent.width
                height: 14

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: seekMouse.containsMouse ? 6 : 4
                    radius: 0
                    color: Theme.surface

                    Behavior on height { NumberAnimation { duration: 120 } }

                    Rectangle {
                        width: parent.width * seek.ratio
                        height: parent.height
                        radius: 0
                        color: Theme.accent
                    }
                }

                Rectangle {
                    x: parent.width * seek.ratio - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: 12
                    height: 12
                    radius: 0
                    color: Theme.fg
                    scale: seekMouse.containsMouse ? 1 : 0

                    Behavior on scale { NumberAnimation { duration: 120 } }
                }

                MouseArea {
                    id: seekMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: root.player?.canSeek ?? false
                    cursorShape: Qt.PointingHandCursor
                    function seekTo(x) {
                        root.player.position = Math.max(0, Math.min(1, x / width)) * root.player.length;
                    }
                    onPressed: mouse => seekTo(mouse.x)
                    onPositionChanged: mouse => { if (pressed) seekTo(mouse.x); }
                }
            }

            Item {
                width: parent.width
                height: posText.height

                Text {
                    id: posText
                    text: root.fmt(root.player?.position ?? 0)
                    font.family: Theme.font
                    font.pixelSize: 11
                    color: Theme.dim
                }

                Text {
                    anchors.right: parent.right
                    text: root.fmt(root.player?.length ?? 0)
                    font.family: Theme.font
                    font.pixelSize: 11
                    color: Theme.dim
                }
            }
        }

        // Controls
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 18

            ControlButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: ""
                enabled: root.player?.canGoPrevious ?? false
                onClicked: root.player.previous()
            }

            ControlButton {
                anchors.verticalCenter: parent.verticalCenter
                primary: true
                icon: root.player?.isPlaying ? "" : ""
                enabled: root.player?.canTogglePlaying ?? false
                onClicked: root.player.togglePlaying()
            }

            ControlButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: ""
                enabled: root.player?.canGoNext ?? false
                onClicked: root.player.next()
            }
        }
    }

    component ControlButton: Rectangle {
        id: btn

        property string icon
        property bool primary: false
        signal clicked

        width: primary ? 52 : 40
        height: width
        radius: 0
        opacity: enabled ? 1 : 0.35
        color: primary || btnMouse.containsMouse ? Theme.surface : "transparent"
        border.width: primary ? 1 : 0
        border.color: Theme.accent
        scale: btnMouse.pressed ? 0.92 : 1

        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on scale { NumberAnimation { duration: 100 } }

        Text {
            anchors.centerIn: parent
            // Play glyph looks off-center without a nudge
            anchors.horizontalCenterOffset: btn.primary && btn.icon === "" ? 2 : 0
            text: btn.icon
            font.family: Theme.font
            font.pixelSize: btn.primary ? 18 : 14
            color: btn.primary ? Theme.accent : Theme.fg
        }

        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }
}
