import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import "../theme"
import "../widgets"

// DATA SHARDS データ: clipboard history (SUPER + V), in place of Walker's. Every copied thing is a
// shard in the index on the left, newest first (pinned ones on top); the picked shard is decrypted
// on the right (text, or the picture itself). Same history as Walker: elephant's clipboard provider.
// Type to search, ↑ ↓ pick, Enter copies it back, Ctrl+P pins / unpins, Ctrl+D / Delete wipes it,
// Ctrl+Shift+D wipes every unpinned shard (press twice), Esc closes. qs ipc call clipboard toggle
PanelWindow {
    id: root

    Binding on screen {
        when: !root.visible
        value: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        restoreMode: Binding.RestoreNone
    }
    visible: ClipboardState.open || shown > 0.01

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "netrunner-shards"
    WlrLayershell.keyboardFocus: ClipboardState.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property real shown: ClipboardState.open ? 1 : 0
    Behavior on shown { NumberAnimation { duration: Theme.normal; easing.type: Theme.easing } }

    // ---------------------------------------------------------------- history
    property var items: []
    property bool loaded: false
    property string query: ""
    property int sel: 0
    property bool clearArmed: false
    property point pointer: Qt.point(-1, -1)

    function isImage(it) { return it.preview_type === "file"; }
    function pinned(it) { return (it.actions ?? []).includes("unpin"); }
    readonly property var filtered: {
        const q = query.trim().toLowerCase();
        const list = q === "" ? items : items.filter(it => !isImage(it) && (it.text ?? "").toLowerCase().includes(q));
        return list.filter(it => pinned(it)).concat(list.filter(it => !pinned(it)));
    }
    readonly property var current: filtered[Math.min(sel, filtered.length - 1)] ?? null
    onQueryChanged: sel = 0

    function refresh() { query_.running = false; query_.running = true; }
    function act(it, action, close) {
        if (!it) return;
        if (close) ClipboardState.open = false;
        activate.command = ["elephant", "activate", `clipboard;${it.identifier};${action};;`];
        activate.closing = close;
        activate.running = true;
    }
    function step(d) {
        const n = filtered.length;
        if (n > 0) sel = Math.max(0, Math.min(n - 1, sel + d));
    }
    function ago(stamp) {
        const t = Date.parse(stamp);
        if (isNaN(t)) return stamp ?? "";
        const s = Math.max(0, (Date.now() - t) / 1000);
        if (s < 60) return "JUST NOW";
        if (s < 3600) return Math.floor(s / 60) + " MIN AGO";
        if (s < 86400) return Math.floor(s / 3600) + " H AGO";
        return Math.floor(s / 86400) + " D AGO";
    }
    function addr(it) {
        let h = 0;
        for (const c of it.identifier ?? "") h = (h * 31 + c.charCodeAt(0)) & 0xffff;
        return "0x" + h.toString(16).toUpperCase().padStart(4, "0");
    }

    Process {
        id: query_
        command: ["elephant", "query", "--json", "clipboard;;500;false"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    if (!line.trim()) continue;
                    try { out.push(JSON.parse(line).item); } catch (e) {}
                }
                root.items = out;
                root.loaded = true;
                root.sel = Math.min(root.sel, Math.max(0, root.filtered.length - 1));
            }
        }
    }
    Process {
        id: activate
        property bool closing: false
        onExited: if (!closing) root.refresh()
    }
    Connections {
        target: ClipboardState
        function onOpenChanged() {
            if (ClipboardState.open) {
                root.query = ""; root.sel = 0; root.clearArmed = false; root.loaded = false;
                root.refresh();
                field.focusField();
                title.replay();
            }
        }
    }
    Timer { id: disarm; interval: 2500; onTriggered: root.clearArmed = false }

    // ---------------------------------------------------------------- look
    Rectangle { anchors.fill: parent; color: Theme.alpha(Theme.bgDark, 0.7 * root.shown) }
    MouseArea { anchors.fill: parent; onClicked: ClipboardState.open = false }

    Item {
        id: stage
        readonly property bool narrow: width < 860
        width: Math.min(1180, root.width - 64)
        height: Math.min(root.height - 140, 640)
        anchors.centerIn: parent
        opacity: root.shown
        transform: Translate { y: (1 - root.shown) * -16 }
        MouseArea { anchors.fill: parent }

        Row {
            id: head
            spacing: 10
            Tag { anchors.verticalCenter: parent.verticalCenter; text: "DATA SHARDS"; height: 24; pixelSize: Theme.label + 2; color: Theme.cyan }
            Scramble { id: title; anchors.verticalCenter: parent.verticalCenter; target: "CLIPBOARD // " + (root.loaded ? root.items.length + " SHARDS" : "READING")
                       color: Theme.bright; font.family: Theme.mono; font.pixelSize: Theme.label + 1; font.letterSpacing: Theme.tracking; font.weight: Font.DemiBold }
            Jp { anchors.verticalCenter: parent.verticalCenter; text: "データ" }
        }
        Field {
            id: field
            anchors.right: parent.right
            anchors.verticalCenter: head.verticalCenter
            width: Math.min(340, stage.width - head.width - 20)
            height: 34
            text: root.query
            placeholder: "search shards"
            onEdited: root.query = text
            onAccepted: root.act(root.current, "copy", true)
            input.Keys.onPressed: e => {
                const k = e.key, ctrl = e.modifiers & Qt.ControlModifier, shift = e.modifiers & Qt.ShiftModifier;
                if (k === Qt.Key_Escape) { if (root.query !== "") root.query = ""; else ClipboardState.open = false; }
                else if (k === Qt.Key_Down || (k === Qt.Key_Tab && !shift)) root.step(1);
                else if (k === Qt.Key_Up || k === Qt.Key_Backtab) root.step(-1);
                else if (k === Qt.Key_PageDown) root.step(8);
                else if (k === Qt.Key_PageUp) root.step(-8);
                else if (ctrl && k === Qt.Key_P && root.current) root.act(root.current, root.pinned(root.current) ? "unpin" : "pin", false);
                else if (ctrl && shift && k === Qt.Key_D) {
                    if (root.clearArmed && root.current) { root.clearArmed = false; root.act(root.current, "remove_all", false); }
                    else { root.clearArmed = true; disarm.restart(); }
                }
                else if ((ctrl && k === Qt.Key_D) || (k === Qt.Key_Delete && root.query === "")) root.act(root.current, "remove", false);
                else return;
                e.accepted = true;
            }
        }

        // ---------------------------------------------------------------- the index
        ListView {
            id: list
            y: 50
            width: stage.narrow ? stage.width : Math.round(stage.width * 0.45)
            height: stage.height - y - 26
            clip: true
            spacing: 4
            boundsBehavior: Flickable.StopAtBounds
            model: root.filtered
            currentIndex: root.sel
            delegate: Item {
                id: row
                required property var modelData
                required property int index
                readonly property bool sel: index === root.sel
                width: list.width
                height: 48
                Chamfer {
                    anchors.fill: parent
                    cut: 10; corners: "tr bl"
                    fill: row.sel ? Theme.alpha(Theme.cyan, 0.14) : Theme.alpha(Theme.bgDark, 0.72)
                    stroke: row.sel ? Theme.cyan : Theme.alpha(Theme.line, 0.9)
                }
                Text {
                    x: 12; anchors.verticalCenter: parent.verticalCenter
                    text: root.pinned(row.modelData) ? "\u{f0403}" : root.addr(row.modelData)
                    color: root.pinned(row.modelData) ? Theme.yellow : row.sel ? Theme.cyan : Theme.dim
                    font.family: Theme.mono; font.pixelSize: Theme.label
                }
                Column {
                    x: 78; width: parent.width - x - 14
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        width: parent.width; elide: Text.ElideRight; maximumLineCount: 1
                        text: root.isImage(row.modelData) ? "▣  IMAGE SHARD" : (row.modelData.text ?? "").replace(/\s+/g, " ").trim()
                        color: row.sel ? Theme.bright : root.isImage(row.modelData) ? Theme.cyan : Theme.fg
                        font.family: Theme.sans; font.pixelSize: Theme.data
                    }
                    Label { text: root.ago(row.modelData.subtext); color: row.sel ? Theme.cyan : Theme.dim }
                }
                MouseArea {
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onPositionChanged: m => { const p = mapToGlobal(m.x, m.y); if (p.x !== root.pointer.x || p.y !== root.pointer.y) { root.pointer = p; root.sel = row.index; } }
                    onClicked: root.act(row.modelData, "copy", true)
                }
            }
            Label {
                anchors.centerIn: parent
                visible: root.loaded && root.filtered.length === 0
                text: root.query !== "" ? "NO SHARD MATCHES" : "NO SHARDS"
            }
        }

        // ---------------------------------------------------------------- decrypted
        Item {
            id: viewer
            visible: !stage.narrow
            x: list.width + 20
            y: list.y
            width: stage.width - x
            height: list.height

            Chamfer { anchors.fill: parent; cut: 18; corners: "tl br"; fill: Theme.alpha(Theme.bgDark, 0.92); stroke: Theme.alpha(Theme.cyan, 0.5) }
            Rectangle { width: parent.width; height: 34; color: Theme.alpha(Theme.cyan, 0.1) }
            Label { x: 18; y: 10; text: "DECRYPTED"; color: Theme.cyan; strong: true }
            Label {
                anchors.right: parent.right; anchors.rightMargin: 18; y: 10
                text: !root.current ? "--" : root.isImage(root.current) ? "IMAGE"
                    : (root.current.text ?? "").length + " CHARS // " + (root.current.text ?? "").split("\n").length + " LINES"
            }
            Flickable {
                id: flick
                x: 18; y: 48
                width: parent.width - 36
                height: parent.height - y - 18
                clip: true
                visible: root.current !== null && !root.isImage(root.current)
                contentHeight: body.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                Text {
                    id: body
                    width: flick.width
                    wrapMode: Text.Wrap
                    textFormat: Text.PlainText
                    text: (root.current?.text ?? "").slice(0, 6000)
                    color: Theme.fg
                    font.family: Theme.mono; font.pixelSize: Theme.data - 1
                    lineHeight: 1.15
                }
            }
            Image {
                x: 18; y: 48
                width: parent.width - 36
                height: parent.height - y - 18
                visible: root.current !== null && root.isImage(root.current)
                source: visible ? "file://" + root.current.preview : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                sourceSize.width: 1200
            }
        }

        Label {
            anchors.bottom: parent.bottom
            text: root.clearArmed ? "CTRL ⇧ D AGAIN WIPES EVERY UNPINNED SHARD"
                : "ENTER COPY   //   CTRL P PIN   //   CTRL D WIPE   //   CTRL ⇧ D WIPE ALL   //   ESC CLOSE"
            color: root.clearArmed ? Theme.red : Theme.dim
        }
    }
}
