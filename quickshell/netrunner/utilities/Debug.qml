pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../rig"

// Testing aids: render a component to a PNG without a screenshot (works while the screen is
// locked or the monitors are off).   qs ipc call debug grab <bar|rig|deck|…> <file.png>
Singleton {
    id: root
    signal grab(string what, string path)

    IpcHandler {
        target: "debug"
        function grab(what: string, path: string): void { root.grab(what, path); }
        function rig(): string { return `open=${RigState.open} page=${RigState.page}`; }
    }
}
