//@ pragma IconTheme Papirus-Dark

import QtQuick
import Quickshell
import "theme"
import "services"
import "rail"
import "home"
import "edges"
import "launcher"
import "quick"
import "power"
import "prefs"
import "deck"
import "menus"
import "utilities"
import "lock"

// Glyph: after Nothing OS (and Shykid002's Nothing-rice). Black, white dots, one red.
// Structure and tweaking notes: README.md
ShellRoot {
    // Singletons that only answer IPC are created on first use: use them now
    Component.onCompleted: {
        IndexState.open; ExecState.open; ClipboardState.open; PromptState.open; QuickState.open;
        PowerState.open; PrefsState.open; DeckState.open; OverviewState.open; TrayMenus.openers; Debug.toString();
        Capture.recording; Voxtype.status; Status.vulnCount; Notifs.dnd;
    }

    // the system stats run while something shows them
    Binding {
        target: SysStats
        property: "active"
        value: HomeState.any || DeckState.open || (PrefsState.open && PrefsState.page === "telemetry")
    }

    Variants {
        model: Quickshell.screens
        Home {}
    }
    Variants {
        model: Quickshell.screens
        Rail {}
    }

    // volume / brightness / progress at the edges, notifications in the island
    Edges {}

    // the index, the root menu (SUPER + Space): qs ipc call index toggle
    Index {}
    // apps (SUPER + CTRL + Space): qs ipc call exec toggle
    Launcher {}
    // clipboard (SUPER + V): qs ipc call clipboard toggle
    Clip {}
    // the scripts' questions: qs ipc call prompt ask <dir>
    Prompt {}

    // quick settings: qs ipc call quick toggle (and deck open helm)
    Quick {}
    // settings: qs ipc call deck open <page>
    Prefs {}
    // the dashboard from the bottom: qs ipc call dash toggle
    Deck {}
    // power: qs ipc call power toggle
    Power {}

    // overview, dictation, admin prompts
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
