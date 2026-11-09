import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import "../theme"
import "../widgets"

// Clipboard history (SUPER + V), after the reference's Clip: a search pill with filter chips
// (all / text / links / images), the entries on the left (a round glyph by kind: text, code, link,
// colour, image; the selected one the white pill, a dot-matrix number on the right), the picked one
// on the right (the text, the picture, the colour). Same history as Walker: elephant's clipboard.
// ↑↓ pick, Enter copies it back, Tab filters, Ctrl+P pins, Delete removes, Esc closes.
PanelWindow {
    id: root

    Binding on screen {
        when: !root.visible
        value: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        restoreMode: Binding.RestoreNone
    }
    readonly property real s: Theme.scaleFor(screen)

    property real t: ClipboardState.open ? 1 : 0
    Behavior on t { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
    visible: t > 0

    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: ClipboardState.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "glyph-clip"

    // ---------------------------------------------------------------- history
    property var items: []
    property int mode: 0
    readonly property var modes: ["all", "text", "links", "images"]
    property int sel: 0

    function isImage(it) { return it.preview_type === "file"; }
    function src(it) { const p = it?.preview ?? ""; return p.startsWith("file:") ? p : "file://" + p; }
    function pinned(it) { return (it.actions ?? []).includes("unpin"); }
    function kind(it) {
        if (isImage(it)) return "image";
        const tx = (it.text ?? "").trim();
        if (/^#[0-9a-f]{6}([0-9a-f]{2})?$/i.test(tx) || /^rgba?\(/i.test(tx)) return "color";
        if (/^(https?|ftp|file):\/\/\S+$/i.test(tx)) return "link";
        if (/[{};]|^\s*(sudo |git |cd |ls |cat |yay |pacman |hyprctl |qs |npm |python)/.test(tx) || tx.includes("\n  ")) return "code";
        return "text";
    }
    readonly property var glyphs: ({ text: "\u{F0F4A}", code: "\u{F0169}", link: "\u{F0337}", image: "\u{F02E9}", color: "\u{F03D8}" })
    readonly property var filtered: {
        const q = input.text.trim().toLowerCase();
        let list = items.filter(it => {
            const k = kind(it);
            if (mode === 1 && (k === "image" || k === "link")) return false;
            if (mode === 2 && k !== "link") return false;
            if (mode === 3 && k !== "image") return false;
            return q === "" || (!isImage(it) && (it.text ?? "").toLowerCase().includes(q));
        });
        return list.filter(it => pinned(it)).concat(list.filter(it => !pinned(it)));
    }
    readonly property var cur: filtered[Math.min(sel, filtered.length - 1)] ?? null
    onFilteredChanged: sel = Math.max(0, Math.min(sel, filtered.length - 1))

    function refresh() { query.running = false; query.running = true; }
    function act(it, action, close) {
        if (!it) return;
        if (close) ClipboardState.open = false;
        run.command = ["elephant", "activate", `clipboard;${it.identifier};${action};;`];
        run.closing = close;
        run.running = true;
    }
    function step(d) {
        const n = filtered.length;
        if (n > 0) sel = Math.max(0, Math.min(n - 1, sel + d));
    }
    function ago(stamp) {
        const t = Date.parse(stamp);
        if (isNaN(t)) return "";
        const s = Math.max(0, (Date.now() - t) / 1000);
        return s < 60 ? "now" : s < 3600 ? Math.floor(s / 60) + " min" : s < 86400 ? Math.floor(s / 3600) + " h" : Math.floor(s / 86400) + " d";
    }

    Process {
        id: query
        command: ["elephant", "query", "--json", "clipboard;;500;false"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    if (!line.trim()) continue;
                    try { out.push(JSON.parse(line).item); } catch (e) {}
                }
                root.items = out;
            }
        }
    }
    Process {
        id: run
        property bool closing: false
        onExited: if (!closing) root.refresh()
    }
    Connections {
        target: ClipboardState
        function onOpenChanged() {
            if (!ClipboardState.open) return;
            input.text = "";
            root.mode = 0;
            root.sel = 0;
            root.refresh();
            input.forceActiveFocus();
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: root.t
        MouseArea { anchors.fill: parent; onClicked: ClipboardState.open = false }
    }

    Stage {
        id: stage
        s: root.s
        readonly property bool narrow: width < 1300

        Rectangle {
            id: panel
            width: Math.min(1160, stage.width - 120)
            height: Math.min(790, stage.height - 220)
            x: (stage.width - width) / 2
            y: (stage.height - height) / 2 - 40 + 24 * (1 - root.t)
            opacity: root.t
            radius: 44
            color: Theme.s1
            border { width: 1; color: Theme.s2 }
            MouseArea { anchors.fill: parent }

            // search
            Rectangle {
                id: search
                x: 34
                y: 30
                width: parent.width - 68
                height: 66
                radius: 33
                color: Theme.s2
                Icon { id: lens; x: 24; anchors.verticalCenter: parent.verticalCenter; text: "\u{F0349}"; color: Theme.grey; font.pixelSize: 22 }
                TextInput {
                    id: input
                    anchors { left: lens.right; leftMargin: 16; right: chips.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    font { family: Theme.ui; pixelSize: 22 }
                    color: Theme.fg
                    selectionColor: Theme.s3
                    clip: true
                    onTextChanged: root.sel = 0
                    cursorDelegate: Rectangle {
                        width: 2
                        color: Theme.red
                        Timer { running: input.activeFocus; interval: 500; repeat: true; onTriggered: parent.opacity = 1 - parent.opacity }
                    }
                    Text { visible: !input.text; x: 6; text: "Search clipboard"; font: input.font; color: Theme.mute }
                    Keys.onPressed: e => {
                        const ctrl = e.modifiers & Qt.ControlModifier;
                        if (e.key === Qt.Key_Escape) ClipboardState.open = false;
                        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.act(root.cur, "copy", true);
                        else if (e.key === Qt.Key_Down) root.step(1);
                        else if (e.key === Qt.Key_Up) root.step(-1);
                        else if (e.key === Qt.Key_Tab) root.mode = (root.mode + 1) % 4;
                        else if (e.key === Qt.Key_Backtab) root.mode = (root.mode + 3) % 4;
                        else if (ctrl && e.key === Qt.Key_P) root.act(root.cur, root.cur && root.pinned(root.cur) ? "unpin" : "pin", false);
                        else if (e.key === Qt.Key_Delete || (ctrl && e.key === Qt.Key_D)) root.act(root.cur, "remove", false);
                        else return;
                        e.accepted = true;
                    }
                }
                Row {
                    id: chips
                    anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    spacing: 6
                    Repeater {
                        model: root.modes
                        Rectangle {
                            required property string modelData
                            required property int index
                            width: chip.width + 32
                            height: chip.height + 20
                            radius: height / 2
                            color: root.mode === index ? Theme.fg : "transparent"
                            Lb { id: chip; anchors.centerIn: parent; text: parent.modelData; px: 11; color: root.mode === parent.index ? Theme.ink : Theme.grey }
                            TapHandler { onTapped: { root.mode = parent.index; input.forceActiveFocus(); } }
                        }
                    }
                }
            }

            // the list
            Row {
                id: head
                x: 40
                y: search.y + search.height + 26
                spacing: 14
                Num { text: root.filtered.length; font.pixelSize: 34; anchors.baseline: hl.baseline }
                Lb { id: hl; text: "entries" }
            }
            ListView {
                id: list
                x: 34
                y: head.y + 50
                width: stage.narrow ? parent.width - 68 : 520
                height: parent.height - y - 34
                clip: true
                model: root.filtered.length
                currentIndex: root.sel
                spacing: 6
                highlightMoveDuration: Theme.fast
                boundsBehavior: Flickable.StopAtBounds
                delegate: Item {
                    id: row
                    required property int index
                    readonly property var it: root.filtered[index] ?? ({})
                    readonly property string k: root.kind(it)
                    readonly property bool on: index === root.sel
                    width: list.width
                    height: 66
                    Rectangle {
                        anchors.fill: parent
                        radius: 33
                        color: row.on ? Theme.fg : hov.hovered ? Theme.s2 : "transparent"
                    }
                    Rectangle {
                        id: disc
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 50
                        height: 50
                        radius: 25
                        color: row.k === "color" ? row.it.text.trim() : row.on ? Theme.ink : Theme.s2
                        clip: true
                        Icon { visible: row.k !== "color" && !thumb.visible; anchors.centerIn: parent; text: root.glyphs[row.k]; font.pixelSize: 20; color: row.on ? Theme.fg : Theme.fg }
                        Image {
                            id: thumb
                            anchors.fill: parent
                            visible: row.k === "image" && status === Image.Ready
                            source: row.k === "image" ? root.src(row.it) : ""
                            sourceSize: Qt.size(100, 100)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            layer.enabled: true
                            layer.effect: Dm { step: 3; circle: true }
                        }
                    }
                    Column {
                        anchors { left: disc.right; leftMargin: 16; right: num.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        spacing: 3
                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            text: row.k === "image" ? "image" : (row.it.text ?? "").replace(/\s+/g, " ")
                            font { family: Theme.ui; pixelSize: 16 }
                            color: row.on ? Theme.ink : Theme.fg
                        }
                        Lb {
                            text: [row.k, root.pinned(row.it) ? "pinned" : "", root.ago(row.it.subtext)].filter(Boolean).join(" · ")
                            px: 10
                            color: row.on ? Theme.ink : Theme.grey
                            opacity: row.on ? 0.7 : 1
                        }
                    }
                    Num {
                        id: num
                        anchors { right: parent.right; rightMargin: 22; verticalCenter: parent.verticalCenter }
                        text: String(row.index + 1).padStart(2, "0")
                        font.pixelSize: 28
                        color: row.on ? Theme.ink : Theme.s3
                    }
                    HoverHandler { id: hov }
                    TapHandler { onTapped: { if (row.on) root.act(row.it, "copy", true); else root.sel = row.index; } }
                }
            }

            // the preview
            Rectangle {
                visible: !stage.narrow
                x: list.x + list.width + 30
                y: head.y
                width: parent.width - x - 34
                height: parent.height - y - 34
                radius: 36
                color: Theme.s2
                readonly property string k: root.cur ? root.kind(root.cur) : ""

                Lb {
                    x: 30
                    y: 30
                    text: root.cur ? `${parent.k} · ${root.sel + 1} of ${root.filtered.length}` : "empty"
                }
                Text {
                    visible: parent.k !== "image" && parent.k !== "color"
                    x: 30
                    y: 74
                    width: parent.width - 60
                    height: parent.height - 74 - 110
                    clip: true
                    wrapMode: Text.WrapAnywhere
                    elide: Text.ElideRight
                    text: root.cur?.text ?? ""
                    textFormat: Text.PlainText
                    font { family: parent.k === "code" ? Theme.mono : Theme.ui; pixelSize: parent.k === "code" ? 15 : 19 }
                    color: Theme.fg
                    lineHeight: 1.2
                }
                Image {
                    id: big
                    visible: parent.k === "image"
                    x: 30
                    y: 74
                    width: parent.width - 60
                    height: parent.height - 74 - 110
                    source: parent.k === "image" ? root.src(root.cur) : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    sourceSize: Qt.size(width * 2, height * 2)
                }
                Rectangle {
                    visible: parent.k === "color"
                    anchors.centerIn: parent
                    width: 220
                    height: 220
                    radius: 110
                    color: parent.k === "color" ? root.cur.text.trim() : "transparent"
                }
                Row {
                    x: 30
                    anchors { bottom: parent.bottom; bottomMargin: 30 }
                    spacing: 16
                    Num {
                        anchors.baseline: meta.baseline
                        font.pixelSize: 40
                        text: parent.parent.k === "image" ? `${big.implicitWidth}×${big.implicitHeight}` : String((root.cur?.text ?? "").length)
                    }
                    Lb {
                        id: meta
                        text: parent.parent.k === "image" ? "png" : "characters"
                    }
                }
            }
        }

        Row {
            anchors { horizontalCenter: parent.horizontalCenter; top: panel.bottom; topMargin: 34 }
            opacity: root.t
            spacing: 34
            Lb { text: "↑↓ select" }
            Lb { text: "↵ copy" }
            Lb { text: "tab filter" }
            Lb { text: "^p pin" }
            Lb { text: "del delete" }
            Lb { text: "esc close" }
        }
    }
}
