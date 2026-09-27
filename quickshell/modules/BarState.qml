pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Bar auto-hide state shared by every monitor's bar
Singleton {
    id: root

    // Keep the bar open instead of hiding it
    property bool pinned: false

    // qs ipc call bar toggle
    IpcHandler {
        target: "bar"
        function toggle(): void { root.pinned = !root.pinned; }
    }
}
