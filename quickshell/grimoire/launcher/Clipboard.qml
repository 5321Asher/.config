import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import "../theme"
import "../widgets"

// The commonplace book: clipboard history (SUPER + V), in place of Walker's. Scholars copied the
// passages they meant to keep into a commonplace book; this one keeps what you copy. An open book on
// the desk: on the left page the entries, newest first (the pinned ones first of all, marked with a
// dab of wax), each its first line and when; on the right page the chosen entry written out in full,
// or a picture tipped in with photo corners. Same history as Walker: elephant's clipboard provider.
// Type to search, ↑ ↓ choose, Enter copies it back, Ctrl+P pins / unpins, Ctrl+D / Delete removes,
// Ctrl+Shift+D clears the unpinned ones (press twice), Esc closes.
//   qs ipc call clipboard toggle
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
    WlrLayershell.namespace: "grimoire-clipboard"
    WlrLayershell.keyboardFocus: ClipboardState.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: ClipboardState.open ? null : noInput
    Region { id: noInput }

    property real shown: ClipboardState.open ? 1 : 0
    Behavior on shown { NumberAnimation { duration: Theme.normal; easing.type: Theme.easing } }

    // ---------------------------------------------------------------- history
    property var items: []
    property bool loaded: false
    property string query: ""
    property int sel: 0
    property bool clearArmed: false

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
        if (n > 0) sel = (sel + d + n) % n;
    }
    function ago(stamp) {
        const t = Date.parse(stamp);
        if (isNaN(t)) return stamp ?? "";
        const s = Math.max(0, (Date.now() - t) / 1000);
        if (s < 60) return "just now";
        if (s < 3600) return `${Math.floor(s / 60)} min ago`;
        if (s < 86400) return `${Math.floor(s / 3600)} h ago`;
        return `${Math.floor(s / 86400)} d ago`;
    }
    function firstLine(t) { return (t ?? "").trim().split("\n")[0]; }

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
                input.text = "";
                root.sel = 0;
                root.clearArmed = false;
                root.loaded = false;
                root.refresh();
                input.forceActiveFocus();
            }
        }
    }
    Timer { id: disarm; interval: 2500; onTriggered: root.clearArmed = false }

    // ---------------------------------------------------------------- the desk
    Rectangle { anchors.fill: parent; color: Theme.alpha(Theme.mix(Theme.veil, "#000000", 0.3), 0.55 * root.shown) }
    MouseArea { anchors.fill: parent; onClicked: ClipboardState.open = false }

    readonly property real pageW: Math.min(470, (width - 100) / 2)
    readonly property real pageH: Math.min(640, height - 170)

    // ---------------------------------------------------------------- the book
    Item {
        id: book
        width: root.pageW * 2 + 28
        height: root.pageH + 26
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -10 + (1 - root.shown) * 30
        opacity: root.shown
        scale: 0.97 + 0.03 * root.shown
        MouseArea { anchors.fill: parent }

        readonly property vector3d lamp: Qt.vector3d(book.width * 0.2, -book.height * 0.35, 1100)

        Rectangle {
            x: 10; y: 18; width: parent.width; height: parent.height; radius: 8
            color: Qt.alpha("#000000", 0.55)
            layer.enabled: true
            layer.effect: MultiEffect { blurEnabled: true; blur: 1; blurMax: 48 }
        }
        Cover {
            anchors.fill: parent
            radius: 8; bevel: 8; wear: 0.5; seed: 0.71
            light: book.lamp; lightPower: 1.4; ambient: 0.85
        }
        PageBlock { x: 16; y: 10 + root.pageH - 1; width: root.pageW * 2 - 4; height: 6; shadeDepth: 0.6 }

        // ------------------------------------------------------------ left: the entries
        Parchment {
            id: left
            x: 14; y: 10
            width: root.pageW; height: root.pageH
            radius: 3; gutter: 1; seed: 0.33

            Column {
                id: head
                x: 34; y: 22
                width: parent.width - 34 - 44
                spacing: 2
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Commonplace"
                    color: Theme.ink
                    font.family: Theme.blackletter
                    font.pixelSize: 36
                }
                Body {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "things copied, and kept"
                    italic: true
                    color: Theme.inkDim
                    font.pixelSize: 14
                }
                Item { width: 1; height: 10 }
                // the line to search with
                Item {
                    width: parent.width
                    height: 30
                    Text {
                        id: quill
                        anchors.verticalCenter: parent.verticalCenter
                        text: "✦"
                        color: Theme.rubric
                        font.family: Theme.symbols
                        font.pixelSize: 12
                    }
                    TextInput {
                        id: input
                        anchors.left: quill.right
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.ink
                        selectionColor: Theme.alpha(Theme.rubric, 0.3)
                        font.family: Theme.body
                        font.italic: true
                        font.pixelSize: 18
                        focus: true
                        cursorDelegate: Rectangle { width: 1.5; color: Theme.rubric }
                        onTextEdited: root.query = text
                        Keys.onPressed: event => {
                            const k = event.key;
                            const ctrl = event.modifiers & Qt.ControlModifier;
                            const shift = event.modifiers & Qt.ShiftModifier;
                            if (k === Qt.Key_Escape) ClipboardState.open = false;
                            else if (k === Qt.Key_Return || k === Qt.Key_Enter) root.act(root.current, "copy", true);
                            else if (k === Qt.Key_Down || (k === Qt.Key_Tab && !shift)) root.step(1);
                            else if (k === Qt.Key_Up || k === Qt.Key_Backtab) root.step(-1);
                            else if (k === Qt.Key_PageDown) root.step(8);
                            else if (k === Qt.Key_PageUp) root.step(-8);
                            else if (ctrl && k === Qt.Key_P && root.current) root.act(root.current, root.pinned(root.current) ? "unpin" : "pin", false);
                            else if (ctrl && shift && k === Qt.Key_D) {
                                if (root.clearArmed && root.current) { root.clearArmed = false; root.act(root.current, "remove_all", false); }
                                else { root.clearArmed = true; disarm.restart(); }
                            } else if ((ctrl && k === Qt.Key_D) || (k === Qt.Key_Delete && root.query === "")) root.act(root.current, "remove", false);
                            else return;
                            event.accepted = true;
                        }
                        Body {
                            visible: input.text === ""
                            anchors.verticalCenter: parent.verticalCenter
                            text: "search what's written…"
                            italic: true
                            color: Theme.alpha(Theme.inkDim, 0.7)
                            font.pixelSize: 18
                        }
                    }
                }
                GoldRule { width: parent.width; color: Theme.alpha(Theme.inkDim, 0.55); ornament: "" }
            }

            ListView {
                id: list
                x: 22
                y: head.y + head.height + 8
                width: parent.width - 22 - 40
                height: parent.height - y - 30
                clip: true
                model: root.filtered
                currentIndex: root.sel
                highlightMoveDuration: Theme.fast
                highlightFollowsCurrentItem: true
                boundsBehavior: Flickable.StopAtBounds
                highlight: Item {
                    Rectangle { anchors.fill: parent; radius: 3; color: Theme.alpha(Theme.rubric, 0.09) }
                    Rectangle { width: 2; height: parent.height - 12; anchors.verticalCenter: parent.verticalCenter; color: Theme.rubric }
                }
                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    width: list.width
                    height: 46
                    Body {
                        x: 10
                        width: 38
                        anchors.verticalCenter: parent.verticalCenter
                        text: Theme.roman(row.index + 1).toLowerCase() + "."
                        italic: true
                        color: Theme.rubric
                        font.pixelSize: 13
                    }
                    Column {
                        x: 50
                        width: parent.width - x - 26
                        anchors.verticalCenter: parent.verticalCenter
                        Body {
                            width: parent.width
                            elide: Text.ElideRight
                            text: root.isImage(row.modelData) ? "a picture, tipped in" : root.firstLine(row.modelData.text)
                            italic: root.isImage(row.modelData)
                            color: Theme.ink
                            font.pixelSize: 16
                        }
                        Body {
                            text: root.ago(row.modelData.subtext)
                            italic: true
                            color: Theme.inkDim
                            font.pixelSize: 12
                        }
                    }
                    // kept: a dab of wax
                    Rectangle {
                        visible: root.pinned(row.modelData)
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 11; height: 11; radius: 5.5
                        color: Theme.wax
                        border.width: 1
                        border.color: Qt.darker(Theme.wax, 1.4)
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { root.sel = row.index; root.act(row.modelData, "copy", true); }
                        hoverEnabled: true
                        onPositionChanged: root.sel = row.index
                    }
                }
            }
            Body {
                visible: root.loaded && root.filtered.length === 0
                anchors.horizontalCenter: list.horizontalCenter
                y: list.y + 30
                text: root.query ? "nothing written matches" : "nothing copied yet"
                italic: true
                color: Theme.inkDim
            }
        }

        // ------------------------------------------------------------ right: the entry, in full
        Parchment {
            id: right
            x: 14 + root.pageW; y: 10
            width: root.pageW; height: root.pageH
            radius: 3; gutter: -1; seed: 0.88

            Column {
                id: entryHead
                x: 44; y: 30
                width: parent.width - 44 - 34
                spacing: 4
                Caps {
                    text: root.current ? "entry " + Theme.roman(root.sel + 1) + (root.pinned(root.current) ? " · kept" : "") : ""
                    color: Theme.rubric
                    font.pixelSize: 12
                    font.letterSpacing: 3
                }
                Body {
                    text: root.current ? root.ago(root.current.subtext) : ""
                    italic: true
                    color: Theme.inkDim
                    font.pixelSize: 13
                }
                GoldRule { width: parent.width; color: Theme.alpha(Theme.inkDim, 0.55); ornament: "❦" }
            }
            Flickable {
                id: page
                x: 44
                y: entryHead.y + entryHead.height + 14
                width: parent.width - 44 - 34
                height: parent.height - y - 34
                clip: true
                contentHeight: entryText.visible ? entryText.implicitHeight : height
                boundsBehavior: Flickable.StopAtBounds
                visible: root.current !== null
                Text {
                    id: entryText
                    visible: root.current !== null && !root.isImage(root.current)
                    width: page.width
                    wrapMode: Text.WrapAnywhere
                    textFormat: Text.PlainText
                    text: root.current && !root.isImage(root.current) ? (root.current.text ?? "").slice(0, 6000) : ""
                    // code and paths in a typewriter's hand, prose in the book's
                    readonly property bool codeish: /[{}();=<>\/\\$]|^\s{2,}/m.test(text)
                    font.family: codeish ? Theme.mono : Theme.body
                    font.pixelSize: codeish ? 14 : 17
                    lineHeight: 1.15
                    color: Theme.ink
                }
                // a picture, tipped in with photo corners
                Item {
                    visible: root.current !== null && root.isImage(root.current)
                    width: page.width
                    height: page.height
                    Image {
                        id: plate
                        anchors.centerIn: parent
                        width: Math.min(parent.width - 20, implicitWidth)
                        height: Math.min(parent.height - 20, implicitHeight)
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        source: parent.visible ? "file://" + root.current.preview : ""
                        readonly property real pw: paintedWidth
                        readonly property real ph: paintedHeight
                        Rectangle {
                            anchors.centerIn: parent
                            width: plate.pw + 2; height: plate.ph + 2
                            color: "transparent"
                            border.width: 1
                            border.color: Theme.alpha(Theme.ink, 0.35)
                            // photo corners: little dark triangles over each corner
                            Repeater {
                                model: [[0, 0], [1, 0], [0, 1], [1, 1]]
                                Shape {
                                    required property var modelData
                                    width: 18; height: 18
                                    x: modelData[0] ? parent.width - 14 : -4
                                    y: modelData[1] ? parent.height - 14 : -4
                                    rotation: modelData[0] ? (modelData[1] ? 180 : 90) : (modelData[1] ? 270 : 0)
                                    preferredRendererType: Shape.CurveRenderer
                                    ShapePath {
                                        strokeColor: "transparent"
                                        fillColor: Theme.mix(Theme.ink, Theme.leatherDark, 0.5)
                                        PathSvg { path: "M 0 0 L 18 0 L 0 18 Z" }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // the keys, tooled along the foot of the cover
        Caps {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.bottom
            anchors.topMargin: 16
            text: root.clearArmed ? "ctrl ⇧ d again clears every entry not kept"
                : "enter  copy   ·   ctrl p  keep   ·   ctrl d  strike out   ·   ctrl ⇧ d  clear   ·   esc  close"
            color: root.clearArmed ? Theme.danger : Theme.alpha(Theme.gold, 0.55)
            font.pixelSize: 10
            font.letterSpacing: 2
        }
    }
}
