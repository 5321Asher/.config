pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../flyouts"

// Windows' taskbar and window keys, for the Hyprland binds in setups/disguise/files/hypr/setup-binds.lua:
//   qs ipc call taskbar activate <n>   Win + 1…9: the taskbar's n-th app (launch it, focus it, or cycle
//                                      its windows), exactly like clicking its button
//   qs ipc call taskbar minimize       Win + Down: minimise the active window
//   qs ipc call taskbar minimizeWindow <address>   a title bar's minimise button
//   qs ipc call desktop toggle         Win + D: show the desktop (again: bring the windows back)
//   qs ipc call desktop minimizeAll    Win + M: minimise every window on this desktop
Singleton {
    id: root

    // TaskButtons on the focused screen answer this
    signal activate(int n, string screenName)

    function focusedScreen() { return Hyprland.focusedMonitor?.name ?? ""; }

    // Maximised the Windows way (scripts/caption.sh): when an app asks Hyprland to maximise itself (or
    // opens maximised), make it a Windows-maximised window instead, so several can stay maximised at once
    Connections {
        target: Hyprland
        function onRawEvent(event) { if (event.name === "fullscreen" && event.data === "1") adopt.restart(); }
    }
    Timer { id: adopt; interval: 30; onTriggered: Quickshell.execDetached([Quickshell.shellDir + "/scripts/caption.sh", "adopt"]) }
    Component.onCompleted: adopt.restart()

    IpcHandler {
        target: "taskbar"
        function activate(n: int): void { root.activate(n, root.focusedScreen()); }
        function minimize(): void { if (Hyprland.activeToplevel) Apps.minimize(Hyprland.activeToplevel); }
        // a title bar's minimise button (scripts/caption.sh): the window whose bar was clicked
        function minimizeWindow(address: string): void {
            const a = address.replace(/^0x/, "");
            const t = Hyprland.toplevels.values.find(w => w.address.replace(/^0x/, "") === a);
            if (t) Apps.minimize(t);
        }
    }
    IpcHandler {
        target: "desktop"
        function toggle(): void { ShowDesktop.toggle(Hyprland.focusedMonitor); }
        function minimizeAll(): void {
            const ws = Hyprland.focusedWorkspace?.id;
            for (const t of Hyprland.toplevels.values.filter(t => t.workspace?.id === ws)) Apps.minimize(t);
        }
    }
}
