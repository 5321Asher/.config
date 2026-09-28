pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Whether EXEC (the app launcher, SUPER + CTRL + Space) is open. qs ipc call exec toggle | open | close
Singleton {
    id: root

    property bool open: false

    IpcHandler {
        target: "exec"
        function toggle(): void { root.open = !root.open; }
        function open(): void { root.open = true; }
        function close(): void { root.open = false; }
    }
}
