//@ pragma IconTheme Sharp

import Quickshell
import "modules"

ShellRoot {
    // One bar per monitor
    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData
            screen: modelData
        }
    }

    // Workspace overview (bar button, or: qs ipc call overview toggle)
    Overview {}

    // Notification popups on the focused monitor
    Toast {}

    // Dictation overlay while voxtype records / transcribes
    VoxtypeOsd {}

    // Polkit agent: admin password prompts (pkexec, disk tools, installers)
    PolkitPrompt {}
}
