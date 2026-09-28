pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Stay awake: while on, hold a systemd idle inhibitor (hypridle respects it), so the screens don't
// dim, lock or sleep. Control Panel's pane and Power Management both switch it.
Singleton {
    property alias on: inhibit.running

    Process {
        id: inhibit
        command: ["systemd-inhibit", "--what=idle", "--who=Memphis", "--why=Stay awake (Power Management)", "sleep", "infinity"]
    }
}
