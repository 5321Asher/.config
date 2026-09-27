pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Whether the horizon bar is pinned open (every monitor). qs ipc call horizon toggle | pin | unpin
Singleton {
    id: root

    property bool pinned: false

    IpcHandler {
        target: "horizon"

        function toggle(): void { root.pinned = !root.pinned; }
        function pin(): void { root.pinned = true; }
        function unpin(): void { root.pinned = false; }
    }
}
