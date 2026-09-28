import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import "../theme"

// Your account picture: ~/.face if there is one, else Windows' grey silhouette in a circle.
Item {
    id: root
    property int size: 32
    width: size
    height: size
    readonly property string face: Quickshell.env("HOME") + "/.face"
    property bool hasFace: false
    Process { running: true; command: ["test", "-s", root.face]; onExited: code => root.hasFace = code === 0 }

    ClippingRectangle {
        anchors.fill: parent
        radius: root.size / 2
        color: Theme.dark ? "#5a5a5a" : "#d8d8d8"
        Glyph {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: root.size * 0.06
            g: ""
            size: root.size * 0.62
            color: Theme.dark ? "#c8c8c8" : "#8a8a8a"
            visible: pic.status !== Image.Ready
        }
        Image {
            id: pic
            anchors.fill: parent
            source: root.hasFace ? "file://" + root.face : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: root.size * 2
            asynchronous: true
        }
    }
}
