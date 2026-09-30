//@ pragma IconTheme Win11

import QtQuick
import Quickshell
import "taskbar"
import "flyouts"
import "settings"
import "notifications"
import "osd"
import "lock"
import "utilities"
import "services"
import "desktop"

// Disguise: Windows 11, on Hyprland. Structure and tweaking notes: README.md
ShellRoot {
    // Singletons that answer IPC (or run the notification server) exist only once touched: touch them
    Component.onCompleted: {
        Flyouts.kind; TrayMenus.openers; WinX; SettingsApp.page; TaskView.open; LockState.locked;
        Capture.recording; Voxtype.status; Updates.count; Notifs.dnd; Backlight.value; WinKeys.toString(); AltTabState.active; PromptState.open;
    }

    // The desktop: the Recycle Bin and ~/Desktop's icons, the right-click menu (under the windows)
    Variants {
        model: Quickshell.screens
        Desktop {}
    }

    // Alt + Tab's switcher (utilities/AltTabState: qs ipc call alttab next | prev | commit | cancel)
    Variants {
        model: Quickshell.screens
        AltTab {}
    }

    // The taskbar, and the flyouts that rise from it, per screen
    Variants {
        model: Quickshell.screens
        Taskbar {}
    }
    Variants {
        model: Quickshell.screens
        FlyoutLayer {}
    }

    // Notifications (toasts above the clock), the volume / brightness flyout
    Toasts {}
    Osd {}

    // Task View (qs ipc call overview toggle), voice typing, User Account Control (polkit)
    TaskViewLayer {}
    VoiceTyping {}
    Uac {}

    // Settings (a real window; qs ipc call settings open <page>, deck open <page>)
    SettingsWindow {}

    // The lock screen: qs ipc call lock lock (or preview)
    Lock {}
}
