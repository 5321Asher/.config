import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import "../theme"
import "../widgets"
import "../services"

// EXEC 実行: the app launcher (SUPER + CTRL + Space), drawn as the game's quickhack scanner. Right,
// the QUICKHACKS: every program that matches what you type, best first (the ones you run often
// rise), each with its RAM cost; above them the RAM meter (your real free memory). Left, the
// target scan: the picked program's icon, name, what it is, its command and how often you've run
// it. Enter uploads the quickhack (a bar fills) and runs it; nothing matching runs what you typed
// as a command. ↑ ↓ / Tab pick, Esc closes. qs ipc call exec toggle
PanelWindow {
    id: root

    // Follows the focused monitor only while hidden: moving a shown window rebuilds its surface
    Binding on screen {
        when: !root.visible
        value: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        restoreMode: Binding.RestoreNone
    }
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
    // Where the pointer last really moved (screen coords): rows that scroll under a still cursor
    // mustn't take the selection, or stepping up past the top of the list jumps back down
    property point pointer: Qt.point(-1, -1)
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
            return apps.slice().sort((a, b) => boost(b) - boost(a) || a.name.localeCompare(b.name)).slice(0, 12);
        return apps.map(a => ({ a: a, s: match(a, q) })).filter(m => m.s > 0)
            .map(m => Object.assign(m, { s: m.s + boost(m.a) }))
            .sort((x, y) => y.s - x.s || x.a.name.localeCompare(y.a.name)).slice(0, 12).map(m => m.a);
    }
    readonly property var current: results[Math.min(pick, results.length - 1)] ?? null
    onQueryChanged: pick = 0

    function hash(t) {
        let h = 0;
        for (const c of t) h = (h * 31 + c.charCodeAt(0)) & 0xffff;
        return h;
    }
    function addr(a) { return "0x" + hash(a.id ?? a.name).toString(16).toUpperCase().padStart(4, "0"); }
    function cost(a) { return 1 + hash(a.name) % 6; }
    function exec(a) { return (a?.command ?? []).join(" ") || a?.execString || ""; }

    // ---------------------------------------------------------------- upload
    property bool uploading: false
    property real uploaded: 0
    property var target: null           // the app being uploaded, or null for a typed command
    SequentialAnimation {
        id: uploadAnim
        NumberAnimation { target: root; property: "uploaded"; from: 0; to: 1; duration: 480; easing.type: Easing.InOutQuad }
        PauseAnimation { duration: 120 }
        ScriptAction {
            script: {
                const a = root.target, cmd = root.query.trim();
                root.uploading = false;
                root.uploaded = 0;
                ExecState.open = false;
                if (a) {
                    const counts = Object.assign({}, root.launches);
                    counts[a.id] = (counts[a.id] ?? 0) + 1;
                    root.launches = counts;
                    usage.setText(JSON.stringify(root.launches));
                    a.execute();
                } else if (cmd) Quickshell.execDetached(["sh", "-c", cmd]);
            }
        }
    }
    function run() {
        if (uploading || (!current && !query.trim())) return;
        target = current;
        uploading = true;
        uploadAnim.restart();
    }
    FileView {
        id: usage
        path: Quickshell.statePath("exec-launches.json")
        printErrors: false
        onLoaded: { try { root.launches = JSON.parse(text()); } catch (e) {} }
    }

    // RAM: your real free memory, in ten blocks (an upload spends the quickhack's cost)
    readonly property int ramMax: 10
    readonly property int ramFree: Math.max(0, Math.round((1 - SysInfo.mem) * ramMax))
    readonly property int ramSpend: current ? Math.min(ramFree, cost(current)) : 0

    Connections {
        target: ExecState
        function onOpenChanged() {
            if (ExecState.open) {
                root.query = ""; root.pick = 0; root.uploading = false; root.uploaded = 0;
                field.focusField(); decode.replay();
            }
        }
    }

    // ---------------------------------------------------------------- backdrop
    Rectangle { anchors.fill: parent; color: Theme.alpha(Theme.bgDark, 0.72 * root.shown) }
    Canvas {        // scanlines
        anchors.fill: parent
        opacity: 0.5 * root.shown
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.fillStyle = Theme.alpha(Theme.red, 0.04);
            for (let y = 0; y < height; y += 3) ctx.fillRect(0, y, width, 1);
        }
    }
    MouseArea { anchors.fill: parent; onClicked: ExecState.open = false }

    Item {
        id: stage
        readonly property bool narrow: root.width < 1100
        width: Math.min(1180, root.width - 64)
        height: Math.min(root.height - 140, 620)
        anchors.centerIn: parent
        opacity: root.shown
        transform: Translate { y: (1 - root.shown) * -18 }
        MouseArea { anchors.fill: parent }

        // ---------------------------------------------------------------- target scan (left)
        Item {
            id: scan
            visible: !stage.narrow
            width: stage.narrow ? 0 : Math.round(stage.width * 0.4)
            height: stage.height

            Chamfer { anchors.fill: parent; cut: 18; corners: "tl br"; fill: Theme.alpha(Theme.bgDark, 0.92); stroke: Theme.alpha(Theme.cyan, 0.5) }
            Rectangle { width: parent.width; height: 34; color: Theme.alpha(Theme.cyan, 0.1) }
            Label { x: 18; y: 10; text: "TARGET SCAN"; color: Theme.cyan; strong: true }
            Label { anchors.right: parent.right; anchors.rightMargin: 18; y: 10; text: root.current ? root.addr(root.current) : "--" }

            // the icon in a scanner reticle
            Item {
                id: reticle
                x: 24; y: 58
                width: 132; height: 132
                Repeater {     // corner brackets
                    model: 4
                    Item {
                        required property int index
                        x: index % 2 ? reticle.width - 18 : 0
                        y: index > 1 ? reticle.height - 18 : 0
                        width: 18; height: 18
                        Rectangle { x: index % 2 ? 16 : 0; width: 2; height: 18; color: Theme.cyan }
                        Rectangle { y: index > 1 ? 16 : 0; width: 18; height: 2; color: Theme.cyan }
                    }
                }
                IconImage {
                    anchors.centerIn: parent
                    implicitSize: 84
                    source: Quickshell.iconPath(root.current?.icon || "application-x-executable", "application-x-executable")
                }
                Rectangle {    // the scan line
                    width: parent.width; height: 2
                    color: Theme.alpha(Theme.cyan, 0.8)
                    NumberAnimation on y { from: 6; to: 124; duration: 1400; loops: Animation.Infinite; running: root.visible }
                }
            }
            Column {
                x: reticle.x + reticle.width + 20
                y: reticle.y + 6
                width: scan.width - x - 20
                spacing: 6
                Tag { height: 20; text: (root.current?.genericName || "PROGRAM").toUpperCase(); color: Theme.cyan; outline: true }
                Text {
                    width: parent.width
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    text: (root.current?.name ?? (root.query.trim() ? root.query.trim() : "NO TARGET")).toUpperCase()
                    color: Theme.bright
                    font.family: Theme.display; font.pixelSize: 26; font.weight: Font.DemiBold
                }
                Label { text: root.current ? "LV." + (1 + (root.launches[root.current.id] ?? 0) % 99) + "  //  RAM " + root.cost(root.current) : "RAW COMMAND" }
            }
            Text {
                id: desc
                x: 24
                y: reticle.y + reticle.height + 22
                width: scan.width - 48
                wrapMode: Text.Wrap
                maximumLineCount: 4
                elide: Text.ElideRight
                text: root.current ? (root.current.comment || root.current.genericName || "No description on file.")
                    : root.query.trim() ? "Nothing matches. Uploading runs it as a shell command." : "Type to scan for programs."
                color: Theme.fg
                font.family: Theme.sans; font.pixelSize: Theme.data + 1
                lineHeight: 1.15
            }
            Column {
                x: 24
                y: desc.y + desc.height + 20
                width: scan.width - 48
                spacing: 8
                Rectangle { width: parent.width; height: 1; color: Theme.alpha(Theme.line, 0.9) }
                KV { width: parent.width; key: "EXEC"; value: root.current ? root.exec(root.current) : root.query.trim() }
                KV { width: parent.width; key: "ID"; value: root.current?.id ?? "--" }
                KV { width: parent.width; key: "UPLOADS"; value: root.current ? String(root.launches[root.current.id] ?? 0) : "--" }
            }
            Hazard { x: 24; anchors.bottom: parent.bottom; anchors.bottomMargin: 18; width: 110; height: 6 }
            Jp { anchors.right: parent.right; anchors.rightMargin: 22; anchors.bottom: parent.bottom; anchors.bottomMargin: 12; text: "スキャン" }
        }

        // ---------------------------------------------------------------- quickhacks (right)
        Item {
            id: hacks
            x: stage.narrow ? 0 : scan.width + 20
            width: stage.width - x
            height: stage.height

            Row {
                id: head
                spacing: 10
                Tag { anchors.verticalCenter: parent.verticalCenter; text: "QUICKHACKS"; height: 24; pixelSize: Theme.label + 2 }
                Scramble { id: decode; anchors.verticalCenter: parent.verticalCenter; target: "EXEC // RUN PROGRAM"; color: Theme.bright
                           font.family: Theme.mono; font.pixelSize: Theme.label + 1; font.letterSpacing: Theme.tracking; font.weight: Font.DemiBold }
                Jp { anchors.verticalCenter: parent.verticalCenter; text: "実行" }
            }
            // RAM meter
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: head.verticalCenter
                spacing: 10
                Label { anchors.verticalCenter: parent.verticalCenter; text: "RAM"; color: Theme.cyan; strong: true }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    Repeater {
                        model: root.ramMax
                        Rectangle {
                            required property int index
                            readonly property bool free: index < root.ramFree
                            readonly property bool spent: free && index >= root.ramFree - root.ramSpend
                            width: 12; height: 18
                            color: !free ? "transparent" : spent ? (root.uploading ? Theme.alpha(Theme.cyan, 0.25) : Theme.alpha(Theme.cyan, 0.55)) : Theme.cyan
                            border.width: 1
                            border.color: free ? Theme.cyan : Theme.alpha(Theme.line, 0.9)
                        }
                    }
                }
                Label { anchors.verticalCenter: parent.verticalCenter; text: root.ramFree + "/" + root.ramMax; strong: true }
            }

            Field {
                id: field
                y: 44
                width: parent.width
                height: 40
                text: root.query
                placeholder: "SCAN //  type a program  //  enter uploads  //  no match runs it as a command"
                onEdited: root.query = text
                onAccepted: root.run()
                input.font.pixelSize: 17
                input.Keys.onPressed: e => {
                    if (root.uploading) { e.accepted = true; return; }
                    if (e.key === Qt.Key_Down || e.key === Qt.Key_Tab) { root.pick = Math.min(root.results.length - 1, root.pick + 1); e.accepted = true; }
                    else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab) { root.pick = Math.max(0, root.pick - 1); e.accepted = true; }
                    else if (e.key === Qt.Key_Escape) { ExecState.open = false; e.accepted = true; }
                }
            }

            ListView {
                id: list
                y: field.y + field.height + 12
                width: parent.width
                height: parent.height - y - 26
                clip: true
                spacing: 4
                model: root.results
                currentIndex: root.pick
                boundsBehavior: Flickable.StopAtBounds
                delegate: Item {
                    id: r
                    required property var modelData
                    required property int index
                    readonly property bool sel: index === root.pick
                    readonly property bool going: sel && root.uploading
                    width: list.width
                    height: 46

                    Chamfer {
                        anchors.fill: parent
                        cut: 10; corners: "tr bl"
                        fill: r.sel ? Theme.alpha(Theme.red, 0.18) : Theme.alpha(Theme.bgDark, 0.72)
                        stroke: r.sel ? Theme.red : Theme.alpha(Theme.line, 0.9)
                    }
                    // the upload bar, filling the row
                    Rectangle {
                        visible: r.going
                        x: 1; y: 1
                        width: (parent.width - 2) * root.uploaded
                        height: parent.height - 2
                        color: Theme.alpha(Theme.red, 0.35)
                    }
                    Text { x: 12; anchors.verticalCenter: parent.verticalCenter; text: r.sel ? "▶" : ""; color: Theme.red; font.pixelSize: 12 }
                    IconImage {
                        x: 30; anchors.verticalCenter: parent.verticalCenter; implicitSize: 26
                        source: Quickshell.iconPath(r.modelData.icon || "application-x-executable", "application-x-executable")
                    }
                    Column {
                        x: 68
                        width: parent.width - x - 120
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            width: parent.width; elide: Text.ElideRight
                            text: r.modelData.name.toUpperCase()
                            color: r.sel ? Theme.bright : Theme.fg
                            font.family: Theme.condensed; font.pixelSize: 19; font.weight: Font.DemiBold; font.letterSpacing: 1
                        }
                        Label {
                            width: parent.width; elide: Text.ElideRight
                            visible: text !== ""
                            text: r.going ? "UPLOADING  " + Math.round(root.uploaded * 100) + "%" : (r.modelData.genericName || "")
                            color: r.going ? Theme.red : r.sel ? Theme.cyan : Theme.dim
                        }
                    }
                    Label { anchors.right: cost.left; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: root.addr(r.modelData) }
                    // RAM cost
                    Rectangle {
                        id: cost
                        anchors.right: parent.right; anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28; height: 28
                        color: r.sel ? Theme.cyan : "transparent"
                        border.width: 1
                        border.color: Theme.cyan
                        Text {
                            anchors.centerIn: parent
                            text: root.cost(r.modelData)
                            color: r.sel ? Theme.bgDark : Theme.cyan
                            font.family: Theme.mono; font.pixelSize: 14; font.weight: Font.Bold
                        }
                    }
                    MouseArea {
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onPositionChanged: mouse => { const p = mapToGlobal(mouse.x, mouse.y); if (p.x !== root.pointer.x || p.y !== root.pointer.y) { root.pointer = p; if (!root.uploading) root.pick = r.index; } }
                        onClicked: { root.pick = r.index; root.run(); }
                    }
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 20
                    visible: root.results.length === 0
                    text: root.query ? "NO QUICKHACK MATCHES  //  ENTER RUNS  \"" + root.query + "\"" : ""
                }
            }
            Label {
                anchors.bottom: parent.bottom
                text: root.query ? root.results.length + " MATCH" + (root.results.length === 1 ? "" : "ES") + "   //   ↑↓ PICK   //   ENTER UPLOAD   //   ESC CLOSE"
                                 : "MOST RUN   //   ↑↓ PICK   //   ENTER UPLOAD   //   ESC CLOSE"
            }
        }
    }
}
