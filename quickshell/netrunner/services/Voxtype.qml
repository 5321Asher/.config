pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Voxtype voice dictation (~/.config/voxtype/config.toml, systemd user service "voxtype").
// Follows the daemon's status stream; SUPER+Z (binds.lua) starts and stops it. The overlay while it
// listens is utilities/DictationOsd.qml.
Singleton {
    id: root

    // "idle", "recording", "transcribing", "stopped" (daemon not running) or "" (voxtype not installed)
    property string status: ""
    property string model: ""
    readonly property bool available: status !== ""
    readonly property bool running: available && status !== "stopped"
    readonly property bool recording: status === "recording"
    readonly property bool transcribing: status === "transcribing"
    readonly property bool busy: recording || transcribing

    property date startedAt
    property int elapsed: 0
    readonly property string elapsedText: Math.floor(elapsed / 60) + ":" + String(elapsed % 60).padStart(2, "0")

    function toggle() {
        if (!available)
            return;
        if (!running)
            Quickshell.execDetached(["systemctl", "--user", "start", "voxtype"]);
        else
            Quickshell.execDetached(["voxtype", "record", "toggle"]);
    }

    function cancel() {
        if (busy)
            Quickshell.execDetached(["voxtype", "record", "cancel"]);
    }

    onRecordingChanged: if (recording) {
        startedAt = new Date();
        elapsed = 0;
    }

    Process {
        id: proc
        running: true
        command: ["voxtype", "status", "--follow", "--format", "json", "--extended"]

        stdout: SplitParser {
            onRead: line => {
                let d;
                try {
                    d = JSON.parse(line);
                } catch (e) {
                    return;
                }
                root.status = d.class || d.alt || "idle";
                root.model = d.model ?? "";
            }
        }

        // Not installed, or the stream ended: retry
        onExited: code => {
            if (code === 127)
                root.status = "";
            restart.start();
        }
    }

    Timer {
        id: restart
        interval: 5000
        onTriggered: proc.running = true
    }

    Timer {
        running: root.recording
        repeat: true
        interval: 1000
        onTriggered: root.elapsed = Math.round((Date.now() - root.startedAt.getTime()) / 1000)
    }

    // qs ipc call voxtype toggle | cancel
    IpcHandler {
        target: "voxtype"

        function toggle(): void {
            root.toggle();
        }
        function cancel(): void {
            root.cancel();
        }
    }
}
