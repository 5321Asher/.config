pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pam
import "../theme"

// Lock screen state and authentication, shared by every monitor's surface.
//
//   qs ipc call lock lock       lock the session (what `theme lock` / hypridle / SUPER+L run)
//   qs ipc call lock preview    show the lock screen in a normal window, to look at it safely
//   qs ipc call lock close      close the preview (never a real lock)
//                               (Esc closes it; a correct password just closes it too)
//
// Never locks you out: authentication uses lock/pam/netrunner-lock (pam_unix only, no faillock),
// a wrong password only clears the field and says so, a PAM error is shown and you can try again,
// and nothing but a successful PAM check unlocks.
Singleton {
    id: root

    property bool locked: false
    property bool previewing: false
    // the logon dialog goes on the screen that had focus when it locked; the others just go blank
    property string mainScreen: ""

    // The animation: false -> true runs the intro (Theme.lockIntro), true -> false the outro.
    // `leaving` says which way the ring should go when it disappears (out = unlocking).
    property bool revealed: false
    property bool leaving: false

    // A snapshot of each monitor taken just before locking, so the lock can start from exactly what
    // was on screen and end on it again: $XDG_RUNTIME_DIR/netrunner-lock/<screen>-<shot>.ppm
    readonly property string shotDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/netrunner-lock"
    property string shot: ""
    function shotPath(screenName) { return shot === "" ? "" : `file://${shotDir}/${screenName}-${shot}.ppm`; }

    property string buffer: ""
    // "idle" | "verifying" | "denied" | "error" | "granted"
    property string status: "idle"
    property string detail: ""          // PAM's own message, when it has one
    property int attempts: 0

    readonly property string user: Quickshell.env("USER") ?? ""

    function lock() {
        if (locked || (snapping.running && !snapFor)) return;
        buffer = "";
        status = "idle";
        detail = "";
        previewing = false;
        snap(false);
    }
    function preview() {
        if (locked || previewing || snapping.running) return;
        buffer = "";
        status = "idle";
        detail = "";
        snap(true);
    }
    function closePreview() {
        if (pam.active) pam.abort();
        buffer = "";
        status = "idle";
        leaveTo();
    }

    // Snapshot every monitor (in parallel, uncompressed, into tmpfs), then lock / preview. If grim
    // fails or hangs, it locks anyway after 400 ms: the lock must never wait on a picture.
    property bool snapFor: false        // true = preview
    function snap(forPreview) {
        snapFor = forPreview;
        mainScreen = Hyprland.focusedMonitor?.name ?? Quickshell.screens[0]?.name ?? "";
        leaving = false;
        revealed = false;
        const id = String(Date.now());
        snapping.command = ["sh", "-c", `d="$1"; id="$2"; shift 2; mkdir -p "$d"; rm -f "$d"/*.ppm
            for o in "$@"; do grim -t ppm -o "$o" "$d/$o-$id.ppm" & done; wait`,
            "sh", shotDir, id].concat(Quickshell.screens.map(s => s.name));
        // published once grim has written the files (an Image asked earlier fails and never retries)
        pendingShot = id;
        shot = "";
        snapping.running = true;
        snapGuard.restart();
    }
    property string pendingShot: ""
    function engage() {
        snapGuard.stop();
        shot = pendingShot;
        if (snapFor) previewing = true;
        else { previewing = false; locked = true; }
        arrive.restart();
    }
    Process {
        id: snapping
        onExited: root.engage()
    }
    Timer { id: snapGuard; interval: 400; onTriggered: { snapping.running = false; root.engage(); } }
    // one frame for the surfaces to map on the snapshot, then run the intro
    Timer { id: arrive; interval: 40; onTriggered: root.revealed = true }

    // Run the outro, then really unlock (or close the preview) and drop the snapshots
    function leaveTo() {
        leaving = true;
        revealed = false;
        leave.restart();
    }
    Process {
        id: cleanup
        command: ["sh", "-c", 'rm -f "$1"/*.ppm', "sh", root.shotDir]
    }

    function submit() {
        if (pam.active) return;
        if (buffer === "") { status = "idle"; return; }
        status = "verifying";
        detail = "";
        pam.start();
    }

    function granted() {
        status = "granted";
        buffer = "";
        attempts = 0;
        leaveTo();
    }
    Timer {
        id: leave
        interval: Theme.lockOutro + 60
        onTriggered: {
            root.locked = false;
            root.previewing = false;
            root.status = "idle";
            root.leaving = false;
            cleanup.running = true;
        }
    }

    function refused(why, message) {
        status = why;
        detail = message ?? "";
        buffer = "";
        attempts++;
    }

    PamContext {
        id: pam

        configDirectory: Quickshell.shellDir + "/lock/pam"
        config: "netrunner-lock"
        user: root.user

        onResponseRequiredChanged: {
            if (responseRequired) respond(root.buffer);
        }
        onCompleted: result => {
            if (result === PamResult.Success) root.granted();
            else if (result === PamResult.Failed) root.refused("denied");
            else if (result === PamResult.MaxTries) root.refused("denied", "too many tries in one go · try again");
            else root.refused("error", pam.message);
        }
        onError: error => root.refused("error", PamError.toString(error))
    }

    IpcHandler {
        target: "lock"

        function lock(): void { root.lock(); }
        function preview(): void { root.preview(); }
        // closes a preview only; a real lock only ever opens with the password
        function close(): void { if (root.previewing && !root.locked) root.closePreview(); }
    }
}
