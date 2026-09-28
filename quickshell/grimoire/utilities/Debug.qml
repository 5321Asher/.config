pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Testing aids: render a piece to a PNG without a screenshot (not while the session is locked).
//   qs ipc call debug grab <bar|spine|codex|circle> <file.png>
//   qs ipc call debug candle <hours>     show the candle as if it had burned that long (-1: the real uptime)
//   qs ipc call debug letters <true|false> open every letter as if the pointer rested on it
Singleton {
    id: root
    signal grab(string what, string path)
    property real candleHours: -1
    property bool lettersOpen: false

    IpcHandler {
        target: "debug"
        function grab(what: string, path: string): void { root.grab(what, path); }
        function candle(hours: real): void { root.candleHours = hours; }
        function letters(open: bool): void { root.lettersOpen = open; }
    }
}
