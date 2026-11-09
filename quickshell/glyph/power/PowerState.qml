pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Whether the power screen (LOCK SLEEP SHUT DOWN REBOOT LOG OUT) is open. qs ipc call power toggle
Singleton {
    id: root

    property bool open: false
    function show() { open = true; }

    IpcHandler {
        target: "power"
        function toggle(): void { root.open = !root.open; }
        function open(): void { root.open = true; }
        function close(): void { root.open = false; }
    }
}
