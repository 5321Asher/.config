pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Whether the summoning circle (the app launcher, SUPER + CTRL + Space) is open.
//   qs ipc call circle toggle | open | close
//   qs ipc call circle type <words> | cast      (testing: write into it without the keyboard, cast)
Singleton {
    id: root

    property bool open: false
    signal typed(string text)
    signal castRequested()

    IpcHandler {
        target: "circle"
        function toggle(): void { root.open = !root.open; }
        function open(): void { root.open = true; }
        function close(): void { root.open = false; }
        function type(text: string): void { root.open = true; root.typed(text); }
        function cast(): void { root.castRequested(); }
    }
}
