import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../theme"
import "../services"

// The messages, top right of the focused screen under the bar, newest on top. Only mapped while
// one is showing.
PanelWindow {
    id: root

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    visible: Notifs.model.count > 0

    anchors { top: true; right: true }
    margins { top: 8; right: 8 }
    implicitWidth: Theme.toastWidth + 40
    implicitHeight: Math.max(1, stack.implicitHeight + 10)
    color: "transparent"
    exclusionMode: ExclusionMode.Normal
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "netrunner-messages"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region { item: stack }

    Column {
        id: stack
        x: 36
        spacing: 2
        move: Transition { NumberAnimation { properties: "y"; duration: Theme.normal; easing.type: Theme.easing } }
        Repeater {
            model: Notifs.model
            Message {}
        }
    }
}
