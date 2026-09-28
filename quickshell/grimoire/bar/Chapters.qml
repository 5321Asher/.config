import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../theme"
import "../utilities"

// The chapters: this screen's workspaces as Roman numerals in uncials. Chapters with pages (windows)
// in them are in parchment, empty ones faded; the open chapter has the ribbon hanging from it
// (bar/Ribbon.qml, drawn by the bar so it can hang below it; `ribbonX` says where). Click to turn
// to a chapter, scroll to leaf through, right-click for the whole book (the overview).
Row {
    id: root

    required property HyprlandMonitor monitor
    readonly property int count: Math.max(5, ...Hyprland.workspaces.values.filter(w => w.id > 0).map(w => w.id))
    readonly property int here: monitor?.activeWorkspace?.id ?? 1
    readonly property int cell: 46
    // centre of the open chapter, in this row's coordinates
    readonly property real ribbonX: (Math.min(here, count) - 0.5) * cell

    spacing: 0
    height: parent ? parent.height : Theme.barHeight

    // the chapter changed: 1 = forward (the ribbon swings back as it's carried right)
    signal turned(int dir)
    property int prev: 0
    Component.onCompleted: prev = here
    onHereChanged: { if (prev > 0 && here !== prev) turned(here > prev ? 1 : -1); prev = here; }

    function go(id) { Hyprland.dispatch(`hl.dsp.focus({ workspace = ${id} })`); }

    Repeater {
        model: root.count
        Item {
            id: ch
            required property int index
            readonly property int wsId: index + 1
            readonly property bool open: root.here === wsId
            readonly property bool busy: (Hyprland.workspaces.values.find(w => w.id === wsId)?.toplevels?.values?.length ?? 0) > 0
            width: root.cell
            height: root.height

            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: ch.open ? -1 : 1
                text: Theme.roman(ch.wsId)
                color: ch.open ? Theme.goldBright : mouse.containsMouse ? Theme.gold : ch.busy ? Theme.fg : Theme.alpha(Theme.dim, 0.7)
                font.family: Theme.uncial
                font.pixelSize: ch.open ? 19 : 17
                style: ch.open ? Text.Raised : Text.Normal
                styleColor: Theme.alpha("#000000", 0.6)
                Behavior on color { ColorAnimation { duration: Theme.normal } }
                Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: Theme.normal } }
            }
            // a dot of gold under chapters that have pages
            Rectangle {
                visible: ch.busy && !ch.open
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 7
                width: 3; height: 3; radius: 1.5
                color: Theme.alpha(Theme.gold, 0.8)
            }
            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: e => e.button === Qt.RightButton ? OverviewState.toggle() : root.go(ch.wsId)
            }
        }
    }

    WheelHandler {
        onWheel: e => {
            const next = Math.max(1, Math.min(root.count, root.here + (e.angleDelta.y < 0 ? 1 : -1)));
            if (next !== root.here) root.go(next);
        }
    }
}
