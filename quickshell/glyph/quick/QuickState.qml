pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Whether the quick settings panel (right edge) is open. qs ipc call quick toggle | open | close
Singleton {
    id: root

    property bool open: false
    // "" | "wifi" | "bt": the list opened under the Wi-Fi / Bluetooth pills
    property string pick: ""
    onOpenChanged: if (!open) pick = ""

    IpcHandler {
        target: "quick"
        function toggle(): void { root.open = !root.open; }
        function open(): void { root.open = true; }
        function close(): void { root.open = false; }
    }
}
