pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Whether the whole book (the workspace overview) is laid open. qs ipc call overview toggle | open | close
Singleton {
    id: root

    property bool open: false
    function toggle() { open = !open; }

    IpcHandler {
        target: "overview"
        function toggle(): void { root.open = !root.open; }
        function open(): void { root.open = true; }
        function close(): void { root.open = false; }
    }
}
