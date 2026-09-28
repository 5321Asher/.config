import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import "../theme"
import "../widgets"

// EXEC 実行: the app launcher (SUPER + CTRL + Space). A cut-corner console in the middle of the
// screen: type, and the programs that match line up best first (apps you run often rise), each
// with a hex address; ↑ ↓ pick, Enter runs, Esc closes. Nothing matching? Enter runs what you
// typed as a command. qs ipc call exec toggle
PanelWindow {
    id: root

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    visible: ExecState.open || shown > 0.01

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "netrunner-exec"
    WlrLayershell.keyboardFocus: ExecState.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property real shown: ExecState.open ? 1 : 0
    Behavior on shown { NumberAnimation { duration: Theme.normal; easing.type: Theme.easing } }

    // ---------------------------------------------------------------- matching
    readonly property var apps: DesktopEntries.applications.values.filter(a => !a.noDisplay).sort((a, b) => a.name.localeCompare(b.name))
    property string query: ""
    property int pick: 0
    property var launches: ({})

    function match(a, q) {
        const name = a.name.toLowerCase();
        if (name.startsWith(q)) return 100 - name.length * 0.1;
        if (name.split(/[\s\-_.]+/).some(w => w.startsWith(q))) return 80;
        if (q.length < 2) return 0;
        if (name.includes(q)) return 60;
        if (q.length < 3) return 0;
        const more = [a.genericName ?? "", (a.keywords ?? []).join(" "), a.comment ?? "", a.id ?? ""].join(" ").toLowerCase();
        return more.includes(q) ? 40 : 0;
    }
    readonly property var results: {
        const q = query.trim().toLowerCase();
        const boost = a => Math.min(45, 9 * Math.log2(1 + (launches[a.id] ?? 0)));
        if (q === "")        // nothing typed: the ones you run most
            return apps.slice().sort((a, b) => boost(b) - boost(a) || a.name.localeCompare(b.name)).slice(0, 10);
        return apps.map(a => ({ a: a, s: match(a, q) })).filter(m => m.s > 0)
            .map(m => Object.assign(m, { s: m.s + boost(m.a) }))
            .sort((x, y) => y.s - x.s || x.a.name.localeCompare(y.a.name)).slice(0, 10).map(m => m.a);
    }
    onQueryChanged: pick = 0

    function run() {
        const a = results[pick];
        if (a) {
            const counts = Object.assign({}, launches);
            counts[a.id] = (counts[a.id] ?? 0) + 1;
            launches = counts;
            usage.setText(JSON.stringify(launches));
            a.execute();
        } else if (query.trim()) Quickshell.execDetached(["sh", "-c", query.trim()]);
        ExecState.open = false;
    }
    FileView {
        id: usage
        path: Quickshell.statePath("exec-launches.json")
        printErrors: false
        onLoaded: { try { root.launches = JSON.parse(text()); } catch (e) {} }
    }
    function addr(a) {
        let h = 0;
        for (const c of a.id ?? a.name) h = (h * 31 + c.charCodeAt(0)) & 0xffff;
        return "0x" + h.toString(16).toUpperCase().padStart(4, "0");
    }

    Connections {
        target: ExecState
        function onOpenChanged() { if (ExecState.open) { root.query = ""; root.pick = 0; field.focusField(); decode.replay(); } }
    }

    // ---------------------------------------------------------------- look
    Rectangle { anchors.fill: parent; color: Theme.alpha(Theme.bgDark, 0.55 * root.shown) }
    MouseArea { anchors.fill: parent; onClicked: ExecState.open = false }

    Item {
        id: box
        width: Math.min(720, root.width - 80)
        height: 104 + Math.max(1, root.results.length) * 44
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.22
        opacity: root.shown
        transform: Translate { y: (1 - root.shown) * -16 }

        MouseArea { anchors.fill: parent }

        Chamfer { anchors.fill: parent; cut: 18; corners: "tr bl"; fill: Theme.alpha(Theme.bgDark, 0.95); stroke: Theme.alpha(Theme.red, 0.7) }
        Hazard { x: parent.width - 120; y: parent.height - 6; width: 90; height: 6 }

        Row {
            x: 18; y: 16
            spacing: 10
            Tag { anchors.verticalCenter: parent.verticalCenter; text: "EXEC"; height: 22 }
            Scramble { id: decode; anchors.verticalCenter: parent.verticalCenter; target: "RUN PROGRAM"; color: Theme.bright
                       font.family: Theme.mono; font.pixelSize: Theme.label + 1; font.letterSpacing: Theme.tracking; font.weight: Font.DemiBold }
            Jp { anchors.verticalCenter: parent.verticalCenter; text: "実行" }
        }
        Label {
            anchors.right: parent.right
            anchors.rightMargin: 22
            y: 20
            text: root.query ? root.results.length + " MATCH" + (root.results.length === 1 ? "" : "ES") : "MOST RUN"
        }

        Field {
            id: field
            x: 18; y: 50
            width: parent.width - 36
            height: 38
            text: root.query
            placeholder: "type to search  //  enter runs  //  no match runs it as a command"
            onEdited: root.query = text
            onAccepted: root.run()
            input.font.pixelSize: 17
            input.Keys.onPressed: e => {
                if (e.key === Qt.Key_Down || e.key === Qt.Key_Tab) { root.pick = Math.min(root.results.length - 1, root.pick + 1); e.accepted = true; }
                else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab) { root.pick = Math.max(0, root.pick - 1); e.accepted = true; }
                else if (e.key === Qt.Key_Escape) { ExecState.open = false; e.accepted = true; }
            }
        }

        Column {
            x: 18; y: 98
            width: parent.width - 36
            Label { visible: root.results.length === 0; height: 44; text: root.query ? "NO MATCH  //  ENTER RUNS  \"" + root.query + "\"" : "" }
            Repeater {
                model: root.results
                Item {
                    id: r
                    required property var modelData
                    required property int index
                    readonly property bool sel: index === root.pick
                    width: parent.width
                    height: 44
                    Rectangle {
                        anchors.fill: parent
                        color: r.sel ? Theme.alpha(Theme.red, 0.16) : "transparent"
                        Rectangle { visible: r.sel; width: 3; height: parent.height; color: Theme.red }
                    }
                    Text { x: 14; anchors.verticalCenter: parent.verticalCenter; text: root.addr(r.modelData); color: r.sel ? Theme.red : Theme.dim
                           font.family: Theme.mono; font.pixelSize: Theme.label }
                    IconImage { x: 82; anchors.verticalCenter: parent.verticalCenter; implicitSize: 24
                                source: Quickshell.iconPath(r.modelData.icon || "application-x-executable", "application-x-executable") }
                    Column {
                        x: 118
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - x - 20
                        Text { width: parent.width; elide: Text.ElideRight; text: r.modelData.name; color: r.sel ? Theme.bright : Theme.fg
                               font.family: Theme.sans; font.pixelSize: Theme.data + 2; font.weight: Font.Medium }
                        Label { width: parent.width; elide: Text.ElideRight; text: r.modelData.genericName || r.modelData.comment || ""; font.pixelSize: Theme.label - 1
                                color: r.sel ? Theme.cyan : Theme.dim }
                    }
                    MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onEntered: root.pick = r.index; onClicked: { root.pick = r.index; root.run(); } }
                }
            }
        }
    }
}
