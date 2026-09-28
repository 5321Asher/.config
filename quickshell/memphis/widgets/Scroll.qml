import QtQuick
import "../theme"

// 98's vertical scroll bar for a Flickable: arrow buttons at each end, a dithered track, a raised
// thumb sized to the view. Clicking the track pages; holding an arrow repeats.
Item {
    id: root

    required property Flickable flick
    readonly property bool needed: flick.contentHeight > flick.height + 1
    readonly property real maxY: Math.max(0, flick.contentHeight - flick.height)

    width: Theme.scrollbar
    visible: needed

    function scrollBy(d) { flick.contentY = Math.max(0, Math.min(maxY, flick.contentY + d)); }

    Btn {
        id: upBtn
        width: parent.width; height: Theme.scrollbar
        implicitWidth: Theme.scrollbar
        glyph: "up"; padding: 0
        activeFocusOnTab: false
        onClicked: root.scrollBy(-24)
        Timer { running: upBtn.down; interval: 60; repeat: true; triggeredOnStart: false; onTriggered: root.scrollBy(-24) }
    }
    Item {
        id: track
        y: Theme.scrollbar
        width: parent.width
        height: parent.height - Theme.scrollbar * 2
        Dither { anchors.fill: parent }
        MouseArea {
            anchors.fill: parent
            onPressed: e => root.scrollBy(e.y < thumb.y ? -root.flick.height : root.flick.height)
        }
        Bevel {
            id: thumb
            kind: "button"
            fill: Theme.face
            width: parent.width
            height: Math.max(Theme.scrollbar, track.height * Math.min(1, root.flick.height / Math.max(1, root.flick.contentHeight)))
            y: root.maxY > 0 ? (track.height - height) * root.flick.contentY / root.maxY : 0
            MouseArea {
                anchors.fill: parent
                property real grab: 0
                onPressed: e => grab = e.y
                onPositionChanged: e => {
                    if (!pressed) return;
                    const room = track.height - thumb.height;
                    if (room <= 0) return;
                    const ny = Math.max(0, Math.min(room, thumb.y + e.y - grab));
                    root.flick.contentY = ny / room * root.maxY;
                }
            }
        }
    }
    Btn {
        id: downBtn
        y: parent.height - Theme.scrollbar
        width: parent.width; height: Theme.scrollbar
        implicitWidth: Theme.scrollbar
        glyph: "down"; padding: 0
        activeFocusOnTab: false
        onClicked: root.scrollBy(24)
        Timer { running: downBtn.down; interval: 60; repeat: true; onTriggered: root.scrollBy(24) }
    }
}
