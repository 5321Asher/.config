pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import "../theme"

// Lock screen state and authentication, shared by every monitor's surface.
//
//   qs ipc call lock lock       lock the session (what `theme lock` / hypridle / SUPER+L run)
//   qs ipc call lock preview    show the lock screen in a normal window, to look at it safely
//                               (Esc closes it; a correct password just closes it too)
//
// Never locks you out: authentication uses lock/pam/observatory-lock (pam_unix only, no faillock),
// a wrong password only clears the field and says so, a PAM error is shown and you can try again,
// and nothing but a successful PAM check unlocks.
Singleton {
    id: root

    property bool locked: false
    property bool previewing: false

    property string buffer: ""
    // "idle" | "verifying" | "denied" | "error" | "granted"
    property string status: "idle"
    property string detail: ""          // PAM's own message, when it has one
    property int attempts: 0

    readonly property string user: Quickshell.env("USER") ?? ""

    function lock() {
        buffer = "";
        status = "idle";
        detail = "";
        previewing = false;
        locked = true;
    }
    function preview() {
        if (locked) return;
        buffer = "";
        status = "idle";
        detail = "";
        previewing = true;
    }
    function closePreview() {
        if (pam.active) pam.abort();
        previewing = false;
        buffer = "";
        status = "idle";
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
        leave.restart();
    }
    Timer {
        id: leave
        interval: Theme.normal
        onTriggered: { root.locked = false; root.previewing = false; root.status = "idle"; }
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
        config: "observatory-lock"
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
    }
}
