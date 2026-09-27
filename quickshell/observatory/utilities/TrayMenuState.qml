pragma Singleton

import QtQuick
import Quickshell

// Which tray app's menu is open, on which screen, and where (x of the icon's centre on that screen).
Singleton {
    property var item: null
    property var screen: null
    property real anchorX: 0

    function show(it, scr, x) {
        if (item === it) { item = null; return; }
        screen = scr;
        anchorX = x;
        item = it;
    }
    function close() { item = null; }
}
