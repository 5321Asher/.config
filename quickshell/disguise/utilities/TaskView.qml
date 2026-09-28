pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Task View's state (Windows + Tab: the windows of a desktop, and the desktops along the bottom).
//   qs ipc call overview toggle | open | close
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
