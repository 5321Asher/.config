pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Open/close state for the workspace overview.
// qs ipc call overview toggle | open | close, or click the star in the middle of the orbit
Singleton {
    id: root

    property bool open: false

    function toggle() {
        open = !open;
    }

    IpcHandler {
        target: "overview"

        function toggle(): void {
            root.toggle();
        }
        function open(): void {
            root.open = true;
        }
        function close(): void {
            root.open = false;
        }
    }
}
