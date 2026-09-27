pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Open/close state for the workspace overview.
// Toggle from a keybind with: qs ipc call overview toggle
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
