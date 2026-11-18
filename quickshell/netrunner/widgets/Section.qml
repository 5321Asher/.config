import QtQuick
import "../theme"

// A section of a rig page, drawn as a cyberware item card: a cut-corner card with a red edge, a header
// ("LEVELS // 音量" beside a square badge, optional text at the right end) and its children below.
// Cards arrive one after another as a page opens: each slides in a little after the one above it,
// a scan line running down it.
Item {
    id: root

    property string title: ""
    property string jp: ""
    property string trailing: ""
    property color trailingColor: Theme.dim
    property string glyph: ""                // the badge's icon (default: a diamond)
    default property alias content: body.data

    width: parent ? parent.width : 400
    implicitHeight: body.y + body.implicitHeight + 14
    height: implicitHeight

    // arriving: wait by how far down the page it is, then slide in
    Driver { id: arrive; until: 380 }
    Timer { id: wait; onTriggered: arrive.play() }
    Component.onCompleted: Qt.callLater(() => { wait.interval = 20 + Math.min(320, root.y / 3); wait.start(); })
    readonly property real k: arrive.running ? Theme.out3(Theme.seg(arrive.ms, 0, 300)) : arrive.ms > 0 ? 1 : 0
    opacity: k
    transform: Translate { x: (1 - root.k) * 26 }

    Chamfer { anchors.fill: parent; cut: 10; corners: "tr bl"; fill: Theme.alpha(Theme.bgDark, 0.55); stroke: Theme.alpha(Theme.line, 0.9) }
    Rectangle { x: 0; y: 10; width: 2; height: parent.height - 20; color: Theme.red }
    Rectangle {            // the scan line as it arrives
        visible: arrive.running
        width: parent.width; height: 1
        y: parent.height * Theme.seg(arrive.ms, 60, 380)
        color: Theme.alpha(Theme.cyan, 0.8)
    }

    Item {
        id: head
        x: 14; y: 10
        width: parent.width - 28
        height: 22
        Rectangle {
            id: badge
            anchors.verticalCenter: parent.verticalCenter
            width: 18; height: 18
            color: Theme.alpha(Theme.red, 0.14)
            border.width: 1; border.color: Theme.alpha(Theme.red, 0.7)
            Text {
                anchors.centerIn: parent
                text: root.glyph || "◆"
                color: Theme.red
                font.family: Theme.mono; font.pixelSize: root.glyph ? 12 : 9
            }
        }
        Row {
            x: badge.width + 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.title.toUpperCase()
                color: Theme.bright
                font.family: Theme.condensed; font.pixelSize: 17; font.weight: Font.Bold; font.letterSpacing: 1.2
            }
            Jp { anchors.verticalCenter: parent.verticalCenter; visible: text !== ""; text: root.jp }
        }
        Label { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: root.trailing; color: root.trailingColor }
    }
    Rectangle { x: 14; y: head.y + head.height + 6; width: parent.width - 28; height: 1; color: Theme.alpha(Theme.line, 0.8) }
    Column {
        id: body
        x: 14; y: head.y + head.height + 14
        width: parent.width - 28
        spacing: 8
    }
}
