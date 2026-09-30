//@ pragma IconTheme Papirus-Dark

import QtQuick
import Quickshell
import "bar"
import "menus"
import "launcher"
import "rig"
import "utilities"
import "frames"
import "dash"
import "notifications"
import "lock"

// Netrunner: a cyberdeck's desktop, after Night City. Structure and tweaking notes: README.md
ShellRoot {
    // Singletons that only answer IPC are created on first use: use them now
    Component.onCompleted: { HubState.toString(); ExecState.open; RigState.open; TrayMenus.openers; OverviewState.open; Debug.toString(); DeckState.windows; }

    Variants {
        model: Quickshell.screens
        Bar {}
    }

    // window frames: cut corners, red for the focused window
    Variants {
        model: Quickshell.screens
        Frames {}
    }

    // the deck: SYS.DIAG, QUEUE, VULN WATCH, SIGNAL, on special:deck
    Variants {
        model: Quickshell.screens
        Deck {}
    }

    // the rig: qs ipc call deck open <page>
    Rig {}

    // BREACH PROTOCOL, the root menu (SUPER + Space): qs ipc call hub toggle
    Breach {}

    // EXEC, the app launcher (SUPER + CTRL + Space): qs ipc call exec toggle
    Exec {}

    // DATA SHARDS, clipboard history (SUPER + V): qs ipc call clipboard toggle
    Shards {}

    // INPUT REQUIRED, the web-app / keybind scripts' questions: qs ipc call prompt ask <dir>
    Prompt {}

    // messages, top right under the bar
    MessageStack {}

    // subnet map (overview), voice (dictation), root access (polkit)
    Overview {}
    DictationOsd {}
    PolkitPrompt {}

    // the lock: qs ipc call lock lock (or preview)
    Lock {}

    Variants {
        model: Quickshell.screens
        MenuLayer {}
    }
}
