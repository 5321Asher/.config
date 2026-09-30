//@ pragma IconTheme Papirus-Dark

import QtQuick
import Quickshell
import "bar"
import "spine"
import "frames"
import "menus"
import "arcana"
import "launcher"
import "codex"
import "letters"
import "lock"
import "utilities"
import "services"

// Grimoire: the desktop as a wizard's spellbook on a candlelit desk. Structure and tweaking notes: README.md
ShellRoot {
    // Singletons that only answer IPC are created on first use: use them now
    Component.onCompleted: { ContentsState.toString(); CircleState.open; CodexState.open; TrayMenus.openers; OverviewState.open; Debug.toString(); Updates.count; }

    // the head of the book (bar) and its spine (reagents and the candle), on every screen
    Variants { model: Quickshell.screens; Bar {} }
    Variants { model: Quickshell.screens; Spine {} }

    // gilt flourishes on the focused window's corners: off (Hyprland's gold rule is enough)
    // Variants { model: Quickshell.screens; Frames {} }

    // the codex (control panel): qs ipc call deck open <page>
    Codex {}

    // the summoning circle (app launcher, SUPER + CTRL + Space): qs ipc call circle toggle
    Circle {}

    // letters (notifications), top right
    Letters {}

    // the whole book (overview), the scribe (dictation), a seal is required (polkit)
    Overview {}
    DictationOsd {}
    PolkitPrompt {}

    // the closed book (lock): qs ipc call lock lock (or preview)
    Lock {}

    // the arcana, the root menu (SUPER + Space): qs ipc call contents toggle
    Arcana {}

    // tray menus (parchment slips)
    Variants { model: Quickshell.screens; MenuLayer {} }
}
