import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import "../theme"

// The plate archive: clipboard history (SUPER + V), in place of Walker's. Every copied thing is a
// photographic plate filed in a ledger, newest first; the selected one is shown on the viewer
// beside it (text, or the picture itself). Same history as Walker: elephant's clipboard provider,
// read with `elephant query` and acted on with `elephant activate`.
// Type to search, ↑ ↓ choose, Enter copies it back, Ctrl+P pins / unpins, Ctrl+D / Delete removes,
// Ctrl+Shift+D clears the unpinned ones (press twice), Esc closes. Opened with: qs ipc call clipboard toggle
PanelWindow {
    id: root

    // Follows the focused monitor only while hidden: moving a shown window rebuilds its surface
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
    WlrLayershell.namespace: "observatory-clipboard"
    WlrLayershell.keyboardFocus: ClipboardState.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property real shown: ClipboardState.open ? 1 : 0
    Behavior on shown { NumberAnimation { duration: Theme.slow; easing.type: Theme.easing } }

    // ---------------------------------------------------------------- history
    property var items: []          // elephant clipboard items, newest first
    property bool loaded: false
    property string query: ""
    property int sel: 0
    // Where the pointer last really moved (screen coords): rows that scroll under a still cursor
    // mustn't take the selection, or stepping up past the top of the view jumps back down
    property point pointer: Qt.point(-1, -1)
    property bool clearArmed: false

    function isImage(it) { return it.preview_type === "file"; }
    function pinned(it) { return (it.actions ?? []).includes("unpin"); }

    readonly property var filtered: {
        const q = query.trim().toLowerCase();
        const list = q === "" ? items : items.filter(it => !isImage(it) && (it.text ?? "").toLowerCase().includes(q));
        // pinned plates first, each group newest first
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
        if (n > 0) sel = (sel + d + n) % n;
    }

    // "Mon, 28 Sep 2026 21:29:40 -0400" -> "4 min ago"
    function ago(stamp) {
        const t = Date.parse(stamp);
        if (isNaN(t)) return stamp ?? "";
        const s = Math.max(0, (Date.now() - t) / 1000);
        if (s < 60) return "just now";
        if (s < 3600) return `${Math.floor(s / 60)} min ago`;
        if (s < 86400) return `${Math.floor(s / 3600)} h ago`;
        return `${Math.floor(s / 86400)} d ago`;
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
                root.query = "";
                root.sel = 0;
                root.clearArmed = false;
                root.loaded = false;
                root.refresh();
                input.forceActiveFocus();
            }
        }
    }
    Timer {
        id: disarm
        interval: 2500
        onTriggered: root.clearArmed = false
    }

    // ---------------------------------------------------------------- backdrop
    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.bgDark, Theme.chartDim * root.shown)
    }
    MouseArea {
        anchors.fill: parent
        onClicked: ClipboardState.open = false
    }

    // ---------------------------------------------------------------- the archive
    Item {
        id: archive
        anchors.centerIn: parent
        width: Math.min(Theme.clipWidth, parent.width - 48)
        height: Math.min(Theme.clipHeight, parent.height - 96)
        opacity: root.shown
        scale: 0.96 + 0.04 * root.shown

        Plate { anchors.fill: parent }
        MouseArea { anchors.fill: parent }

        readonly property int pad: Theme.transmissionPad + 6
        readonly property bool narrow: width < 720

        // Title and search
        Row {
            id: head
            x: archive.pad
            y: archive.pad
            spacing: 10
            Rectangle {
                width: 8; height: 8; rotation: 45
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.phosphor
            }
            Text {
                text: "plate archive"
                color: Theme.brass
                font.family: Theme.fontLabel
                font.pixelSize: Theme.labelSizeLarge
                font.capitalization: Font.SmallCaps
                font.letterSpacing: Theme.labelSpacing * 1.5
                font.weight: Font.DemiBold
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.loaded ? `${root.items.length} plates` : "…"
                color: Theme.dim
                font.family: Theme.fontData
                font.pixelSize: Theme.dataSizeSmall
            }
        }
        Item {
            id: search
            anchors.right: parent.right
            anchors.rightMargin: archive.pad
            anchors.verticalCenter: head.verticalCenter
            width: Math.min(300, archive.width - head.width - 3 * archive.pad)
            height: 30
            Rectangle {
                anchors.fill: parent
                radius: 4
                color: Theme.alpha(Theme.bg, 0.9)
                border.width: 1.2
                border.color: root.query !== "" ? Theme.brassBright : Theme.border
            }
            Text {
                x: 10
                anchors.verticalCenter: parent.verticalCenter
                visible: input.text === ""
                text: "search the archive"
                color: Theme.dim
                font.family: Theme.fontData
                font.pixelSize: Theme.dataSizeSmall + 1
            }
            TextInput {
                id: input
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                color: Theme.phosphor
                selectionColor: Theme.brassMuted
                font.family: Theme.fontData
                font.pixelSize: Theme.dataSize
                focus: ClipboardState.open
                text: root.query
                onTextEdited: root.query = text
                Keys.onPressed: event => {
                    const k = event.key, ctrl = event.modifiers & Qt.ControlModifier, shift = event.modifiers & Qt.ShiftModifier;
                    if (k === Qt.Key_Escape) {
                        if (root.query !== "") root.query = "";
                        else ClipboardState.open = false;
                    }
                    else if (k === Qt.Key_Return || k === Qt.Key_Enter) root.act(root.current, "copy", true);
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
                    event.accepted = true;
                }
            }
        }
        Rectangle {
            id: rule
            x: archive.pad
            y: head.y + 34
            width: archive.width - 2 * archive.pad
            height: 1
            color: Theme.alpha(Theme.brass, 0.3)
        }

        // ---------------------------------------------------------------- the ledger
        Item {
            id: ledgerBox
            x: archive.pad
            y: rule.y + 10
            width: archive.narrow ? rule.width : Math.round(rule.width * 0.46)
            height: foot.y - y - 10

            ListView {
                id: ledger
                anchors.fill: parent
                clip: true
                model: root.filtered
                currentIndex: root.sel
                highlightMoveDuration: Theme.fast
                highlight: Rectangle {
                    width: ledger.width
                    color: Theme.alpha(Theme.brassMuted, 0.6)
                    Rectangle { width: 2; height: parent.height; color: Theme.brassBright }
                }
                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool active: index === root.sel
                    width: ledger.width
                    height: Theme.clipRow

                    // plate number
                    Text {
                        id: num
                        x: 10
                        width: 30
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.pinned(row.modelData) ? "\u{f0403}" : String(row.index + 1).padStart(2, "0")
                        color: root.pinned(row.modelData) ? Theme.brassBright : Theme.alpha(Theme.dim, 0.9)
                        font.family: Theme.fontData
                        font.pixelSize: Theme.dataSizeSmall + 1
                    }
                    Column {
                        anchors.left: num.right
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1
                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            text: root.isImage(row.modelData) ? "▣  image plate"
                                : (row.modelData.text ?? "").replace(/\s+/g, " ").trim()
                            color: row.active ? Theme.starlight : root.isImage(row.modelData) ? Theme.phosphor : Theme.fg
                            font.family: Theme.fontData
                            font.pixelSize: Theme.dataSize
                        }
                        Text {
                            text: root.ago(row.modelData.subtext)
                            color: Theme.dim
                            font.family: Theme.fontData
                            font.pixelSize: Theme.dataSizeSmall
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: mouse => { const p = mapToGlobal(mouse.x, mouse.y); if (p.x !== root.pointer.x || p.y !== root.pointer.y) { root.pointer = p; root.sel = row.index; } }
                        onClicked: root.act(row.modelData, "copy", true)
                    }
                }
            }
            Text {
                anchors.centerIn: parent
                visible: root.loaded && root.filtered.length === 0
                text: root.query !== "" ? "no plate matches" : "the archive is empty"
                color: Theme.dim
                font.family: Theme.fontLabel
                font.pixelSize: Theme.labelSize
                font.capitalization: Font.SmallCaps
                font.letterSpacing: Theme.labelSpacing
            }
        }

        // ---------------------------------------------------------------- the viewer
        Item {
            id: viewer
            visible: !archive.narrow
            anchors.left: ledgerBox.right
            anchors.leftMargin: 16
            anchors.right: rule.right
            y: ledgerBox.y
            height: ledgerBox.height

            // an eyepiece frame: engraved border with corner ticks
            Rectangle {
                anchors.fill: parent
                color: Theme.alpha(Theme.bg, 0.7)
                border.width: 1
                border.color: Theme.alpha(Theme.brass, 0.45)
            }
            Repeater {
                model: 4
                Item {
                    required property int index
                    x: index % 2 ? viewer.width - 14 : 0
                    y: index > 1 ? viewer.height - 14 : 0
                    width: 14; height: 14
                    Rectangle { x: index % 2 ? 13 : 0; width: 1; height: 14; color: Theme.brass }
                    Rectangle { y: index > 1 ? 13 : 0; width: 14; height: 1; color: Theme.brass }
                }
            }

            Flickable {
                id: textView
                anchors.fill: parent
                anchors.margins: 16
                visible: root.current !== null && !root.isImage(root.current)
                clip: true
                contentHeight: body.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                Text {
                    id: body
                    width: textView.width
                    wrapMode: Text.Wrap
                    textFormat: Text.PlainText
                    text: (root.current?.text ?? "").slice(0, 6000)
                    color: Theme.fg
                    font.family: Theme.fontData
                    font.pixelSize: Theme.dataSize
                    lineHeight: 1.15
                }
            }
            Image {
                anchors.fill: parent
                anchors.margins: 16
                visible: root.current !== null && root.isImage(root.current)
                source: visible ? "file://" + root.current.preview : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                sourceSize.width: 1200
            }
            Text {
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.margins: 8
                visible: root.current !== null && !root.isImage(root.current)
                text: {
                    const t = root.current?.text ?? "";
                    const lines = t.split("\n").length;
                    return `${t.length} chars · ${lines} ${lines === 1 ? "line" : "lines"}`;
                }
                color: Theme.alpha(Theme.dim, 0.9)
                font.family: Theme.fontData
                font.pixelSize: Theme.dataSizeSmall
            }
        }

        // ---------------------------------------------------------------- keys
        Text {
            id: foot
            anchors.right: parent.right
            anchors.rightMargin: archive.pad
            anchors.bottom: parent.bottom
            anchors.bottomMargin: archive.pad - 2
            text: root.clearArmed ? "ctrl ⇧ d again to clear every unpinned plate"
                : "enter  copy   ·   ctrl p  pin   ·   ctrl d  remove   ·   ctrl ⇧ d  clear   ·   esc  close"
            color: root.clearArmed ? Theme.signal : Theme.alpha(Theme.dim, 0.9)
            font.family: Theme.fontData
            font.pixelSize: Theme.dataSizeSmall
        }
    }
}
