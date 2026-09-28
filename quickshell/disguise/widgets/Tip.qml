import QtQuick
import Quickshell
import "../theme"

// A tooltip: a small rounded flyout above `target` (below: true for under it), after a moment's
// hover. A popup window of its own, so it can leave the taskbar.
PopupWindow {
    id: root

    required property Item target
    property string text: ""
    property bool hovered: false
    property bool below: false

    visible: shown && text !== ""
    property bool shown: false
    onHoveredChanged: { if (hovered) delay.restart(); else { delay.stop(); shown = false; } }
    Timer { id: delay; interval: 700; onTriggered: root.shown = true }
    Timer { running: root.shown; interval: 6000; onTriggered: root.shown = false }

    anchor.item: target
    anchor.rect.x: Math.round(target.width / 2 - implicitWidth / 2)
    anchor.rect.y: below ? target.height + 6 : -implicitHeight - 6
    implicitWidth: Math.min(360, label.implicitWidth + 18)
    implicitHeight: label.implicitHeight + 12
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.flyout
        border.width: 1
        border.color: Theme.flyoutStroke
        Txt {
            id: label
            anchors.centerIn: parent
            width: Math.min(implicitWidth, 342)
            text: root.text
            size: Theme.caption
            wrapMode: Text.Wrap
            elide: Text.ElideNone
        }
    }
}
