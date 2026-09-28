pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../flyouts"

// The corner of the taskbar: minimise every window on this desktop; again, bring them back.
Singleton {
    id: root

    property var hidden: []

    function toggle(monitor) {
        const back = hidden.filter(t => Apps.isMin(t));
        if (back.length) {
            for (const t of back) Apps.restore(t, monitor?.activeWorkspace?.id);
            hidden = [];
            return;
        }
        const ws = monitor?.activeWorkspace?.id ?? Hyprland.focusedWorkspace?.id;
        const wins = Hyprland.toplevels.values.filter(t => t.workspace?.id === ws);
        for (const t of wins) Apps.minimize(t);
        hidden = wins;
    }
}
