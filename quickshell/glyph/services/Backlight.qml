pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The laptop panel's brightness (/sys/class/backlight), set through logind (SetBrightness on your
// session: no root, no udev rule), read back from sysfs. Monitors on DDC/CI are Brightness.qml.
Singleton {
    id: root

    property string device: ""          // e.g. intel_backlight
    property int max: 0
    property real value: 0              // 0..1
    readonly property bool available: device !== "" && max > 0

    Process {
        running: true
        command: ["sh", "-c", 'for d in /sys/class/backlight/*; do [ -e "$d" ] || continue; echo "$(basename "$d") $(cat "$d/max_brightness") $(cat "$d/brightness")"; break; done']
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(" ");
                if (p.length < 3) return;
                root.device = p[0];
                root.max = parseInt(p[1]) || 0;
                root.value = root.max ? (parseInt(p[2]) || 0) / root.max : 0;
            }
        }
    }
    // keep up with brightness keys and other tools
    FileView {
        path: root.device ? `/sys/class/backlight/${root.device}/actual_brightness` : ""
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: if (!setter.running && root.max) root.value = (parseInt(text()) || 0) / root.max
    }

    property real pending: -1
    function set(v) {
        if (!available) return;
        value = Math.max(0.01, Math.min(1, v));
        pending = value;
        if (!setter.running) flush();
    }
    function flush() {
        if (pending < 0) return;
        const raw = Math.max(1, Math.round(pending * max));
        pending = -1;
        setter.command = ["busctl", "call", "org.freedesktop.login1", "/org/freedesktop/login1/session/auto",
                          "org.freedesktop.login1.Session", "SetBrightness", "ssu", "backlight", device, String(raw)];
        setter.running = true;
    }
    Process { id: setter; onExited: root.flush() }
}
