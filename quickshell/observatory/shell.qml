//@ pragma IconTheme Observatory

import QtQuick
import Quickshell
import "bar"
import "notifications"
import "launcher"
import "lock"
import "utilities"
import "deck"

// Observatory: the control panel of a deep-space observatory.
// Structure and theming notes: README.md
ShellRoot {
    // 1 · Horizon bar (with 2-4 inside it), one per monitor
    Variants {
        model: Quickshell.screens

        HorizonBar {}
    }

    // 6 · Transmissions (notifications), on the focused monitor
    TransmissionStack {}

    // 7 · Star-chart launcher (SUPER + CTRL + Space): qs ipc call starchart toggle
    StarChart {}

    // The console, Observatory's root menu (SUPER + Space): qs ipc call console toggle
    Console {}

    // 8 · Lock screen: qs ipc call lock lock (or preview)
    Lock {}

    // Utilities carried over from Sharp, in Observatory's style:
    // survey (workspace overview: the orbit's star, or qs ipc call overview toggle),
    // dictation overlay (voxtype, SUPER + Z). Capture (screenshots, OCR, recording:
    // qs ipc call capture …) is services/Capture.qml, its recording beacon bar/Beacons.qml.
    Overview {}
    DictationOsd {}

    // Polkit agent: admin password prompts for pkexec, disk tools, installers…
    PolkitPrompt {}

    // The control deck: qs ipc call deck open <page>
    Deck {}

    // Tray app menus (the tray itself is on the horizon)
    TrayMenu {}
}
