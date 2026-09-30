import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../theme"
import "../widgets"

// BREACH PROTOCOL 侵入: Netrunner's root menu (SUPER + Space), drawn like a breach from the game.
// Left, the CODE MATRIX: a grid of hex bytes. Right, the BUFFER and the daemons you can upload:
// the shared menus' entries (HubState), each with its own byte sequence, which is a real path
// through the matrix (row 0, down a column, along a row…) traced as you move the selection.
// Enter uploads the daemon (the bytes run into the buffer) and runs it; a submenu is a deeper
// subnet. ↑ ↓ / Tab pick, type to filter, → / Enter go in, ← / Esc / Backspace come back out.
// qs ipc call hub toggle
PanelWindow {
    id: root

    Binding on screen {
        when: !root.visible
        value: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        restoreMode: Binding.RestoreNone
    }
    visible: HubState.open || shown > 0.01

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "netrunner-breach"
    WlrLayershell.keyboardFocus: HubState.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property real shown: HubState.open ? 1 : 0
    Behavior on shown { NumberAnimation { duration: Theme.normal; easing.type: Theme.easing } }

    // ---------------------------------------------------------------- the daemons
    property string query: ""
    property int sel: 0
    property point pointer: Qt.point(-1, -1)    // last real pointer move (rows scrolling under a still cursor don't select)
    readonly property var items: HubState.level?.items ?? []
    readonly property var shownItems: {
        const q = query.trim().toLowerCase();
        return q === "" ? items : items.filter(e => (e.text + " " + e.sub).toLowerCase().includes(q));
    }
    readonly property var current: shownItems[Math.min(sel, shownItems.length - 1)] ?? null
    onQueryChanged: sel = 0
    onItemsChanged: sel = 0

    function step(d) {
        const n = shownItems.length;
        if (n > 0 && !uploading) sel = (sel + d + n) % n;
    }
    function enter() {
        const e = current;
        if (!e || uploading) return;
        if (e.open) { query = ""; HubState.push(e.text, e.open); timer.restart(); return; }
        upload.target = e;
        uploading = true;
        uploadAnim.restart();
    }
    function back() {
        if (uploading) return;
        if (query !== "") { query = ""; return; }
        HubState.back();
        timer.restart();
    }

    // ---------------------------------------------------------------- the matrix
    readonly property var bytes: ["1C", "55", "BD", "E9", "7A", "FF"]
    readonly property int size: 7
    readonly property var matrix: {
        let s = HubState.seed * 2654435761 % 4294967296;
        const out = [];
        for (let i = 0; i < size * size; i++) {
            s = (s * 1103515245 + 12345) % 2147483648;
            out.push(bytes[Math.floor(s / 65536) % bytes.length]);
        }
        return out;
    }
    function hash(t) {
        let h = 7;
        for (const c of t) h = (h * 31 + c.charCodeAt(0)) % 1000003;
        return h;
    }
    // The entry's path through the matrix: [{r, c}], alternating column / row moves from row 0
    function pathFor(e) {
        if (!e) return [];
        let h = hash(e.text + HubState.seed);
        const len = 2 + h % 3;
        const cells = [];
        let r = 0, c = (h >> 2) % size;
        cells.push({ r: r, c: c });
        for (let i = 1; i < len; i++) {
            h = (h * 131 + 17) % 1000003;
            if (i % 2 === 1) { let nr = (h >> 3) % size; if (nr === r) nr = (nr + 1 + h % (size - 1)) % size; r = nr; }
            else { let nc = (h >> 3) % size; if (nc === c) nc = (nc + 1 + h % (size - 1)) % size; c = nc; }
            if (cells.some(x => x.r === r && x.c === c)) { r = (r + 1) % size; }
            cells.push({ r: r, c: c });
        }
        return cells;
    }
    function seqFor(e) { return pathFor(e).map(p => matrix[p.r * size + p.c]); }
    readonly property var path: pathFor(current)
    readonly property var seq: path.map(p => matrix[p.r * size + p.c])

    // ---------------------------------------------------------------- upload
    property bool uploading: false
    property real uploaded: 0               // 0..1 while uploading
    QtObject { id: upload; property var target: null }
    SequentialAnimation {
        id: uploadAnim
        NumberAnimation { target: root; property: "uploaded"; from: 0; to: 1; duration: 520; easing.type: Easing.Linear }
        PauseAnimation { duration: 160 }
        ScriptAction {
            script: {
                const e = upload.target;
                root.uploading = false;
                root.uploaded = 0;
                HubState.close();
                if (e && e.run) Qt.callLater(e.run);
            }
        }
    }

    // ---------------------------------------------------------------- breach time
    property real remaining: 45
    NumberAnimation {
        id: timer
        target: root; property: "remaining"
        from: 45; to: 0; duration: 45000
        running: false
    }

    Connections {
        target: HubState
        function onOpenChanged() {
            if (HubState.open) {
                root.query = ""; root.sel = 0; root.uploading = false; root.uploaded = 0;
                keys.forceActiveFocus();
                timer.restart();
                title.replay();
            } else timer.stop();
        }
    }

    // ---------------------------------------------------------------- backdrop
    Rectangle { anchors.fill: parent; color: Theme.alpha(Theme.bgDark, 0.78 * root.shown) }
    Canvas {        // scanlines
        anchors.fill: parent
        opacity: 0.5 * root.shown
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.fillStyle = Theme.alpha(Theme.cyan, 0.05);
            for (let y = 0; y < height; y += 3) ctx.fillRect(0, y, width, 1);
        }
    }
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: m => m.button === Qt.RightButton ? root.back() : HubState.close() }

    // ---------------------------------------------------------------- the breach
    Item {
        id: stage
        readonly property bool narrow: root.width < 1100
        width: Math.min(1240, root.width - 64)
        height: Math.min(root.height - 120, narrow ? 1100 : 640)
        anchors.centerIn: parent
        opacity: root.shown
        transform: Translate { x: (1 - root.shown) * 24 }
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton; onClicked: m => { if (m.button === Qt.RightButton) root.back(); } }

        // header
        Row {
            id: head
            spacing: 12
            Tag { anchors.verticalCenter: parent.verticalCenter; height: 26; text: "BREACH PROTOCOL"; pixelSize: Theme.label + 3 }
            Jp { anchors.verticalCenter: parent.verticalCenter; text: "侵入"; font.pixelSize: 18 }
            Scramble {
                id: title
                anchors.verticalCenter: parent.verticalCenter
                target: HubState.path
                color: Theme.cyan
                font.family: Theme.mono; font.pixelSize: Theme.label + 1; font.letterSpacing: Theme.tracking
            }
        }
        // breach time remaining
        Column {
            anchors.right: parent.right
            spacing: 4
            Row {
                anchors.right: parent.right
                spacing: 10
                Label { anchors.verticalCenter: parent.verticalCenter; text: "BREACH TIME REMAINING" }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.remaining.toFixed(2)
                    color: root.remaining < 10 ? Theme.red : Theme.yellow
                    font.family: Theme.display; font.pixelSize: 24; font.weight: Font.DemiBold
                }
            }
            Rectangle {
                anchors.right: parent.right
                width: 300; height: 4
                color: Theme.alpha(Theme.yellow, 0.15)
                Rectangle { width: parent.width * root.remaining / 45; height: parent.height; color: root.remaining < 10 ? Theme.red : Theme.yellow }
            }
        }

        // ---------------------------------------------------------------- CODE MATRIX
        Item {
            id: matrixBox
            y: 64
            width: stage.narrow ? stage.width : Math.min(460, stage.width * 0.4)
            height: stage.narrow ? width * 0.78 : stage.height - y
            readonly property real cell: Math.min((width - 48) / root.size, (height - 72) / root.size)

            Chamfer { anchors.fill: parent; cut: 16; corners: "tl br"; fill: Theme.alpha(Theme.bgDark, 0.92); stroke: Theme.alpha(Theme.yellow, 0.55) }
            Rectangle { x: 0; y: 0; width: parent.width; height: 34; color: Theme.alpha(Theme.yellow, 0.12) }
            Label { x: 18; y: 10; text: "CODE MATRIX"; color: Theme.yellow; strong: true }
            Label { anchors.right: parent.right; anchors.rightMargin: 18; y: 10; text: "SUBNET " + (HubState.seed % 256).toString(16).toUpperCase().padStart(2, "0") }

            Item {
                id: grid
                x: (parent.width - width) / 2
                y: 34 + (parent.height - 34 - height) / 2
                width: matrixBox.cell * root.size
                height: width

                // the band of the path's last move (the game's highlighted row / column)
                Rectangle {
                    readonly property var last: root.path[root.path.length - 1] ?? null
                    readonly property bool column: root.path.length % 2 === 0
                    visible: !!last
                    x: column ? (last?.c ?? 0) * matrixBox.cell : 0
                    y: column ? 0 : (last?.r ?? 0) * matrixBox.cell
                    width: column ? matrixBox.cell : grid.width
                    height: column ? grid.height : matrixBox.cell
                    color: Theme.alpha(Theme.yellow, 0.10)
                    border.width: 1
                    border.color: Theme.alpha(Theme.yellow, 0.35)
                    Behavior on x { NumberAnimation { duration: Theme.fast; easing.type: Theme.easing } }
                    Behavior on y { NumberAnimation { duration: Theme.fast; easing.type: Theme.easing } }
                }

                Repeater {
                    model: root.size * root.size
                    Item {
                        id: cellItem
                        required property int index
                        readonly property int r: Math.floor(index / root.size)
                        readonly property int c: index % root.size
                        readonly property int order: root.path.findIndex(p => p.r === r && p.c === c)
                        readonly property bool onPath: order >= 0
                        readonly property bool done: onPath && root.uploading && root.uploaded * root.path.length > order
                        x: c * matrixBox.cell; y: r * matrixBox.cell
                        width: matrixBox.cell; height: matrixBox.cell
                        Rectangle {
                            anchors.fill: parent; anchors.margins: 5
                            visible: cellItem.onPath
                            color: cellItem.done ? Theme.yellow : "transparent"
                            border.width: 1
                            border.color: Theme.yellow
                        }
                        Text {
                            anchors.centerIn: parent
                            text: root.matrix[cellItem.index]
                            color: cellItem.done ? Theme.bgDark : cellItem.onPath ? Theme.yellow : Theme.alpha(Theme.fg, 0.55)
                            font.family: Theme.mono
                            font.pixelSize: Math.max(12, matrixBox.cell * 0.34)
                            font.weight: cellItem.onPath ? Font.Bold : Font.Normal
                        }
                        Text {     // the step number, top right of a path cell
                            visible: cellItem.onPath
                            anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 6
                            text: cellItem.order + 1
                            color: cellItem.done ? Theme.bgDark : Theme.alpha(Theme.yellow, 0.8)
                            font.family: Theme.mono; font.pixelSize: 9
                        }
                    }
                }
            }
        }

        // ---------------------------------------------------------------- BUFFER + daemons
        Item {
            id: right
            x: stage.narrow ? 0 : matrixBox.width + 24
            y: stage.narrow ? matrixBox.y + matrixBox.height + 20 : 64
            width: stage.width - x
            height: stage.height - y

            // buffer
            Label { id: bufLabel; text: "BUFFER"; color: Theme.yellow; strong: true }
            Row {
                id: buffer
                y: bufLabel.height + 8
                spacing: 8
                Repeater {
                    model: 6
                    Item {
                        id: slot
                        required property int index
                        readonly property string b: root.seq[index] ?? ""
                        readonly property bool filled: root.uploading && root.uploaded * root.seq.length > index
                        width: 46; height: 40
                        Rectangle {
                            anchors.fill: parent
                            color: slot.filled ? Theme.alpha(Theme.yellow, 0.2) : "transparent"
                            border.width: 1
                            border.color: slot.b ? Theme.alpha(Theme.yellow, slot.filled ? 1 : 0.5) : Theme.alpha(Theme.line, 0.8)
                        }
                        Text {
                            anchors.centerIn: parent
                            text: slot.b || "··"
                            color: slot.filled ? Theme.yellow : slot.b ? Theme.alpha(Theme.yellow, 0.45) : Theme.alpha(Theme.dim, 0.6)
                            font.family: Theme.mono; font.pixelSize: 16; font.weight: Font.DemiBold
                        }
                    }
                }
            }
            // what's going on
            Text {
                anchors.left: buffer.right; anchors.leftMargin: 18
                anchors.verticalCenter: buffer.verticalCenter
                width: right.width - buffer.width - 18
                elide: Text.ElideRight
                text: root.uploading ? (root.uploaded < 1 ? "UPLOADING DAEMON  " + Math.round(root.uploaded * 100) + "%" : "DAEMON UPLOADED")
                    : HubState.level?.loading ? "ACCESSING SUBNET…"
                    : root.query !== "" ? "> " + root.query + "▌"
                    : root.current?.open ? "ENTER // ACCESS SUBNET" : "ENTER // UPLOAD DAEMON"
                color: root.uploading && root.uploaded >= 1 ? Theme.green : root.query !== "" ? Theme.cyan : Theme.dim
                font.family: Theme.mono; font.pixelSize: Theme.label + 1; font.letterSpacing: Theme.tracking
            }

            Label { id: seqLabel; y: buffer.y + buffer.height + 22; text: "SEQUENCE REQUIRED TO UPLOAD"; color: Theme.yellow; strong: true }

            ListView {
                id: list
                y: seqLabel.y + seqLabel.height + 10
                width: parent.width
                height: parent.height - y
                clip: true
                model: root.shownItems
                currentIndex: root.sel
                highlightMoveDuration: Theme.fast
                boundsBehavior: Flickable.StopAtBounds
                spacing: 4
                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool sel: index === root.sel
                    readonly property var bytes: root.seqFor(modelData)
                    width: list.width
                    height: 54

                    Chamfer {
                        anchors.fill: parent
                        cut: 10; corners: "tr bl"
                        fill: row.sel ? Theme.alpha(Theme.yellow, 0.14) : Theme.alpha(Theme.bgDark, 0.7)
                        stroke: row.sel ? Theme.yellow : Theme.alpha(Theme.line, 0.9)
                    }
                    // the daemon's sequence
                    Row {
                        id: seqRow
                        x: 14
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        Repeater {
                            model: row.bytes
                            Text {
                                required property var modelData
                                text: modelData
                                color: row.sel ? Theme.yellow : Theme.alpha(Theme.cyan, 0.8)
                                font.family: Theme.mono; font.pixelSize: 14; font.weight: Font.DemiBold
                            }
                        }
                    }
                    Text {
                        id: glyph
                        x: 150
                        anchors.verticalCenter: parent.verticalCenter
                        text: (row.modelData.glyph ?? "").length <= 2 ? (row.modelData.glyph ?? "") : ""
                        color: row.sel ? Theme.bright : Theme.dim
                        font.family: Theme.mono; font.pixelSize: 18
                    }
                    Column {
                        x: 184
                        width: parent.width - x - 110
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: row.modelData.text.toUpperCase() + (row.modelData.on ? "  ●" : "")
                            color: row.sel ? Theme.bright : Theme.fg
                            font.family: Theme.condensed; font.pixelSize: 20; font.weight: Font.DemiBold; font.letterSpacing: 1
                        }
                        Label {
                            width: parent.width
                            elide: Text.ElideRight
                            visible: text !== ""
                            text: row.modelData.sub
                            color: row.sel ? Theme.cyan : Theme.dim
                        }
                    }
                    Tag {
                        anchors.right: parent.right; anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        height: 20
                        text: row.modelData.open ? "SUBNET ›" : "DAEMON"
                        outline: !row.sel
                        color: row.modelData.open ? Theme.cyan : Theme.yellow
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onPositionChanged: m => { const p = mapToGlobal(m.x, m.y); if (p.x !== root.pointer.x || p.y !== root.pointer.y) { root.pointer = p; if (!root.uploading) root.sel = row.index; } }
                        onClicked: m => { if (m.button === Qt.RightButton) root.back(); else { root.sel = row.index; root.enter(); } }
                    }
                }
                Label {
                    anchors.centerIn: parent
                    visible: !HubState.level?.loading && root.shownItems.length === 0
                    text: root.query !== "" ? "NO DAEMON MATCHES  \"" + root.query + "\"" : "SUBNET EMPTY"
                }
            }
        }

        // footer
        Label {
            anchors.left: parent.left
            anchors.top: parent.bottom
            anchors.topMargin: 14
            text: "↑↓ PICK   //   ENTER UPLOAD   //   → ACCESS   //   ← ESC BACK OUT   //   TYPE TO FILTER"
        }
        Hazard { anchors.right: parent.right; anchors.top: parent.bottom; anchors.topMargin: 16; width: 120; height: 6 }
    }

    // ---------------------------------------------------------------- keys
    TextInput {
        id: keys
        opacity: 0; width: 1; height: 1
        focus: HubState.open
        text: root.query
        onTextEdited: root.query = text
        Keys.onPressed: e => {
            const k = e.key;
            if (k === Qt.Key_Escape || k === Qt.Key_Left || (k === Qt.Key_Backspace && root.query === "")) root.back();
            else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Right) root.enter();
            else if (k === Qt.Key_Down || (k === Qt.Key_Tab && !(e.modifiers & Qt.ShiftModifier))) root.step(1);
            else if (k === Qt.Key_Up || k === Qt.Key_Backtab) root.step(-1);
            else return;
            e.accepted = true;
        }
    }
}
