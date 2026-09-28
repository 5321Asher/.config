import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../theme"
import "../services"

// The letters: notifications arrive in the top right corner of the focused screen, under the bar,
// newest on top, and the others shuffle down. Only mapped while one is on the desk.
PanelWindow {
    id: root

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    visible: Notifs.model.count > 0

    anchors { top: true; right: true }
    margins { top: Theme.ribbonDrop - 18; right: 6 }
    implicitWidth: Theme.letterWidth + 60
    implicitHeight: Math.max(1, stack.implicitHeight + 24)
    color: "transparent"
    exclusionMode: ExclusionMode.Normal
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "grimoire-letters"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region { item: stack }

    Column {
        id: stack
        y: 8
        spacing: 4
        move: Transition { NumberAnimation { properties: "y"; duration: Theme.normal; easing.type: Theme.easing } }
        Repeater {
            model: Notifs.model
            Letter {}
        }
    }
}
