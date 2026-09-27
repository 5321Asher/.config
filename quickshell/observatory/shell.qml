//@ pragma IconTheme Adwaita

import QtQuick
import Quickshell
import "bar"
import "notifications"
import "launcher"
import "lock"

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
}
