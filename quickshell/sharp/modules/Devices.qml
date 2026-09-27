pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Drives and fans from scripts/devices.py, plus mount / unmount / eject via udisksctl
Singleton {
    id: root

    property var drives: []
    property var fans: []
    property bool udisks: false
    property bool liquidctl: false
    property string board: ""
    // Device path currently being mounted/unmounted
    property string busy: ""
    property string error: ""
    // Poll while something is showing the data
    property bool active: false

    function refresh() {
        if (!reader.running)
            reader.running = true;
    }

    function mount(drive) {
        run(drive.path, ["udisksctl", "mount", "--no-user-interaction", "-b", drive.path]);
    }

    function unmount(drive) {
        run(drive.path, ["udisksctl", "unmount", "--no-user-interaction", "-b", drive.path]);
    }

    // Unmount, then power the whole disk down so it's safe to pull
    function eject(drive) {
        run(drive.path, ["sh", "-c", 'udisksctl unmount --no-user-interaction -b "$1" && udisksctl power-off --no-user-interaction -b "$2"', "sh", drive.path, drive.disk]);
    }

    function run(path, cmd) {
        busy = path;
        error = "";
        action.command = cmd;
        action.running = true;
    }

    Process {
        id: reader
        command: ["python3", Quickshell.shellDir + "/scripts/devices.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    root.drives = d.drives;
                    root.fans = d.fans;
                    root.udisks = d.udisks;
                    root.liquidctl = d.liquidctl;
                    root.board = d.board.trim();
                } catch (e) {}
            }
        }
    }

    Process {
        id: action
        stderr: StdioCollector { id: actionErr }
        onExited: code => {
            if (code !== 0)
                root.error = actionErr.text.trim().split("\n").pop() || "Operation failed";
            root.busy = "";
            root.refresh();
        }
    }

    Timer {
        running: root.active
        repeat: true
        triggeredOnStart: true
        interval: 5000
        onTriggered: root.refresh()
    }
}
