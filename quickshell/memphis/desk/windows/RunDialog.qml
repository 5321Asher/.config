import QtQuick
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../widgets"
import ".."

// Run… — Memphis's app launcher (SUPER + CTRL + Space, Start → Run). Type: the programs that match
// drop down under the box, best first (apps you launch often rise); ↑ ↓ pick one, Enter opens it.
// If nothing matches, what you typed runs as a command (or opens, if it's a path or a web address),
// just like 98's Run box. The drop-down arrow lists what you ran before.
Win {
    id: root

    title: "Run"
    helpButton: true
    onHelpRequested: Desk.show("help")

    property string query: ""
    property int pick: 0
    property bool history: false        // the drop-down shows past commands instead of matches

    // ---------------------------------------------------------------- matching
    readonly property var apps: DesktopEntries.applications.values.filter(a => !a.noDisplay)
    function match(a, q) {
        const name = a.name.toLowerCase();
        if (name.startsWith(q)) return 100 - name.length * 0.1;
        if (name.split(/[\s\-_.]+/).some(w => w.startsWith(q))) return 80;
        if (q.length < 2) return 0;
        if (name.includes(q)) return 60;
        if (q.length < 3) return 0;
        const more = [a.genericName ?? "", (a.keywords ?? []).join(" "), a.comment ?? "", a.id ?? "", a.execString ?? ""]
            .join(" ").toLowerCase();
        return more.includes(q) ? 40 : 0;
    }
    readonly property var matches: {
        if (history) return state.mru.map(c => ({ cmd: c }));
        const q = query.trim().toLowerCase();
        if (q === "") return [];
        return apps.map(a => ({ app: a, s: match(a, q) }))
            .filter(m => m.s > 0)
            .map(m => Object.assign(m, { s: m.s + Math.min(45, 9 * Math.log2(1 + (state.launches[m.app.id] ?? 0))) }))
            .sort((x, y) => y.s - x.s || x.app.name.localeCompare(y.app.name))
            .slice(0, 8);
    }
    onQueryChanged: { pick = 0; history = false; }

    readonly property int baseH: 250
    readonly property int listH: matches.length ? Math.min(8, matches.length) * (Theme.menuItem - 2) + 8 : 0
    onListHChanged: Desk.resize("run", 480, baseH + listH)
    Component.onCompleted: { field.focusField(); Desk.resize("run", 480, baseH + listH); }
    onActiveChanged: if (active) field.focusField()

    function launch() {
        const m = matches[pick];
        const typed = query.trim();
        if (m?.app) {
            const counts = Object.assign({}, state.launches);
            counts[m.app.id] = (counts[m.app.id] ?? 0) + 1;
            state.launches = counts;
            state.save();
            m.app.execute();
        } else {
            const cmd = m?.cmd ?? typed;
            if (!cmd) return;
            const opens = /^(https?:\/\/|www\.|~?\/|file:)/.test(cmd);
            const target = cmd.startsWith("~") ? Quickshell.env("HOME") + cmd.slice(1) : cmd.startsWith("www.") ? "https://" + cmd : cmd;
            Quickshell.execDetached(opens ? ["xdg-open", target] : ["sh", "-c", cmd]);
            state.mru = [cmd].concat(state.mru.filter(c => c !== cmd)).slice(0, 12);
            state.save();
        }
        root.closeRequested();
    }

    // Launch counts and past commands, kept in Quickshell's state folder
    QtObject {
        id: state
        property var launches: ({})
        property var mru: []
        function save() { file.setText(JSON.stringify({ launches: launches, mru: mru })); }
    }
    FileView {
        id: file
        path: Quickshell.statePath("run.json")
        printErrors: false
        onLoaded: {
            try {
                const j = JSON.parse(text());
                state.launches = j.launches ?? {};
                state.mru = j.mru ?? [];
            } catch (e) {}
        }
    }

    // ---------------------------------------------------------------- the dialog
    Item {
        anchors.fill: parent
        anchors.margins: Theme.pad

        Icon {
            id: bigIcon
            name: "system-run"
            size: 40
        }
        Txt {
            x: bigIcon.width + Theme.pad + 4
            width: parent.width - x
            height: 44
            wrapMode: Text.Wrap
            verticalAlignment: Text.AlignTop
            text: "Type the name of a program, folder, document, or Internet resource, and Memphis will open it for you."
        }

        Txt { id: openLabel; y: 66; height: Theme.field; text: "Open:" }
        Field {
            id: field
            x: openLabel.width + 14
            y: 66
            width: parent.width - x - dropBtn.width
            text: root.query
            onEdited: root.query = text
            onAccepted: root.launch()
            input.Keys.onPressed: e => {
                if (e.key === Qt.Key_Down) { root.pick = Math.min(root.matches.length - 1, root.pick + 1); e.accepted = true; }
                else if (e.key === Qt.Key_Up) { root.pick = Math.max(0, root.pick - 1); e.accepted = true; }
                else if (e.key === Qt.Key_Escape) { root.closeRequested(); e.accepted = true; }
                else if (e.key === Qt.Key_Tab && root.matches[root.pick]?.app) {
                    root.query = root.matches[root.pick].app.name;
                    e.accepted = true;
                }
            }
        }
        Btn {
            id: dropBtn
            anchors.left: field.right
            y: 68
            width: Theme.field - 6
            implicitWidth: Theme.field - 6
            height: Theme.field - 4
            glyph: "down"
            padding: 0
            activeFocusOnTab: false
            onClicked: { root.history = !root.history; root.pick = 0; field.focusField(); }
        }

        // the matches, dropping down from the box
        ListBox {
            id: list
            visible: root.matches.length > 0
            x: field.x
            y: field.y + field.height
            width: field.width + dropBtn.width
            height: root.listH
            model: root.matches
            currentIndex: root.pick
            activeFocusOnTab: false
            iconOf: m => m.app ? (m.app.icon || "application-x-executable") : "utilities-terminal"
            textOf: m => m.app ? m.app.name + (m.app.genericName && m.app.genericName !== m.app.name ? "  —  " + m.app.genericName : "") : m.cmd
            onClicked: i => { root.pick = i; field.focusField(); }
            onActivated: i => { root.pick = i; root.launch(); }
        }

        Row {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            spacing: 8
            Btn { text: "OK"; isDefault: true; onClicked: root.launch() }
            Btn { text: "Cancel"; onClicked: root.closeRequested() }
            Btn {
                text: "Browse…"
                onClicked: browse.running = true
            }
        }
    }

    Process {
        id: browse
        command: ["zenity", "--file-selection", "--title=Browse"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim();
                if (p) { root.query = p.includes(" ") ? `"${p}"` : p; field.focusField(); }
            }
        }
    }
}
