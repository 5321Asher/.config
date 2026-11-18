pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Whether the workspace overview (SUBNET MAP) is open, and where its scan starts from: the corner
// that was clicked (utilities/Corner.qml), else the middle of the screen (origin x < 0).
//   qs ipc call overview toggle | open | close | state
Singleton {
    id: root

    property bool open: false
    property point origin: Qt.point(-1, -1)
    property string status: ""
    function toggle() { open = !open; }

    IpcHandler {
        target: "overview"
        function toggle(): void { root.open = !root.open; }
        function open(): void { root.open = true; }
        function close(): void { root.open = false; }
        function state(): string { return root.status; }
    }
}
