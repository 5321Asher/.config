pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Whether the data shards (clipboard history, SUPER + V) is open.
//   qs ipc call clipboard toggle | open | close
Singleton {
    id: root

    property bool open: false

    IpcHandler {
        target: "clipboard"

        function toggle(): void { root.open = !root.open; }
        function open(): void { root.open = true; }
        function close(): void { root.open = false; }
    }
}
