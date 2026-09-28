//@ pragma IconTheme Chicago95

import QtQuick
import Quickshell
import "taskbar"
import "menus"
import "start"
import "desk"
import "notifications"
import "lock"
import "utilities"

// Memphis: your dad's computer, around 1998. Structure and tweaking notes: README.md
ShellRoot {
    // Singletons that only answer IPC (Start menu, tray menus) are created on first use: use them now
    Component.onCompleted: { StartMenu.user; TrayMenus.openers; }

    // The taskbar, one per screen
    Variants {
        model: Quickshell.screens
        Taskbar {}
    }

    // The shell's own windows (Control Panel, Properties, Run, Shut Down…), per screen
    Variants {
        model: Quickshell.screens
        DeskLayer {}
    }

    // Notifications: small message windows above the clock
    MessageStack {}

    // Workspace overview (qs ipc call overview toggle), dictation (Sound Recorder), admin passwords
    Overview {}
    DictationOsd {}
    PolkitPrompt {}

    // The lock screen, 98's logon box: qs ipc call lock lock (or preview)
    Lock {}

    // Menus (Start, tray apps, window menus), drawn on the screen they were opened on
    Variants {
        model: Quickshell.screens
        MenuLayer {}
    }
}
