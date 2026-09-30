import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"
import "../widgets"
import "../settings"

// Run (Win + R), as Windows 11 draws it: a small dialog at the bottom left with its own title bar,
// "Type the name of a program, folder, document, or Internet resource, and Windows will open it for
// you.", an Open box that remembers what you ran, and OK / Cancel / Browse…. It understands the
// Windows names (cmd, powershell, wt, notepad, explorer, C:\ paths, control, ms-settings:, taskmgr,
// calc, URLs); anything else runs as a command, and what can't be found gets Windows' error.
Item {
    id: root

    property string screenName
    property bool active: false
    property string error: ""

    onActiveChanged: if (active) { error = ""; field.text = history[0] ?? ""; focusLater.restart(); }
    Timer { id: focusLater; interval: 30; onTriggered: { field.input.forceActiveFocus(); field.input.selectAll(); } }

    // ---------------------------------------------------------------- history
    property var history: []
    FileView {
        id: histFile
        path: Quickshell.statePath("run-history.json")
        printErrors: false
        onLoaded: { try { root.history = JSON.parse(text()); } catch (e) {} }
    }
    function remember(t) {
        history = [t].concat(history.filter(x => x !== t)).slice(0, 20);
        histFile.setText(JSON.stringify(history));
    }

    // ---------------------------------------------------------------- what it means
    // C:\Users\av\Documents -> /home/av/Documents, C:\etc -> /etc, %USERPROFILE% -> ~
    function unixPath(p) {
        const home = Quickshell.env("HOME"), user = Quickshell.env("USER");
        p = p.replace(/%userprofile%/ig, `C:\\Users\\${user}`).replace(/^"|"$/g, "");
        const m = /^([a-z]):[\\\/]?(.*)$/i.exec(p);
        if (!m) return null;
        let rest = m[2].replace(/\\/g, "/");
        const users = new RegExp(`^users/${user}(/|$)`, "i");
        if (users.test(rest)) return home + "/" + rest.replace(users, "");
        return "/" + rest;
    }
    function plan(text) {
        const t = text.trim();
        const low = t.toLowerCase();
        const word = low.split(/\s+/)[0];
        const argsOf = () => t.slice(word.length).trim();
        if (/^(https?:\/\/|www\.)/.test(low)) return ["xdg-open", low.startsWith("www.") ? "https://" + t : t];
        if (/^ms-settings:?/.test(low)) return { settings: low.replace(/^ms-settings:?/, "") || "home" };
        const path = unixPath(t);
        if (path !== null) return ["thunar", path];
        switch (word) {
        case "cmd": case "cmd.exe": case "powershell": case "powershell.exe": case "pwsh": case "wt": case "wt.exe":
            return ["kitty"];
        case "explorer": case "explorer.exe": {
            const a = argsOf();
            return ["thunar", a ? (unixPath(a) ?? a) : Quickshell.env("HOME")];
        }
        case "notepad": case "notepad.exe": case "write":
            return ["kitty", "-e", Quickshell.env("EDITOR") || "nvim"].concat(argsOf() ? [argsOf()] : []);
        case "control": case "control.exe": return { settings: "home" };
        case "taskmgr": case "taskmgr.exe": return { settings: "performance" };
        case "calc": case "calc.exe": return ["sh", "-c", "gnome-calculator || qalculate-gtk || kitty -e qalc"];
        case "msinfo32": case "winver": return { settings: "about" };
        case "ncpa.cpl": return { settings: "network" };
        case "mmsys.cpl": return { settings: "sound" };
        case "desk.cpl": return { settings: "display" };
        case "appwiz.cpl": return { settings: "apps" };
        case ".": return ["thunar", Quickshell.env("HOME")];
        }
        return ["sh", "-c", `command -v ${word.replace(/[^a-zA-Z0-9._+-]/g, "")} >/dev/null || exit 127; exec ${t}`];
    }

    function run() {
        const t = field.text.trim();
        if (!t) return;
        const p = plan(t);
        if (!Array.isArray(p)) {
            remember(t);
            Flyouts.close();
            SettingsApp.open(p.settings);
            return;
        }
        checker.cmd = p;
        checker.text = t;
        checker.command = p[0] === "sh" ? p : ["sh", "-c", 'command -v "$1" >/dev/null', "sh", p[0]];
        checker.running = true;
    }
    // Only a command that exists closes the dialog; else Windows' message
    Process {
        id: checker
        property var cmd: []
        property string text: ""
        onExited: code => {
            if (cmd[0] === "sh" ? code === 127 : code !== 0) {
                root.error = `Windows cannot find '${text}'. Make sure you typed the name correctly, and then try again.`;
                return;
            }
            root.remember(text);
            Flyouts.close();
            if (cmd[0] !== "sh") Quickshell.execDetached(cmd);
        }
    }

    // ---------------------------------------------------------------- the dialog
    Acrylic { anchors.fill: parent; tint: Theme.mica; tintAlpha: 1 }

    // title bar
    Item {
        id: titleBar
        width: parent.width
        height: 32
        Glyph { x: 12; anchors.verticalCenter: parent.verticalCenter; g: "\uE7C4"; size: 14; color: Theme.accent }
        Txt { x: 36; anchors.verticalCenter: parent.verticalCenter; text: "Run"; size: Theme.caption }
        Rectangle {
            id: closeBtn
            anchors.right: parent.right
            width: 46; height: 32
            topRightRadius: Theme.radiusLarge
            color: closeMouse.containsMouse ? Theme.closeRed : "transparent"
            Glyph { anchors.centerIn: parent; g: "\uE8BB"; size: 10; color: closeMouse.containsMouse ? "#ffffff" : Theme.text }
            MouseArea { id: closeMouse; anchors.fill: parent; hoverEnabled: true; onClicked: Flyouts.close() }
        }
    }

    Item {
        x: 24; y: titleBar.height + 12
        width: parent.width - 48
        height: parent.height - y - 24

        // the Run icon and the sentence
        Rectangle {
            id: runIcon
            width: 32; height: 32; radius: 4
            color: Theme.accent
            Glyph { anchors.centerIn: parent; g: "\uE7C4"; size: 18; color: Theme.accentText }
        }
        Txt {
            x: runIcon.width + 16
            width: parent.width - x
            wrapMode: Text.Wrap
            text: "Type the name of a program, folder, document, or Internet resource, and Windows will open it for you."
        }

        Row {
            y: 64
            spacing: 12
            Txt { width: 40; height: Theme.controlHeight; verticalAlignment: Text.AlignVCenter; text: "Open:" }
            Field {
                id: field
                width: root.width - 48 - 52
                height: Theme.controlHeight
                onAccepted: root.run()
                input.Keys.onUpPressed: { const i = root.history.indexOf(field.text); field.text = root.history[Math.max(0, i - 1)] ?? field.text; }
                input.Keys.onDownPressed: { const i = root.history.indexOf(field.text); field.text = root.history[Math.min(root.history.length - 1, i + 1)] ?? field.text; }
                input.onTextEdited: root.error = ""
            }
        }
        Txt {
            y: 104
            width: parent.width
            visible: root.error !== ""
            wrapMode: Text.Wrap
            color: Theme.danger
            size: Theme.caption
            text: root.error
        }

        Row {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            spacing: 8
            Btn { width: 88; kind: "accent"; text: "OK"; enabled: field.text.trim() !== ""; onClicked: root.run() }
            Btn { width: 88; text: "Cancel"; onClicked: Flyouts.close() }
            Btn { width: 88; text: "Browse…"; onClicked: { Flyouts.close(); Quickshell.execDetached(["thunar", Quickshell.env("HOME")]); } }
        }
    }
}
