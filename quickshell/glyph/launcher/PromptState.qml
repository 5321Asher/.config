pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Questions from ~/.config/theme/prompt (the web-app and keybind scripts), shown by launcher/Prompt.qml.
// The script leaves a request directory with request.json and a FIFO named reply, then waits on it:
//   qs ipc call prompt ask <dir>
// answer(text) writes the reply; cancel() writes nothing, which the scripts read as "cancelled".
Singleton {
    id: root

    property string dir: ""
    property var request: ({ placeholder: "", options: [], index: false, input: true })
    readonly property bool open: dir !== ""

    function answer(text) {
        if (dir === "") return;
        Quickshell.execDetached(["sh", "-c", 'printf "%s" "$1" > "$2"', "sh", text, dir + "/reply"]);
        dir = "";
    }
    function cancel() { answer(""); }

    FileView {
        id: file
        printErrors: false
        onLoaded: {
            try {
                root.request = JSON.parse(text());
            } catch (e) {
                console.warn("prompt request:", e);
                root.cancel();
            }
        }
        onLoadFailed: root.cancel()
    }

    IpcHandler {
        target: "prompt"

        function ask(dir: string): void {
            root.cancel();      // a newer question replaces one still open
            root.dir = dir;
            file.path = "";
            file.path = dir + "/request.json";
        }
        function cancel(): void { root.cancel(); }
    }
}
