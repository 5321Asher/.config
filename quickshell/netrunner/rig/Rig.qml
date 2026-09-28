import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../theme"
import "../widgets"
import "pages"

// The rig: a cut-corner panel sliding in from the right of the focused screen, under the bar. A
// rail of numbered pages down its left (01 HELM 操縦 …), the page on the right with its header
// decoding itself as it arrives. Esc or a click outside closes it. qs ipc call deck open <page>
PanelWindow {
    id: root

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    visible: RigState.open || shown > 0.01

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Normal
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "netrunner-rig"
    WlrLayershell.keyboardFocus: RigState.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    mask: RigState.open ? null : noInput
    Region { id: noInput }

    property real shown: RigState.open ? 1 : 0
    Behavior on shown { NumberAnimation { duration: Theme.slow; easing.type: Theme.easing } }
    onVisibleChanged: if (visible) keys.forceActiveFocus()

    FocusScope {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: RigState.open = false
        Keys.onPressed: e => {
            const i = RigState.pages.findIndex(p => p.id === RigState.page);
            if (e.key === Qt.Key_Tab || e.key === Qt.Key_PageDown) { RigState.page = RigState.pages[(i + 1) % RigState.pages.length].id; e.accepted = true; }
            else if (e.key === Qt.Key_Backtab || e.key === Qt.Key_PageUp) { RigState.page = RigState.pages[(i - 1 + RigState.pages.length) % RigState.pages.length].id; e.accepted = true; }
        }

        MouseArea { anchors.fill: parent; onClicked: RigState.open = false }

        Item {
            id: plate
            width: Theme.rigWidth
            height: parent.height - Theme.gap * 2
            x: parent.width - width - Theme.gap + (1 - root.shown) * (width * 0.25)
            y: Theme.gap
            opacity: root.shown

            MouseArea { anchors.fill: parent }       // clicks on the plate stay here

            Chamfer {
                anchors.fill: parent
                cut: 18
                corners: "tl br"
                fill: Theme.alpha(Theme.bgDark, 0.93)
                stroke: Theme.alpha(Theme.red, 0.55)
            }
            Hazard { x: 30; y: 0; width: 80; height: 5 }

            // ---------------------------------------------------------------- the rail
            Column {
                id: rail
                x: 10
                y: 26
                width: 96
                spacing: 2
                Repeater {
                    model: RigState.pages
                    Item {
                        id: tab
                        required property var modelData
                        readonly property bool on: RigState.page === modelData.id
                        width: rail.width
                        height: 42
                        Rectangle {
                            anchors.fill: parent
                            color: tab.on ? Theme.alpha(Theme.red, 0.18) : tabMouse.containsMouse ? Theme.alpha(Theme.fg, 0.05) : "transparent"
                            Rectangle { visible: tab.on; width: 2; height: parent.height; color: Theme.red }
                        }
                        Column {
                            x: 10
                            anchors.verticalCenter: parent.verticalCenter
                            Row {
                                spacing: 6
                                Text { text: tab.modelData.code; color: tab.on ? Theme.red : Theme.dim; font.family: Theme.display; font.pixelSize: 13; font.weight: Font.Bold }
                                Label { text: tab.modelData.title; strong: tab.on; color: tab.on ? Theme.bright : Theme.fg; font.pixelSize: Theme.label - 1 }
                            }
                            Jp { text: tab.modelData.jp; font.pixelSize: 10; color: tab.on ? Theme.cyan : Theme.alpha(Theme.cyan, 0.5) }
                        }
                        MouseArea { id: tabMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: RigState.page = tab.modelData.id }
                    }
                }
            }
            Rectangle { x: rail.x + rail.width + 8; y: 24; width: 1; height: parent.height - 48; color: Theme.line }

            // ---------------------------------------------------------------- the page
            Item {
                id: page
                x: rail.x + rail.width + 24
                y: 20
                width: plate.width - x - 22
                height: plate.height - y - 20

                Row {
                    id: head
                    spacing: 10
                    Tag { anchors.verticalCenter: parent.verticalCenter; text: RigState.current.code; height: 22; pixelSize: 12 }
                    Scramble {
                        anchors.verticalCenter: parent.verticalCenter
                        target: RigState.current.title.toUpperCase()
                        color: Theme.bright
                        font.family: Theme.display
                        font.pixelSize: Theme.title
                        font.weight: Font.Bold
                    }
                    Jp { anchors.verticalCenter: parent.verticalCenter; text: RigState.current.jp; font.pixelSize: 14 }
                }
                Label { id: sub; y: head.height + 4; text: RigState.current.sub }

                Flickable {
                    id: flick
                    y: sub.y + sub.height + 16
                    width: parent.width
                    height: parent.height - y
                    clip: true
                    contentHeight: loader.item ? loader.item.implicitHeight + 16 : 0
                    boundsBehavior: Flickable.StopAtBounds

                    Loader {
                        id: loader
                        width: flick.width
                        active: root.visible
                        sourceComponent: root.components[RigState.page] ?? null
                        onLoaded: flick.contentY = 0
                    }
                }
                // scroll position: a red tick on the right edge
                Rectangle {
                    visible: flick.contentHeight > flick.height
                    x: parent.width + 8
                    y: flick.y + flick.visibleArea.yPosition * flick.height
                    width: 2
                    height: Math.max(20, flick.visibleArea.heightRatio * flick.height)
                    color: Theme.red
                }
            }
        }
    }

    // pages as types (so live reload sees them)
    readonly property var components: ({
        helm: helm, comms: comms, radio: radio, log: log, almanac: almanac, telemetry: telemetry,
        hangar: hangar, optics: optics, lamps: lamps, chronometer: chrono, claude: claude,
    })
    Component { id: helm; Helm {} }
    Component { id: comms; Comms {} }
    Component { id: radio; Airwaves {} }
    Component { id: log; Log {} }
    Component { id: almanac; Almanac {} }
    Component { id: telemetry; Telemetry {} }
    Component { id: hangar; Hangar {} }
    Component { id: optics; Optics {} }
    Component { id: lamps; Lamps {} }
    Component { id: chrono; Chrono {} }
    Component { id: claude; Claude {} }
}
