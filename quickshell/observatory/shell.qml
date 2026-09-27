//@ pragma IconTheme Adwaita

import QtQuick
import Quickshell
import "bar"
import "notifications"

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
}
