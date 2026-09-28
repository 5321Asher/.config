import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import "../theme"
import "../widgets"

// 98's little volume pop-up from the speaker in the notification area: "Volume", a vertical
// slider and a Mute check box. A click anywhere else closes it.
PopupWindow {
    id: root

    required property Item target
    property PwNode sink

    visible: false
    anchor.item: target
    anchor.rect.x: Math.round(target.width / 2 - implicitWidth / 2)
    anchor.rect.y: -implicitHeight - 6
    implicitWidth: 96
    implicitHeight: 210
    color: "transparent"

    HyprlandFocusGrab {
        windows: [root]
        active: root.visible
        onCleared: root.visible = false
    }

    Bevel {
        anchors.fill: parent
        kind: "raised"
        fill: Theme.face

        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 8
            text: "Volume"
        }
        TrackBar {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 34
            width: 40
            height: 124
            vertical: true
            ticks: 6
            value: root.sink?.audio?.volume ?? 0
            onMoved: v => { if (root.sink?.audio) root.sink.audio.volume = v; }
        }
        Check {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height - height - 10
            text: "Mute"
            checked: root.sink?.audio?.muted ?? false
            onToggled: if (root.sink?.audio) root.sink.audio.muted = !root.sink.audio.muted
        }
    }
}
