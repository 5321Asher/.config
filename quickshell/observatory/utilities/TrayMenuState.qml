pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray

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

    // qs ipc call tray list | menu <n>   (n = position in the tray, from 0; opens on the first screen)
    IpcHandler {
        target: "tray"
        function list(): string {
            return SystemTray.items.values.map((it, i) => `${i} ${it.id} ${it.hasMenu ? "menu" : "-"}`).join("\n");
        }
        function state(): string {
            return `item=${item?.id} screen=${screen?.name} x=${anchorX} menu=${item?.menu}`;
        }
        function menu(n: int): void {
            const it = SystemTray.items.values[n];
            if (it?.hasMenu) show(it, Quickshell.screens[0], Quickshell.screens[0].width - 200);
        }
    }
}
