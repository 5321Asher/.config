pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Whether the console (Observatory's root menu) is open. qs ipc call console toggle | open | close
Singleton {
    id: root

    property bool open: false

    IpcHandler {
        target: "console"

        function toggle(): void { root.open = !root.open; }
        function open(): void { root.open = true; }
        function close(): void { root.open = false; }
    }
}
