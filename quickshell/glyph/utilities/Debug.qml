pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Test aids: qs ipc call debug grab <what> <path> renders a piece to a PNG (pieces answer `grab`).
Singleton {
    id: root
    signal grab(string what, string path)

    IpcHandler {
        target: "debug"
        function grab(what: string, path: string): void { root.grab(what, path); }
    }
}
