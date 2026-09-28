pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../theme"

// Screenshots (grim + slurp → Satty editor), OCR (tesseract → clipboard) and screen recording
// (gpu-screen-recorder or wf-recorder). Same as Sharp's, in Observatory's colours; the recording
// beacon on the horizon line (bar/Beacons.qml) shows and stops a recording.
Singleton {
    id: root

    // "gpu-screen-recorder", "wf-recorder" or ""
    property string recorder: ""
    property bool hasHyprlock: false
    property bool recording: false
    property date startedAt
    property int elapsed: 0
    property string lastFile: ""

    // slurp selection: a black rubber band with a faint highlight-colour fill, the screen barely dimmed
    readonly property var slurpArgs: {
        const hex = c => c.toString().slice(-6);
        return ["-c", "#000000ff", "-s", "#" + hex(Theme.select) + "33", "-b", "#00000044", "-w", "1"];
    }

    readonly property string elapsedText: Math.floor(elapsed / 60) + ":" + String(elapsed % 60).padStart(2, "0")

    // mode: "region" or "screen". Delay lets popouts close before capturing.
    // The capture opens in Satty (~/.config/satty/config.toml) to annotate, copy or save.
    function screenshot(mode) {
        // Detached so a still-open Satty window doesn't block the next capture
        Quickshell.execDetached(["sh", "-c", `
            sleep 0.35
            mkdir -p "$HOME/Pictures/Screenshots"
            mode="$1" output="$2"; shift 2   # the rest is slurpArgs
            if [ "$mode" = region ]; then
                # slurp reads preset boxes from stdin when it isn't a TTY; give it nothing
                geo="$(slurp "$@" < /dev/null)" || exit 0
                set -- -g "$geo"
            else
                set -- -o "$output"
            fi
            grim "$@" - | satty --filename -`,
            "sh", mode, Hyprland.focusedMonitor?.name ?? "", ...slurpArgs]);
    }

    // Select a region, read its text with tesseract and put it on the clipboard
    function ocr() {
        Quickshell.execDetached(["sh", "-c", `
            sleep 0.35
            if ! command -v tesseract >/dev/null; then
                notify-send -a OCR "OCR unavailable" "Install tesseract and tesseract-data-eng"; exit 1
            fi
            geo="$(slurp "$@" < /dev/null)" || exit 0
            # 2x upscale: tesseract is much more accurate on small UI text
            text="$(grim -s 2 -g "$geo" - | tesseract stdin stdout -l eng 2>/dev/null | sed -e 's/[[:space:]]*$//' | sed -e '/./,$!d')"
            if [ -z "$text" ]; then
                notify-send -a OCR "No text found" "Nothing readable in the selection"
            else
                printf '%s' "$text" | wl-copy
                notify-send -a OCR "Text copied" "$(printf '%s' "$text" | head -c 200)"
            fi`,
            "sh", ...slurpArgs]);
    }

    function toggleRecording() {
        if (recording) {
            // SIGINT lets the recorder finish writing the file
            rec.signal(2);
            return;
        }
        if (!recorder)
            return;
        const output = Hyprland.focusedMonitor?.name ?? "";
        const dir = Quickshell.env("HOME") + "/Videos/Recordings";
        const stamp = Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss");
        lastFile = dir + "/Recording_" + stamp + ".mp4";
        const cmd = recorder === "gpu-screen-recorder"
            ? `gpu-screen-recorder -w "$1" -f 60 -a default_output -o "$2"`
            : `wf-recorder -o "$1" --audio -f "$2"`;
        rec.command = ["sh", "-c", `sleep 0.35; mkdir -p "$(dirname "$2")"; exec ${cmd}`, "sh", output, lastFile];
        rec.running = true;
    }

    Process {
        running: true
        command: ["sh", "-c", "for c in gpu-screen-recorder wf-recorder hyprlock; do command -v $c >/dev/null && echo $c; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = text.trim().split("\n");
                root.recorder = found.includes("gpu-screen-recorder") ? "gpu-screen-recorder"
                    : found.includes("wf-recorder") ? "wf-recorder" : "";
                root.hasHyprlock = found.includes("hyprlock");
            }
        }
    }

    // qs ipc call capture toggleRecording | screenshot region|screen | ocr
    IpcHandler {
        target: "capture"

        function toggleRecording(): void {
            root.toggleRecording();
        }
        function screenshot(mode: string): void {
            root.screenshot(mode === "screen" ? "screen" : "region");
        }
        function ocr(): void {
            root.ocr();
        }
    }

    Process {
        id: rec

        onRunningChanged: {
            root.recording = running;
            if (running) {
                root.startedAt = new Date();
                root.elapsed = 0;
            }
        }
        onExited: code => {
            Quickshell.execDetached(["notify-send", "-a", "Recorder",
                code === 0 || code === 130 ? "Recording saved" : "Recording failed",
                root.lastFile]);
        }
    }

    Timer {
        running: root.recording
        repeat: true
        interval: 1000
        onTriggered: root.elapsed = Math.round((Date.now() - root.startedAt.getTime()) / 1000)
    }
}
