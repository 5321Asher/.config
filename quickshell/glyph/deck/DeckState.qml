pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Whether the deck (the dashboard that rises from the bottom edge) is open. qs ipc call dash toggle
Singleton {
    id: root

    property bool open: false

    IpcHandler {
        target: "dash"
        function toggle(): void { root.open = !root.open; }
        function open(): void { root.open = true; }
        function close(): void { root.open = false; }
    }
}
