import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../theme"
import "../widgets"
import "../utilities"
import "../dash"

// Workspaces: "P1 ▪▪▪" (this screen, and how many windows are on it), then 01 02 03 … with the
// one showing here in a red box. While the deck (special:deck) is open on this screen it reads
// "SPC ▪▪▪ DECK" instead, like the reference. Click to go, scroll to step, right-click for the
// subnet map (overview). The DECK chip toggles the deck. Any other special workspace (the
// scratchpad) open on this screen puts a cyan bracket round the workspace it's over.
Row {
    id: root

    required property HyprlandMonitor monitor
    required property int screenIndex
    readonly property int count: Math.max(5, ...Hyprland.workspaces.values.filter(w => w.id > 0).map(w => w.id))
    readonly property string special: monitor?.lastIpcObject?.specialWorkspace?.name ?? ""
    readonly property bool deckOpen: special === "special:deck"
    readonly property bool scratchOpen: special !== "" && !deckOpen
    readonly property int here: monitor?.activeWorkspace?.id ?? 1
    readonly property int windows: (monitor?.activeWorkspace?.toplevels?.values?.length ?? 0)

    spacing: 0
    height: parent ? parent.height : Theme.barHeight

    function go(id) { Hyprland.dispatch(`hl.dsp.focus({ workspace = ${id} })`); }
    function toggleDeck() { DeckState.toggle(); }
    Timer { id: refresh; interval: 120; onTriggered: Hyprland.refreshMonitors() }
    Connections {
        target: Hyprland
        function onRawEvent(e) { if (e.name === "activespecial" || e.name === "activespecialv2") Hyprland.refreshMonitors(); }
    }

    // screen + window pips
    Item {
        width: pip.width + 20
        height: root.height
        Row {
            id: pip
            anchors.centerIn: parent
            spacing: 6
            Label { anchors.verticalCenter: parent.verticalCenter; text: root.deckOpen ? "SPC" : "P" + (root.screenIndex + 1) }
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Repeater {
                    model: 3
                    Rectangle {
                        required property int index
                        width: 5; height: 5
                        color: index < Math.min(3, root.windows) ? Theme.red : Theme.alpha(Theme.dim, 0.5)
                    }
                }
            }
        }
    }

    // the deck chip, while it's open
    Item {
        visible: root.deckOpen
        width: visible ? 58 : 0
        height: root.height
        Rectangle { anchors.centerIn: parent; width: 44; height: 26; color: Theme.alpha(Theme.red, 0.25); border.width: 1; border.color: Theme.red }
        Label { anchors.centerIn: parent; text: "DECK"; color: Theme.red; strong: true }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleDeck() }
    }

    Repeater {
        model: root.deckOpen ? 0 : root.count
        Item {
            id: ws
            required property int index
            readonly property int wsId: index + 1
            readonly property bool active: root.here === wsId
            readonly property bool busy: (Hyprland.workspaces.values.find(w => w.id === wsId)?.toplevels?.values?.length ?? 0) > 0
            width: 36
            height: root.height

            Rectangle {
                anchors.centerIn: parent
                width: 32; height: 26
                visible: ws.active
                color: Theme.alpha(Theme.red, 0.22)
            }
            Rectangle {
                visible: ws.active
                anchors.bottom: parent.bottom
                width: parent.width; height: 2
                color: Theme.red
            }
            // the scratchpad is open over this workspace: cyan corner brackets + a small tag
            Item {
                id: scratch
                anchors.centerIn: parent
                width: 34; height: 28
                visible: ws.active && root.scratchOpen
                Repeater {
                    model: 4
                    Item {
                        required property int index
                        readonly property bool r: index % 2 === 1
                        readonly property bool b: index >= 2
                        x: r ? scratch.width - 7 : 0
                        y: b ? scratch.height - 7 : 0
                        width: 7; height: 7
                        Rectangle { y: parent.b ? 5 : 0; width: 7; height: 2; color: Theme.cyan }
                        Rectangle { x: parent.r ? 5 : 0; width: 2; height: 7; color: Theme.cyan }
                    }
                }
                Rectangle {
                    anchors { right: parent.right; top: parent.top; rightMargin: -2; topMargin: -2 }
                    width: 5; height: 5
                    color: Theme.cyan
                }
            }
            Text {
                anchors.centerIn: parent
                text: String(ws.wsId).padStart(2, "0")
                color: ws.active ? Theme.red : ws.busy ? Theme.fg : Theme.dim
                font.family: Theme.mono
                font.pixelSize: Theme.data
                font.letterSpacing: 1
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: e => e.button === Qt.RightButton ? OverviewState.toggle() : root.go(ws.wsId)
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
