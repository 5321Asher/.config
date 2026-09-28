pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Stay awake: while on, hold a systemd idle inhibitor (hypridle respects it), so the screens don't
// dim, lock or sleep. The Sanctum's "keep vigil" switches it.
Singleton {
    property alias on: inhibit.running

    Process {
        id: inhibit
        command: ["systemd-inhibit", "--what=idle", "--who=Grimoire", "--why=Keep vigil (the Sanctum)", "sleep", "infinity"]
    }
}
