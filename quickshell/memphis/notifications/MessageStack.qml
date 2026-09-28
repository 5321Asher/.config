import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../theme"
import "../services"

// The notification windows, stacked up from the notification area (bottom right of the focused
// screen, above the taskbar), newest at the bottom. Only mapped while one is showing.
PanelWindow {
    id: root

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    visible: Notifs.model.count > 0

    anchors { bottom: true; right: true }
    margins { bottom: 4; right: 4 }
    implicitWidth: Theme.toastWidth + 8
    implicitHeight: Math.max(1, stack.implicitHeight + 24)
    color: "transparent"
    exclusionMode: ExclusionMode.Normal
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "memphis-messages"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region { item: stack }

    // Notifs.model is newest first: laid out bottom-up, so the newest sits by the clock
    ListView {
        id: stack
        x: 4
        y: parent.height - height
        width: Theme.toastWidth
        height: contentHeight
        implicitHeight: contentHeight
        interactive: false
        verticalLayoutDirection: ListView.BottomToTop
        spacing: Theme.toastGap
        model: Notifs.model
        delegate: Message {}
    }
}
