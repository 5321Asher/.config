pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Whether the star-chart launcher is open. qs ipc call starchart toggle | open | close
Singleton {
    id: root

    property bool open: false

    IpcHandler {
        target: "starchart"

        function toggle(): void { root.open = !root.open; }
        function open(): void { root.open = true; }
        function close(): void { root.open = false; }
    }
}
