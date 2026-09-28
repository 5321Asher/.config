import QtQuick
import Quickshell
import "../theme"

// A 98 tooltip: pale yellow, black 1 px border, shown after the pointer rests on `target` a moment.
// Above the target (the taskbar is at the bottom) unless below: true.
PopupWindow {
    id: root

    required property Item target
    property string text: ""
    property bool hovered: false
    property bool below: false

    visible: shown && text !== ""
    property bool shown: false
    onHoveredChanged: { if (hovered) delay.restart(); else { delay.stop(); shown = false; } }
    Timer { id: delay; interval: Theme.tooltipDelay; onTriggered: root.shown = true }
    Timer { running: root.shown; interval: 8000; onTriggered: root.shown = false }

    anchor.item: target
    anchor.rect.x: Math.round(target.width / 2 - implicitWidth / 2)
    anchor.rect.y: below ? target.height + 4 : -implicitHeight - 4
    implicitWidth: label.implicitWidth + 10
    implicitHeight: label.implicitHeight + 6
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        color: Theme.info
        border.width: 1
        border.color: Theme.dkShadow
        Text {
            id: label
            anchors.centerIn: parent
            text: root.text
            color: Theme.infoText
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            renderType: Text.NativeRendering
        }
    }
}
