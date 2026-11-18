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
//   qs ipc call lock takeover   lock at once, no snapshot: taking over a session lock whose locker
//                               died (theme lock --boot hands over from hyprlock this way)
//   qs ipc call lock preview    show the lock screen in a normal window, to look at it safely
//   qs ipc call lock close      close the preview (never a real lock)
//   qs ipc call lock state      what it's doing (tests)
//
// Security (audited 2026-11-17):
// - Only a PAM success unlocks, and only for the lock it was typed into: every lock bumps `session`;
//   an answer or an outro that belongs to an older session (or to a preview) is ignored, so closing a
//   preview, or unlocking, a moment before a new lock can never undo that lock.
// - lock/pam/netrunner-lock is pam_unix only (no faillock: wrong passwords never lock the account);
//   instead, after 5 wrong ones in a row each try waits 5 s, then 10, 20, 40, at most 60 (it counts
//   across locks until a right one).
// - Once the intro has played the desktop is gone from the screen (no blurred copy behind the lock);
//   the snapshot is only the first and last frames of the animations, in $XDG_RUNTIME_DIR (0700).
// - If the shell starts while Hyprland says the session is locked (it restarted under a lock, so
//   Hyprland shows "lockscreen died"), it takes the lock over again by itself.
Singleton {
    id: root

    property bool locked: false
    property bool previewing: false
    property bool secure: false              // the compositor has confirmed the lock (Lock.qml)
    property int session: 0
    // the logon dialog goes on the screen that had focus when it locked; the others just go blank
    property string mainScreen: ""

    // The animation: false -> true runs the intro, true -> false the outro (granted = the boot-up)
    property bool revealed: false
    property bool leaving: false

    // A snapshot of each monitor taken just before locking, for the intro's first frame and the
    // outro's last: $XDG_RUNTIME_DIR/netrunner-lock/<screen>-<shot>.ppm
    readonly property string shotDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/netrunner-lock"
    property string shot: ""
    function shotPath(screenName) { return shot === "" ? "" : `file://${shotDir}/${screenName}-${shot}.ppm`; }

    property string buffer: ""
    // "idle" | "verifying" | "denied" | "error" | "cooldown" | "granted"
    property string status: "idle"
    property string detail: ""          // PAM's own message, when it has one
    property int attempts: 0            // wrong in a row (kept across locks until a right one)
    property double coolUntil: 0
    readonly property int coolLeft: Math.max(0, Math.ceil((coolUntil - now) / 1000))
    property double now: Date.now()
    Timer { running: root.coolUntil > root.now; interval: 250; repeat: true; triggeredOnStart: true; onTriggered: root.now = Date.now() }

    readonly property string user: Quickshell.env("USER") ?? ""

    function lock() {
        if (locked) {
            // already locked; if it's on its way out (just unlocked), stay locked instead
            if (leave.running) { leave.stop(); leaving = false; revealed = true; status = "idle"; session++; }
            return;
        }
        if (snapping.running && !snapFor) return;
        begin();
        snap(false);
    }
    function takeover() {
        if (locked && secure) return;
        if (locked) locked = false;          // a lock we think we hold but the compositor never confirmed
        begin();
        snapGuard.stop();
        snapping.running = false;
        snapFor = false;
        mainScreen = Hyprland.focusedMonitor?.name ?? Quickshell.screens[0]?.name ?? "";
        pendingShot = "";
        engage();
    }
    function begin() {
        leave.stop();
        leaving = false;
        if (pam.active) pam.abort();
        session++;
        buffer = "";
        status = "idle";
        detail = "";
        previewing = false;
    }
    function preview() {
        if (locked || previewing || snapping.running) return;
        buffer = "";
        status = "idle";
        detail = "";
        snap(true);
    }
    function closePreview() {
        if (!previewing || locked) return;
        if (pam.active) pam.abort();
        buffer = "";
        status = "idle";
        leaveTo("preview");
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
        snapping.command = ["sh", "-c", `d="$1"; id="$2"; shift 2; mkdir -p -m 700 "$d"; rm -f "$d"/*.ppm
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
        onExited: if (root.pendingShot !== "" || root.snapFor) root.engage()
    }
    Timer { id: snapGuard; interval: 400; onTriggered: { snapping.running = false; root.engage(); } }
    // one frame for the surfaces to map on the snapshot, then run the intro
    Timer { id: arrive; interval: 40; onTriggered: root.revealed = true }

    // Run the outro, then really unlock (only the session it was granted for) or close the preview
    property string leaveKind: ""
    property int leaveSession: -1
    function leaveTo(kind) {
        leaveKind = kind;
        leaveSession = session;
        leaving = true;
        revealed = false;
        leave.restart();
    }
    Timer {
        id: leave
        interval: (root.leaveKind === "unlock" ? Theme.lockOutro : Theme.lockClose) + 60
        onTriggered: {
            if (root.leaveKind === "preview") root.previewing = false;
            else if (root.leaveKind === "unlock" && root.leaveSession === root.session) root.locked = false;
            else return;
            root.status = "idle";
            root.leaving = false;
            cleanup.running = true;
        }
    }
    Process {
        id: cleanup
        command: ["sh", "-c", 'rm -f "$1"/*.ppm', "sh", root.shotDir]
    }

    property int asked: -1              // the session the PAM run in progress was started for
    property bool askedPreview: false
    function submit() {
        if (pam.active || leaving) return;
        if (buffer === "") { status = "idle"; return; }
        if (Date.now() < coolUntil) { status = "cooldown"; buffer = ""; return; }
        status = "verifying";
        detail = "";
        asked = session;
        askedPreview = previewing && !locked;
        pam.start();
    }

    function granted() {
        status = "granted";
        buffer = "";
        attempts = 0;
        coolUntil = 0;
        leaveTo(askedPreview ? "preview" : "unlock");
    }
    function refused(why, message) {
        status = why;
        detail = message ?? "";
        buffer = "";
        if (why === "denied") {
            attempts++;
            if (attempts >= 5) coolUntil = Date.now() + Math.min(60, 5 * Math.pow(2, attempts - 5)) * 1000;
        }
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
            // an answer for a lock (or preview) that's no longer the current one counts for nothing
            const current = root.asked === root.session && (root.askedPreview ? root.previewing && !root.locked : root.locked);
            if (!current) { root.status = "idle"; return; }
            if (result === PamResult.Success) root.granted();
            else if (result === PamResult.Failed) root.refused("denied");
            else if (result === PamResult.MaxTries) root.refused("denied", "too many tries in one go · try again");
            else root.refused("error", pam.message);
        }
        onError: error => root.refused("error", PamError.toString(error))
    }

    // started under a lock (the shell restarted while locked): take it over, unless hyprlock holds it
    // (theme lock --boot is handing over from hyprlock and will call takeover itself)
    Process {
        id: lockedAtStart
        running: true
        command: ["sh", "-c", 'pidof hyprlock >/dev/null && exit 1; [ "$(hyprctl locked 2>/dev/null)" = true ]']
        onExited: code => { if (code === 0) root.takeover(); }
    }

    IpcHandler {
        target: "lock"

        function lock(): void { root.lock(); }
        function takeover(): void { root.takeover(); }
        function preview(): void { root.preview(); }
        // closes a preview only; a real lock only ever opens with the password
        function close(): void { root.closePreview(); }
        function state(): string {
            return `locked=${root.locked} secure=${root.secure} previewing=${root.previewing} session=${root.session} status=${root.status} attempts=${root.attempts} cool=${root.coolLeft} revealed=${root.revealed} leaving=${root.leaving}`;
        }
    }
}
