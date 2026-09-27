import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../theme"
import "../services"

// 6 · Transmissions: the stack of notification cards, top right of the focused monitor, below the
// horizon. Newest on top. The window is only mapped while something is on screen.
PanelWindow {
    id: root

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    visible: Transmissions.model.count > 0

    anchors {
        top: true
        right: true
    }
    margins {
        top: Theme.transmissionTop
        right: Theme.transmissionRight
    }
    implicitWidth: Theme.transmissionWidth + 48      // room for the shadow and the slide
    implicitHeight: Math.max(1, stack.implicitHeight + 24)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "observatory-transmissions"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Only the cards take clicks
    mask: Region { item: stack }

    Column {
        id: stack
        x: 24
        y: 4
        spacing: Theme.transmissionGap

        move: Transition {
            NumberAnimation { properties: "y"; duration: Theme.normal; easing.type: Theme.easing }
        }

        Repeater {
            model: Transmissions.model
            Transmission {}
        }
    }
}
