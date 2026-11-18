pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Whether EXEC (the app launcher, SUPER + CTRL + Space) is open. qs ipc call exec toggle | open | close
Singleton {
    id: root

    property bool open: false
    property string status: ""               // the launcher's state, for tests: qs ipc call exec state
    property string report: ""               // which app is in which district: qs ipc call exec districts

    IpcHandler {
        target: "exec"
        function toggle(): void { root.open = !root.open; }
        function open(): void { root.open = true; }
        function close(): void { root.open = false; }
        function state(): string { return root.status; }
        function districts(): string { return root.report; }
    }
}
