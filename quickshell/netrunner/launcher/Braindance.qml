import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import "../theme"
import "../widgets"
import "bd.js" as Bd

// BRAINDANCE ブレインダンス: clipboard history (SUPER + V) as the game's braindance editor. Your
// copies are a recording: along the bottom a timeline, oldest left, with a track per kind of thing
// (LINK CODE PATH TEXT IMAGE) and each copy a clip at the moment you made it (pauses stretch the
// tape a little, long gaps become cuts: // 9H 12M). Above it a filmstrip of the clips around the
// playhead, and the viewer: the selected clip whole, on one of three layers (Tab): RAW, DECODED
// (bd.js: a link's parts, JSON laid out, a colour, a timestamp, base64 / JWT…), META.
// It opens on the newest copy. ← → (and ↓ ↑) step through the clips; held down they rewind / fast
// forward with the tape tearing; when you stop, the frame reconstructs behind a scan line. Typing
// scans the recording: matches light up on the tape and ← → hop between them. Enter extracts the
// clip (copies it back) and closes; Ctrl+P pins it (a yellow flag), Ctrl+D / Delete cuts it out
// (the tape closes up), Ctrl+Shift+D twice wipes every unpinned clip, Esc closes. Drag or click
// on the timeline to scrub, wheel to step. Same history as Walker's (elephant's clipboard provider).
// qs ipc call clipboard toggle. Testing: NETRUNNER_BD_FIXTURE=<elephant json lines> reads that
// instead and applies actions only in memory (logged to <fixture>.log).
PanelWindow {
    id: root

    Binding on screen {
        when: !root.visible
        value: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        restoreMode: Binding.RestoreNone
    }
    visible: ClipboardState.open || outro.running

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "netrunner-shards"
    WlrLayershell.keyboardFocus: ClipboardState.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: ClipboardState.open ? null : noInput
    Region { id: noInput }

    readonly property string fixture: Quickshell.env("NETRUNNER_BD_FIXTURE") ?? ""

    // ---------------------------------------------------------------- the recording
    property var items: []
    property bool loaded: false
    property string query: ""
    property string curId: ""
    property int layerIdx: 0                 // 0 RAW, 1 DECODED, 2 META
    property bool clearArmed: false
    property point pointer: Qt.point(-1, -1)
    property double now: Date.now()

    readonly property var layers: ["RAW", "DECODED", "META"]
    Binding {
        target: ClipboardState; property: "status"
        value: `open=${ClipboardState.open} visible=${root.visible} clips=${root.tape.list.length} clip=${root.cur ? root.cur.n + 1 : 0} id=${root.cur?.id ?? ""} layer=${root.layers[root.layerIdx]} query=${root.query} hits=${root.hits.length}`
    }
    function pinned(it) { return (it.actions ?? []).includes("unpin"); }
    function kindColor(k) { return k === "link" ? Theme.cyan : k === "code" ? Theme.green : k === "path" ? Theme.yellow : k === "image" ? Theme.red : Theme.fg; }

    // the clips in time order, placed on the tape: a unit per clip, up to two more for a pause,
    // and a cut (4 units) for a gap over half an hour
    readonly property var tape: {
        const list = root.items.map((it, i) => ({ id: it.identifier, it: it, i: i, t: Date.parse(it.subtext ?? "") || 0,
                                                 kind: Bd.kindOf(it), pinned: root.pinned(it) }))
            .sort((a, b) => a.t - b.t || b.i - a.i);
        const cuts = [], byId = {};
        let u = 0;
        for (let n = 0; n < list.length; n++) {
            const c = list[n];
            if (n > 0) {
                const g = Math.max(0, (c.t - list[n - 1].t) / 1000);
                if (g > 1800) { cuts.push({ u: u + 2, gap: Bd.gap(g) }); u += 4; }
                else u += 1 + Math.min(2, g / 300);
            }
            c.u = u;
            c.n = n;
            c.hour = n === 0 || new Date(c.t).getHours() !== new Date(list[n - 1].t).getHours() || c.t - list[n - 1].t > 3600000;
            byId[c.id] = c;
        }
        return { list: list, cuts: cuts, byId: byId, total: u };
    }
    readonly property bool searching: query.trim() !== ""
    readonly property var hits: {
        const q = query.trim().toLowerCase();
        if (q === "") return tape.list;
        return tape.list.filter(c => (c.it.text ?? "").toLowerCase().includes(q) || (q.length >= 3 && c.kind.startsWith(q)));
    }
    readonly property var hitIds: { const s = {}; for (const c of hits) s[c.id] = true; return s; }
    readonly property var cur: tape.byId[curId] ?? (tape.list.length ? tape.list[tape.list.length - 1] : null)
    readonly property var decoded: cur ? Bd.decode(cur.it, cur.kind, now) : ({ title: "", rows: [], code: "", swatch: "" })

    // typing scans: stay on the clip if it still matches, else hop to the nearest match
    onQueryChanged: {
        if (!searching || hits.length === 0 || !cur || hitIds[cur.id]) return;
        let best = hits[hits.length - 1];
        for (const h of hits) if (Math.abs(h.u - cur.u) < Math.abs(best.u - cur.u)) best = h;
        select(best.id, best.u < cur.u ? -1 : 1);
    }

    // ---------------------------------------------------------------- moving the playhead
    property real tapeFx: 0                  // the rewind effect, kicked by each step, decaying
    property int lastDir: 0
    function select(id, dir) {
        if (!id || id === (cur?.id ?? "")) return;
        curId = id;
        if (dir !== 0) { tapeFx = Math.min(1, tapeFx + 0.5); lastDir = dir; }
        recon.play();
    }
    function step(d) {
        const pool = hits;
        if (!pool.length) return;
        const c = cur;
        const i = c ? pool.findIndex(x => x.id === c.id) : -1;
        let target;
        if (i >= 0) target = pool[Math.max(0, Math.min(pool.length - 1, i + d))];
        else if (d < 0) target = pool.filter(x => x.u < (c?.u ?? 1e9)).pop() ?? pool[0];
        else target = pool.find(x => x.u > (c?.u ?? -1)) ?? pool[pool.length - 1];
        select(target.id, d < 0 ? -1 : 1);
    }
    function jump(toEnd) {
        const pool = hits;
        if (pool.length) select(pool[toEnd ? pool.length - 1 : 0].id, toEnd ? 1 : -1);
    }
    function scrubTo(u) {                    // the clip nearest a point on the tape
        let best = null;
        for (const h of hits) if (!best || Math.abs(h.u - u) < Math.abs(best.u - u)) best = h;
        if (best) select(best.id, best.u < (cur?.u ?? 0) ? -1 : 1);
    }

    // ---------------------------------------------------------------- elephant
    function refresh() { query_.running = false; query_.command = root.fixture ? ["cat", root.fixture] : ["elephant", "query", "--json", "clipboard;;500;false"]; query_.running = true; }
    function act(c, action, closing) {
        if (!c) return;
        if (closing) extract();
        else applyLocally(c, action);        // show it now; the refresh after confirms it
        if (fixture) {
            Quickshell.execDetached(["sh", "-c", 'printf "%s %s\\n" "$1" "$2" >> "$3"', "sh", action, c.id, fixture + ".log"]);
            return;
        }
        activate.command = ["elephant", "activate", `clipboard;${c.id};${action};;`];
        activate.closing = closing;
        activate.running = true;
    }
    function applyLocally(c, action) {
        if (action === "remove" || action === "remove_all") {
            const keep = action === "remove" ? root.items.filter(it => it.identifier !== c.id) : root.items.filter(it => root.pinned(it));
            if (action === "remove") {         // the playhead moves to the next clip (newer, else older)
                const pool = hits.filter(x => x.id !== c.id);
                const next = pool.find(x => x.u > c.u) ?? pool.filter(x => x.u < c.u).pop();
                curId = next ? next.id : "";
            } else curId = "";
            cutFx.play();
            root.items = keep;
        } else if (action === "pin" || action === "unpin") {
            root.items = root.items.map(it => it.identifier !== c.id ? it : Object.assign({}, it, {
                actions: (it.actions ?? []).filter(a => a !== "pin" && a !== "unpin").concat([action === "pin" ? "unpin" : "pin"]) }));
        }
    }
    Process {
        id: query_
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    if (!line.trim()) continue;
                    try { out.push(JSON.parse(line).item); } catch (e) {}
                }
                root.items = out;
                root.loaded = true;
                if (root.curId && !root.tape.byId[root.curId]) root.curId = "";
            }
        }
    }
    Process {
        id: activate
        property bool closing: false
        onExited: if (!closing) root.refresh()
    }

    // ---------------------------------------------------------------- open, extract, close
    Driver { id: intro; until: 420 }
    Driver { id: outro; until: 220 }
    Driver { id: recon; until: 300 }
    Driver { id: cutFx; until: 260 }
    property bool extracting: false
    property real time: 0
    FrameAnimation {
        running: root.visible
        onTriggered: {
            root.time += frameTime;
            if (root.tapeFx > 0) root.tapeFx = Math.max(0, root.tapeFx - frameTime * 3.2);
        }
    }

    function extract() { extracting = true; outro.until = 340; outro.play(); ClipboardState.open = false; }
    function close() {
        if (!ClipboardState.open) return;
        extracting = false; outro.until = 220; outro.play(); ClipboardState.open = false;
    }
    Connections {
        target: ClipboardState
        function onOpenChanged() {
            if (ClipboardState.open) {
                outro.stop();
                root.extracting = false;
                root.query = ""; root.curId = ""; root.layerIdx = 0; root.clearArmed = false;
                root.pointer = Qt.point(-1, -1);
                root.now = Date.now();
                root.loaded = false;
                root.refresh();
                field.focusField();
                title.replay();
                intro.play();
                recon.play();
            } else if (!outro.running) { root.extracting = false; outro.until = 220; outro.play(); }   // closed from outside
        }
    }
    Timer { id: disarm; interval: 2500; onTriggered: root.clearArmed = false }

    readonly property real glitchAmt: intro.running ? 1 - Theme.out3(Theme.seg(intro.ms, 0, 260))
        : outro.running ? (extracting ? Theme.seg(outro.ms, 110, 340) : Theme.seg(outro.ms, 0, 200)) : 0
    readonly property real presence: intro.running ? Theme.seg(intro.ms, 0, 220) : outro.running ? 1 - Theme.seg(outro.ms, 0, outro.until) : ClipboardState.open ? 1 : 0
    readonly property real reveal: intro.running ? Theme.out3(Theme.seg(intro.ms, 60, 400)) : 1
    readonly property real filmIn: intro.running ? Theme.out3(Theme.seg(intro.ms, 120, 400)) : 1

    // ---------------------------------------------------------------- look
    Rectangle { anchors.fill: parent; color: Theme.alpha(Theme.bgDark, 0.74 * root.presence) }
    MouseArea { anchors.fill: parent; onClicked: root.close() }

    Item {
        id: stage
        width: Math.min(1440, root.width - 80)
        height: Math.min(root.height - 100, 860)
        anchors.centerIn: parent
        MouseArea { anchors.fill: parent }

        layer.enabled: root.glitchAmt > 0.002
        layer.effect: ShaderEffect {
            fragmentShader: Qt.resolvedUrl("../shaders/glitch.frag.qsb")
            property vector2d size: Qt.vector2d(stage.width, stage.height)
            property real amount: root.glitchAmt
            property real time: root.time
            property real seed: 0.31
            property color red: Theme.red
            property color cyan: Theme.cyan
        }

        // ---------------------------------------------------------------- header
        Row {
            id: head
            spacing: 10
            Tag { anchors.verticalCenter: parent.verticalCenter; text: "BRAINDANCE"; height: 24; pixelSize: Theme.label + 2 }
            Scramble {
                id: title
                anchors.verticalCenter: parent.verticalCenter
                target: "EDITOR // CLIPBOARD // " + (root.loaded ? root.tape.list.length + " CLIPS" : "READING TAPE")
                color: Theme.bright; font.family: Theme.mono; font.pixelSize: Theme.label + 1; font.letterSpacing: Theme.tracking; font.weight: Font.DemiBold
            }
            Jp { anchors.verticalCenter: parent.verticalCenter; text: "ブレインダンス" }
        }
        Label {
            anchors.right: field.left; anchors.rightMargin: 12
            anchors.verticalCenter: field.verticalCenter
            visible: root.searching
            text: root.hits.length + " MATCH" + (root.hits.length === 1 ? "" : "ES")
            color: root.hits.length ? Theme.cyan : Theme.red
        }
        Field {
            id: field
            anchors.right: parent.right
            anchors.verticalCenter: head.verticalCenter
            width: Math.min(360, stage.width - head.width - 140)
            height: 34
            text: root.query
            placeholder: "scan the recording"
            onEdited: root.query = text
            onAccepted: root.act(root.cur, "copy", true)
            input.Keys.onPressed: e => {
                const k = e.key, ctrl = e.modifiers & Qt.ControlModifier, shift = e.modifiers & Qt.ShiftModifier;
                if (k === Qt.Key_Escape) { if (root.query !== "") root.query = ""; else root.close(); }
                else if (k === Qt.Key_Left || k === Qt.Key_Down) root.step(-1);
                else if (k === Qt.Key_Right || k === Qt.Key_Up) root.step(1);
                else if (k === Qt.Key_PageUp) root.step(-10);
                else if (k === Qt.Key_PageDown) root.step(10);
                else if (k === Qt.Key_Home) root.jump(false);
                else if (k === Qt.Key_End) root.jump(true);
                else if (k === Qt.Key_Tab) root.layerIdx = (root.layerIdx + 1) % 3;
                else if (k === Qt.Key_Backtab) root.layerIdx = (root.layerIdx + 2) % 3;
                else if (ctrl && k === Qt.Key_P && root.cur) root.act(root.cur, root.cur.pinned ? "unpin" : "pin", false);
                else if (ctrl && shift && k === Qt.Key_D) {
                    if (root.clearArmed && root.cur) { root.clearArmed = false; root.act(root.cur, "remove_all", false); }
                    else { root.clearArmed = true; disarm.restart(); }
                }
                else if ((ctrl && k === Qt.Key_D) || (k === Qt.Key_Delete && root.query === "")) root.act(root.cur, "remove", false);
                else return;
                e.accepted = true;
            }
        }

        // ---------------------------------------------------------------- the viewer
        Item {
            id: viewer
            y: 50
            width: stage.width
            height: film.y - 10 - y

            Chamfer { anchors.fill: parent; cut: 18; corners: "tl br"; fill: Theme.alpha(Theme.bgDark, 0.93); stroke: Theme.alpha(Theme.red, 0.55) }

            Item {
                id: screenArea
                anchors.fill: parent
                anchors.margins: 1
                layer.enabled: true
                layer.effect: ShaderEffect {
                    fragmentShader: Qt.resolvedUrl("../shaders/tape.frag.qsb")
                    property vector2d size: Qt.vector2d(screenArea.width, screenArea.height)
                    property real amount: Math.max(root.tapeFx, root.extracting ? 0.6 * Theme.seg(outro.ms, 0, 120) : 0, cutFx.running ? 1 - Theme.seg(cutFx.ms, 0, 260) : 0)
                    property real pixel: 5 + 7 * root.tapeFx
                    property real sweep: recon.running ? Theme.out3(Theme.seg(recon.ms, 0, 280)) : 1
                    property real time: root.time
                    property color tint: Theme.red
                }

                // the layer tabs, the clip's track and time
                Row {
                    x: 18; y: 12
                    spacing: 4
                    Label { anchors.verticalCenter: parent.verticalCenter; text: "LAYER"; rightPadding: 8 }
                    Repeater {
                        model: root.layers
                        Item {
                            id: tab
                            required property string modelData
                            required property int index
                            readonly property bool on: root.layerIdx === index
                            width: tabText.implicitWidth + 20
                            height: 22
                            Rectangle { anchors.fill: parent; color: tab.on ? Theme.red : "transparent"; border.width: 1; border.color: tab.on ? Theme.red : Theme.line }
                            Text {
                                id: tabText
                                anchors.centerIn: parent
                                text: tab.modelData
                                color: tab.on ? Theme.onRed : Theme.fg
                                font.family: Theme.mono; font.pixelSize: Theme.label; font.letterSpacing: Theme.tracking; font.weight: Font.Bold
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.layerIdx = tab.index }
                        }
                    }
                }
                Row {
                    anchors.right: parent.right; anchors.rightMargin: 18
                    y: 16
                    spacing: 10
                    Text {
                        text: root.cur ? root.cur.kind.toUpperCase() : ""
                        color: root.cur ? root.kindColor(root.cur.kind) : Theme.dim
                        font.family: Theme.mono; font.pixelSize: Theme.label; font.letterSpacing: Theme.tracking; font.weight: Font.Bold
                    }
                    Label {
                        text: root.cur && root.cur.t ? Qt.formatDateTime(new Date(root.cur.t), "ddd dd MMM  hh:mm:ss").toUpperCase() + "   //   " + Bd.ago(root.now - root.cur.t) : ""
                    }
                    Text {
                        visible: root.cur?.pinned ?? false
                        text: "\u{f0403}"
                        color: Theme.yellow
                        font.family: Theme.mono; font.pixelSize: Theme.label + 1
                    }
                }

                // the frame
                Item {
                    id: frame
                    x: 22; y: 48
                    width: parent.width - 44
                    height: parent.height - y - 40

                    // RAW
                    Flickable {
                        id: rawText
                        anchors.fill: parent
                        visible: root.layerIdx === 0 && root.cur !== null && root.cur.kind !== "image"
                        clip: true
                        contentHeight: body.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        Text {
                            id: body
                            width: rawText.width
                            wrapMode: Text.WrapAnywhere
                            textFormat: Text.PlainText
                            text: (root.cur?.it.text ?? "").slice(0, 8000)
                            color: Theme.bright
                            font.family: Theme.mono; font.pixelSize: Theme.data + 1
                            lineHeight: 1.2
                        }
                    }
                    Image {
                        id: picture
                        anchors.fill: parent
                        visible: root.layerIdx === 0 && root.cur?.kind === "image"
                        source: root.cur?.kind === "image" ? "file://" + root.cur.it.preview : ""
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        sourceSize.width: 1600
                    }

                    // DECODED
                    Flickable {
                        id: decodedView
                        anchors.fill: parent
                        visible: root.layerIdx === 1
                        clip: true
                        contentHeight: decodedCol.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        Column {
                            id: decodedCol
                            width: decodedView.width
                            spacing: 8
                            Label {
                                text: root.decoded.title || (root.cur?.kind === "image" ? "IMAGE  //  NOTHING HIDDEN IN THE PIXELS" : "NO HIDDEN LAYER  //  WHAT YOU SEE IS ALL THERE IS")
                                color: root.decoded.title ? Theme.cyan : Theme.dim
                                strong: true
                            }
                            Row {
                                visible: root.decoded.swatch !== ""
                                spacing: 16
                                Rectangle { width: 96; height: 96; color: root.decoded.swatch || "transparent"; border.width: 1; border.color: Theme.line }
                                Rectangle { width: 96; height: 96; color: Theme.bgDark; border.width: 1; border.color: Theme.line
                                    Rectangle { anchors.centerIn: parent; width: 48; height: 48; color: root.decoded.swatch || "transparent" } }
                            }
                            Repeater {
                                model: root.decoded.rows
                                Row {
                                    required property var modelData
                                    spacing: 16
                                    Text {
                                        width: 110
                                        text: modelData[0]
                                        color: Theme.cyan
                                        elide: Text.ElideRight
                                        font.family: Theme.mono; font.pixelSize: Theme.label + 1; font.letterSpacing: 1
                                    }
                                    Text {
                                        width: decodedCol.width - 126
                                        text: modelData[1]
                                        wrapMode: Text.WrapAnywhere
                                        color: Theme.bright
                                        textFormat: Text.PlainText
                                        font.family: Theme.mono; font.pixelSize: Theme.data + 1
                                    }
                                }
                            }
                            Rectangle {
                                visible: root.decoded.code !== ""
                                width: parent.width
                                height: code.implicitHeight + 24
                                color: Theme.alpha(Theme.bg, 0.8)
                                border.width: 1; border.color: Theme.line
                                Text {
                                    id: code
                                    x: 12; y: 12
                                    width: parent.width - 24
                                    wrapMode: Text.WrapAnywhere
                                    textFormat: Text.PlainText
                                    text: root.decoded.code
                                    color: Theme.green
                                    font.family: Theme.mono; font.pixelSize: Theme.data
                                }
                            }
                        }
                    }

                    // META
                    Column {
                        visible: root.layerIdx === 2 && root.cur !== null
                        width: parent.width
                        spacing: 8
                        Repeater {
                            model: {
                                const c = root.cur;
                                if (!c) return [];
                                const s = c.it.text ?? "";
                                const rows = [
                                    ["COPIED", c.t ? Bd.stamp(new Date(c.t)) : "unknown"],
                                    ["AGO", c.t ? Bd.ago(root.now - c.t) : "unknown"],
                                    ["TRACK", c.kind.toUpperCase()],
                                    ["CLIP", (c.n + 1) + " OF " + root.tape.list.length],
                                    ["PINNED", c.pinned ? "YES  //  KEPT WHEN YOU WIPE" : "NO"],
                                    ["ADDRESS", c.id],
                                ];
                                if (c.kind === "image") rows.splice(3, 0, ["FILE", c.it.preview], ["PIXELS", picture.implicitWidth ? picture.implicitWidth + " × " + picture.implicitHeight : "…"]);
                                else rows.splice(3, 0, ["LENGTH", s.length + " CHARS  //  " + (s.trim() ? s.trim().split(/\s+/).length : 0) + " WORDS  //  " + s.split("\n").length + (s.split("\n").length === 1 ? " LINE" : " LINES")],
                                                       ["BYTES", Bd.bytes(s) + " UTF-8"]);
                                return rows;
                            }
                            Row {
                                required property var modelData
                                spacing: 16
                                Text { width: 110; text: modelData[0]; color: Theme.red; font.family: Theme.mono; font.pixelSize: Theme.label + 1; font.letterSpacing: 1 }
                                Text { width: frame.width - 126; text: modelData[1]; color: Theme.bright; wrapMode: Text.WrapAnywhere; textFormat: Text.PlainText; font.family: Theme.mono; font.pixelSize: Theme.data + 1 }
                            }
                        }
                    }

                    Label {
                        anchors.centerIn: parent
                        visible: root.loaded && root.tape.list.length === 0
                        text: "NO RECORDING  //  COPY SOMETHING"
                    }
                }

                // viewfinder corners
                Repeater {
                    model: 4
                    Item {
                        required property int index
                        x: index % 2 ? screenArea.width - 34 : 12
                        y: index > 1 ? screenArea.height - 34 : 40
                        width: 22; height: 22
                        Rectangle { x: index % 2 ? 20 : 0; width: 2; height: 22; color: Theme.alpha(Theme.red, 0.6) }
                        Rectangle { y: index > 1 ? 20 : 0; width: 22; height: 2; color: Theme.alpha(Theme.red, 0.6) }
                    }
                }
                Text {
                    x: 20
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 12
                    text: root.tapeFx > 0.15 ? (root.lastDir < 0 ? "◀◀  REWIND" : "▶▶  FAST-FORWARD") : recon.running ? "▣  RECONSTRUCTING" : "▶  PLAYBACK"
                    color: root.tapeFx > 0.15 ? Theme.red : Theme.cyan
                    font.family: Theme.mono; font.pixelSize: Theme.label + 1; font.letterSpacing: Theme.tracking; font.weight: Font.Bold
                }
                Label {
                    anchors.right: parent.right; anchors.rightMargin: 20
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 12
                    text: root.cur ? "CLIP " + String(root.cur.n + 1).padStart(3, "0") + " / " + String(root.tape.list.length).padStart(3, "0") : "--"
                }
            }

            // EXTRACTED: stamped over the frame as Enter copies it
            Rectangle {
                anchors.centerIn: parent
                visible: root.extracting
                width: stampText.implicitWidth + 40
                height: 48
                color: Theme.red
                scale: 1.25 - 0.25 * Theme.out3(Theme.seg(outro.ms, 0, 120))
                Text {
                    id: stampText
                    anchors.centerIn: parent
                    text: "EXTRACTED TO CLIPBOARD"
                    color: Theme.onRed
                    font.family: Theme.display; font.pixelSize: 22; font.weight: Font.Bold; font.letterSpacing: 2
                }
            }
        }

        // ---------------------------------------------------------------- the filmstrip
        ListView {
            id: film
            y: timeline.y - 10 - height
            width: stage.width
            height: 66
            opacity: root.filmIn
            orientation: ListView.Horizontal
            spacing: 8
            clip: true
            interactive: false
            model: root.tape.list
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: width / 2 - 88
            preferredHighlightEnd: width / 2 + 88
            highlightMoveDuration: 160
            transform: Translate { x: (1 - root.filmIn) * 80 }
            // set, not bound, and after the model settles: a ListView resets currentIndex when its model changes
            function follow() { const n = root.cur ? root.cur.n : -1; if (currentIndex !== n) currentIndex = n; }
            onCountChanged: Qt.callLater(follow)
            Connections { target: root; function onCurChanged() { Qt.callLater(film.follow); } }
            delegate: Item {
                id: card
                required property var modelData
                readonly property bool on: root.cur?.id === modelData.id
                readonly property bool hit: !root.searching || root.hitIds[modelData.id] === true
                width: 176
                height: film.height
                opacity: hit ? 1 : 0.25
                Chamfer {
                    anchors.fill: parent
                    cut: 8; corners: "tr bl"
                    fill: card.on ? Theme.alpha(Theme.red, 0.18) : Theme.alpha(Theme.bgDark, 0.85)
                    stroke: card.on ? Theme.red : Theme.alpha(Theme.line, 0.9)
                }
                Rectangle { x: 1; y: 1; width: parent.width - 10; height: 2; color: root.kindColor(card.modelData.kind) }
                Text {
                    x: 10; y: 10
                    width: parent.width - 20
                    visible: card.modelData.kind !== "image"
                    maximumLineCount: 2
                    wrapMode: Text.WrapAnywhere
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    text: (card.modelData.it.text ?? "").replace(/\s+/g, " ").trim().slice(0, 120)
                    color: card.on ? Theme.bright : Theme.fg
                    font.family: Theme.mono; font.pixelSize: Theme.label
                }
                Image {
                    x: 10; y: 8
                    width: parent.width - 20; height: 34
                    visible: card.modelData.kind === "image"
                    source: visible ? "file://" + card.modelData.it.preview : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 200
                }
                Label {
                    x: 10; anchors.bottom: parent.bottom; anchors.bottomMargin: 6
                    text: (card.modelData.t ? Qt.formatDateTime(new Date(card.modelData.t), "hh:mm") : "--:--") + (card.modelData.pinned ? "  \u{f0403}" : "")
                    color: card.modelData.pinned ? Theme.yellow : card.on ? Theme.cyan : Theme.dim
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.select(card.modelData.id, card.modelData.u < (root.cur?.u ?? 0) ? -1 : 1)
                    onDoubleClicked: root.act(card.modelData, "copy", true)
                }
            }
        }

        // ---------------------------------------------------------------- the timeline
        Item {
            id: timeline
            y: stage.height - 26 - height
            width: stage.width
            height: 150

            readonly property real labelW: 74
            readonly property real trackW: width - labelW
            readonly property real rowH: 20
            readonly property real tracksY: 26
            readonly property real visibleUnits: Math.max(30, Math.min(root.tape.total + 6, trackW / 15))
            readonly property real ppu: trackW / visibleUnits
            readonly property real viewStart: {
                const c = root.cur;
                if (!c) return 0;
                const lo = -3, hi = Math.max(lo, root.tape.total + 3 - visibleUnits);
                return Math.max(lo, Math.min(hi, c.u - visibleUnits * 0.5));
            }

            Chamfer { anchors.fill: parent; cut: 12; corners: "tr bl"; fill: Theme.alpha(Theme.bgDark, 0.9); stroke: Theme.alpha(Theme.line, 0.9) }

            // the tracks' names and how many clips each has
            Repeater {
                model: Bd.KINDS
                Item {
                    required property string modelData
                    required property int index
                    x: 12
                    y: timeline.tracksY + index * timeline.rowH
                    width: timeline.labelW - 16
                    height: timeline.rowH
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.toUpperCase()
                        color: root.kindColor(modelData)
                        font.family: Theme.mono; font.pixelSize: Theme.label - 1; font.letterSpacing: 1; font.weight: Font.Bold
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.tape.list.filter(c => c.kind === modelData).length
                        color: Theme.dim
                        font.family: Theme.mono; font.pixelSize: Theme.label - 1
                    }
                }
            }
            Repeater {          // track lanes
                model: 5
                Rectangle {
                    required property int index
                    x: timeline.labelW; y: timeline.tracksY + index * timeline.rowH + timeline.rowH / 2
                    width: timeline.trackW - 10; height: 1
                    color: Theme.alpha(Theme.line, 0.6)
                }
            }

            // the reel: everything on the tape, scrolled to keep the playhead in view
            Item {
                id: revealer
                x: timeline.labelW
                y: 0
                width: (timeline.trackW - 10) * root.reveal
                height: timeline.tracksY + 5 * timeline.rowH + 4
                clip: true

                Item {
                    id: reel
                    x: -timeline.viewStart * timeline.ppu
                    Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                    // hour marks on the ruler, kept apart
                    Repeater {
                        model: {
                            const out = [], cutsX = root.tape.cuts.map(k => k.u * timeline.ppu);
                            let last = -1e9;
                            for (const c of root.tape.list) {
                                const x = c.u * timeline.ppu;
                                if (c.hour && c.t && x - last > 70 && cutsX.every(k => Math.abs(k - x) > 90)) { out.push(c); last = x; }
                            }
                            return out;
                        }
                        Item {
                            required property var modelData
                            x: modelData.u * timeline.ppu
                            Rectangle { y: 4; width: 1; height: 14; color: Theme.line }
                            Text { x: 4; y: 4; text: Qt.formatDateTime(new Date(modelData.t), "hh:mm"); color: Theme.dim; font.family: Theme.mono; font.pixelSize: Theme.label - 1 }
                        }
                    }
                    // cuts: where the recording stopped for a while
                    Repeater {
                        model: {
                            let last = -1e9;
                            return root.tape.cuts.map(k => { const x = k.u * timeline.ppu, room = x - last > 90; if (room) last = x; return Object.assign({ room: room }, k); });
                        }
                        Item {
                            required property var modelData
                            x: modelData.u * timeline.ppu
                            Repeater {
                                model: 10
                                Rectangle { required property int index; x: -1; y: timeline.tracksY + index * 10; width: 2; height: 5; color: Theme.alpha(Theme.red, 0.6) }
                            }
                            Text { visible: modelData.room; x: 5; y: 4; text: "// " + modelData.gap; color: Theme.red; font.family: Theme.mono; font.pixelSize: Theme.label - 1; font.weight: Font.Bold }
                        }
                    }
                    // the clips
                    Repeater {
                        model: ScriptModel { values: root.tape.list; objectProp: "id" }
                        Item {
                            id: mark
                            required property var modelData
                            readonly property var c: root.tape.byId[modelData.id] ?? modelData
                            readonly property bool on: root.cur?.id === c.id
                            readonly property bool hit: !root.searching || root.hitIds[c.id] === true
                            x: c.u * timeline.ppu
                            y: timeline.tracksY + Bd.KINDS.indexOf(c.kind) * timeline.rowH
                            Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                            Rectangle {
                                visible: mark.on
                                x: -5; y: 1; width: 12; height: timeline.rowH - 2
                                color: Theme.alpha(root.kindColor(mark.c.kind), 0.3)
                            }
                            Rectangle {
                                x: -1.5
                                y: mark.hit && root.searching ? 2 : 4
                                width: mark.on ? 4 : 3
                                height: timeline.rowH - 2 * y
                                color: root.kindColor(mark.c.kind)
                                opacity: mark.hit ? (mark.on ? 1 : 0.85) : 0.18
                            }
                            // a pin: a yellow flag up on the ruler
                            Item {
                                visible: mark.c.pinned
                                y: -(mark.y - 6)
                                Rectangle { width: 1; height: 16; color: Theme.yellow }
                                Rectangle { x: 1; width: 8; height: 6; color: Theme.yellow }
                            }
                        }
                    }
                    // the playhead
                    Item {
                        visible: root.cur !== null
                        x: (root.cur?.u ?? 0) * timeline.ppu
                        Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        Rectangle { x: -1; y: 20; width: 2; height: timeline.tracksY + 5 * timeline.rowH - 18; color: Theme.red }
                        Rectangle { x: -6; y: 18; width: 12; height: 6; color: Theme.red }
                    }
                }
            }
            // the write head while the tape records in
            Rectangle {
                visible: intro.running
                x: revealer.x + revealer.width
                y: timeline.tracksY - 4
                width: 2; height: 5 * timeline.rowH + 8
                color: Theme.bright
            }
            MouseArea {
                x: revealer.x; y: 0
                width: timeline.trackW - 10
                height: revealer.height
                cursorShape: Qt.SizeHorCursor
                preventStealing: true
                onPressed: m => root.scrubTo(timeline.viewStart + m.x / timeline.ppu)
                onPositionChanged: m => { if (pressed) root.scrubTo(timeline.viewStart + m.x / timeline.ppu); }
                onWheel: w => root.step(w.angleDelta.y > 0 ? -1 : 1)
            }

            // the whole recording, small, with the part in view boxed
            Item {
                id: overview
                x: timeline.labelW
                y: timeline.height - 16
                width: timeline.trackW - 10
                height: 6
                Canvas {
                    id: overCanvas
                    anchors.fill: parent
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        const total = Math.max(1, root.tape.total);
                        for (const c of root.tape.list) {
                            ctx.fillStyle = root.kindColor(c.kind);
                            ctx.globalAlpha = !root.searching || root.hitIds[c.id] ? 0.9 : 0.15;
                            ctx.fillRect(Math.round(c.u / total * (width - 2)), 0, 1, height);
                        }
                    }
                    Connections {
                        target: root
                        function onTapeChanged() { overCanvas.requestPaint(); }
                        function onHitIdsChanged() { overCanvas.requestPaint(); }
                    }
                    onWidthChanged: requestPaint()
                }
                Rectangle {
                    readonly property real total: Math.max(1, root.tape.total)
                    x: Math.max(0, timeline.viewStart / total * overview.width)
                    width: Math.min(overview.width - x, timeline.visibleUnits / total * overview.width)
                    y: -3; height: overview.height + 6
                    color: "transparent"
                    border.width: 1; border.color: Theme.alpha(Theme.red, 0.8)
                    Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                }
            }
        }

        Label {
            anchors.bottom: parent.bottom
            text: root.clearArmed ? "CTRL ⇧ D AGAIN WIPES EVERY UNPINNED CLIP"
                : "← → SCRUB   //   TAB LAYER   //   ENTER EXTRACT   //   CTRL P PIN   //   CTRL D CUT   //   CTRL ⇧ D WIPE ALL   //   ESC CLOSE"
            color: root.clearArmed ? Theme.red : Theme.dim
        }
    }
}
