import QtQuick
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../widgets"
import ".."

// Background: the pictures for this theme as a grid of thumbnails (click one to set it), Random,
// and Browse for any picture.
Column {
    id: root
    spacing: 4
    Component.onCompleted: Look.refresh()

    SettingRow {
        width: parent.width
        glyph: ""; title: "Personalize your background"; subtitle: Look.wallNow ? Look.base(Look.wallNow) : ""
        Row {
            spacing: 8
            Btn { text: "Random"; glyph: ""; onClicked: Look.randomWall() }
            Btn { text: "Browse photos"; onClicked: browse.running = true }
            Btn { text: "Wallpaper picker"; onClicked: Quickshell.execDetached(["gtk-launch", "skwd-wall-v2"]) }
        }
    }
    Card {
        width: parent.width
        height: grid.height + 32
        Flow {
            id: grid
            x: 16; y: 16
            width: parent.width - 32
            spacing: 10
            Repeater {
                model: Look.walls
                Rectangle {
                    id: wallTile
                    required property string modelData
                    width: 176; height: 100; radius: Theme.radius
                    color: Theme.subtle
                    border.width: modelData === Look.wallNow ? 3 : wm.containsMouse ? 1 : 0
                    border.color: modelData === Look.wallNow ? Theme.accent : Theme.strong
                    clip: true
                    Image {
                        anchors.fill: parent; anchors.margins: 3
                        visible: !Look.isVideo(parent.modelData)
                        source: visible ? "file://" + parent.modelData : ""
                        fillMode: Image.PreserveAspectCrop; sourceSize.width: 352; asynchronous: true
                    }
                    Glyph { anchors.centerIn: parent; visible: Look.isVideo(parent.modelData); g: ""; size: 28 }
                    MouseArea { id: wm; anchors.fill: parent; hoverEnabled: true; onClicked: Look.setWall(parent.modelData) }
                    Tip { target: wallTile; hovered: wm.containsMouse; text: Look.base(wallTile.modelData) }
                }
            }
        }
    }
    Process {
        id: browse
        command: ["zenity", "--file-selection", "--title=Choose a picture", "--file-filter=Pictures | *.png *.jpg *.jpeg *.webp *.gif *.mp4"]
        stdout: StdioCollector { onStreamFinished: { const p = text.trim(); if (p) Look.setWall(p); } }
    }
}
