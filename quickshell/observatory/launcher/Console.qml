import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import "../theme"

// The console: Observatory's root menu (SUPER + Space), in place of Walker's. Same menus, same
// actions: it reads ~/.config/elephant/menus through `elephant query` and runs entries with
// `elephant activate`, exactly as Walker does, so anything added to those menus appears here too.
//
// A menu is a ring of brass instruments around a hub; long menus (the keybind sheet) become a
// ledger beside it. ← → ↑ ↓ / Tab select, type to filter, Enter opens or runs, Esc / Backspace /
// right-click go back up a level (and close at the top). Opened with: qs ipc call console toggle
PanelWindow {
    id: root

    // Follows the focused monitor only while hidden: moving a shown window rebuilds its surface
    // (it vanished for a few frames mid-fade on close, when the keyboard grab let go).
    Binding on screen {
        when: !root.visible
        value: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        restoreMode: Binding.RestoreNone
    }
    visible: ConsoleState.open || shown > 0.01

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "observatory-console"
    WlrLayershell.keyboardFocus: ConsoleState.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property real shown: ConsoleState.open ? 1 : 0
    Behavior on shown { NumberAnimation { duration: Theme.slow; easing.type: Theme.easing } }

    // ---------------------------------------------------------------- menus
    property var stack: []          // [{provider, title}]
    property var items: []          // elephant items of the current menu
    property string query: ""
    property int sel: 0
    // Where the pointer last really moved (screen coords): ledger rows that scroll under a still
    // cursor mustn't take the selection, or stepping up past the top of the view jumps back down
    property point pointer: Qt.point(-1, -1)
    property real arrive: 1         // 0 -> 1 each time a menu is shown
    NumberAnimation on arrive { id: arriving; from: 0; to: 1; duration: Theme.slow; easing.type: Theme.easing; running: false }

    readonly property var filtered: {
        const q = query.trim().toLowerCase();
        if (q === "") return items;
        return items.filter(it => (it.text + " " + (it.subtext ?? "")).toLowerCase().includes(q));
    }
    readonly property bool ledger: filtered.length > Theme.consoleRingMax || items.length > Theme.consoleRingMax
    readonly property var current: filtered[Math.min(sel, filtered.length - 1)] ?? null
    readonly property string path: stack.map(s => s.title.toLowerCase()).join("  ›  ")
    onQueryChanged: sel = 0

    function load(provider, title) {
        stack = stack.concat([{ provider: provider, title: title }]);
        show();
    }
    function show() {
        query = "";
        sel = 0;
        items = [];
        query_.command = ["elephant", "query", "--json", `${stack[stack.length - 1].provider};;500;false`];
        query_.running = true;
    }
    function back() {
        if (query !== "") { query = ""; return; }
        if (stack.length <= 1) { ConsoleState.open = false; return; }
        stack = stack.slice(0, -1);
        show();
    }
    function step(d) {
        const n = filtered.length;
        if (n > 0) sel = (sel + d + n) % n;
    }
    function activate(it) {
        if (!it) return;
        const action = (it.actions ?? [])[0] ?? "";
        if (action === "menus:open") {
            // "menus:style::<hash>" opens the menu "menus:style"
            load(it.identifier.split("::")[0], it.text);
            return;
        }
        // Close first so whatever the action opens (the star chart, a Walker prompt) gets the keyboard
        ConsoleState.open = false;
        pending = `${it.provider};${it.identifier};${action};;`;
        runLater.restart();
    }
    property string pending: ""
    Timer {
        id: runLater
        interval: 120
        onTriggered: Quickshell.execDetached(["elephant", "activate", root.pending])
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
                arriving.restart();
            }
        }
    }

    Connections {
        target: ConsoleState
        function onOpenChanged() {
            if (ConsoleState.open) {
                root.stack = [];
                root.load("menus:start", "Menu");
                input.forceActiveFocus();
            }
        }
    }

    // ---------------------------------------------------------------- geometry
    property real ccx: ledger ? width / 2 - Theme.consoleLedgerWidth / 2 - Theme.consoleHub / 2 : width / 2
    Behavior on ccx { NumberAnimation { duration: Theme.slow; easing.type: Theme.easing } }
    readonly property real ccy: height / 2
    readonly property real ringR: Math.max(Theme.consoleRing, filtered.length * Theme.consoleKnobPitch / (2 * Math.PI))
    function knobPos(i, n) {
        const a = -Math.PI / 2 + i / Math.max(1, n) * 2 * Math.PI + (1 - arrive) * -0.45;
        const r = Theme.consoleHub + (ringR - Theme.consoleHub) * (0.55 + 0.45 * arrive);
        return { x: ccx + r * Math.cos(a), y: ccy + r * Math.sin(a), a: a };
    }

    // ---------------------------------------------------------------- backdrop
    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.bgDark, Theme.chartDim * root.shown)
    }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => mouse.button === Qt.RightButton ? root.back() : (ConsoleState.open = false)
    }

    Item {
        id: stage
        anchors.fill: parent
        opacity: root.shown
        scale: 0.95 + 0.05 * root.shown

        // Engraved guide ring and the pointer to the selection
        Item {
            anchors.fill: parent
            Canvas {
                id: guide
                anchors.fill: parent
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const cx = root.ccx, cy = root.ccy;
                    if (!root.ledger) {
                        const r = Theme.consoleHub + (root.ringR - Theme.consoleHub) * (0.55 + 0.45 * root.arrive);
                        ctx.strokeStyle = Theme.alpha(Theme.brass, 0.3 * root.arrive);
                        ctx.lineWidth = 1;
                        ctx.setLineDash([2, 7]);
                        ctx.beginPath(); ctx.arc(cx, cy, r, 0, 2 * Math.PI); ctx.stroke();
                        ctx.setLineDash([]);
                        ctx.strokeStyle = Theme.alpha(Theme.brass, 0.18);
                        ctx.beginPath(); ctx.arc(cx, cy, r + Theme.consoleKnob * 0.9, 0, 2 * Math.PI); ctx.stroke();
                        // degree marks on the outer guide
                        for (let d = 0; d < 360; d += 5) {
                            const a = d * Math.PI / 180, R = r + Theme.consoleKnob * 0.9, big = d % 45 === 0;
                            ctx.strokeStyle = Theme.alpha(Theme.brass, big ? 0.5 : 0.22);
                            ctx.beginPath();
                            ctx.moveTo(cx + R * Math.cos(a), cy + R * Math.sin(a));
                            ctx.lineTo(cx + (R + (big ? 9 : 4)) * Math.cos(a), cy + (R + (big ? 9 : 4)) * Math.sin(a));
                            ctx.stroke();
                        }
                        if (root.current && root.filtered.length > 0) {
                            const p = root.knobPos(Math.min(root.sel, root.filtered.length - 1), root.filtered.length);
                            const a = Math.atan2(p.y - cy, p.x - cx);
                            ctx.strokeStyle = Theme.alpha(Theme.brass, 0.85);
                            ctx.lineWidth = 1.3;
                            ctx.beginPath();
                            ctx.moveTo(cx + Theme.consoleHub * Math.cos(a), cy + Theme.consoleHub * Math.sin(a));
                            ctx.lineTo(p.x - (Theme.consoleKnob / 2 + 6) * Math.cos(a), p.y - (Theme.consoleKnob / 2 + 6) * Math.sin(a));
                            ctx.stroke();
                        }
                    } else if (root.current) {
                        // ledger: a bracket from the hub to the selected row
                        const row = ledgerView.itemAtIndex(root.sel);
                        if (row) {
                            const pt = row.mapToItem(guide, 0, row.height / 2);
                            ctx.strokeStyle = Theme.alpha(Theme.brass, 0.8);
                            ctx.lineWidth = 1.2;
                            ctx.beginPath();
                            ctx.moveTo(cx + Theme.consoleHub, cy);
                            ctx.bezierCurveTo(cx + Theme.consoleHub + 40, cy, pt.x - 50, pt.y, pt.x - 6, pt.y);
                            ctx.stroke();
                        }
                    }
                }
                Connections {
                    target: root
                    function onArriveChanged() { guide.requestPaint(); }
                    function onSelChanged() { guide.requestPaint(); }
                    function onFilteredChanged() { guide.requestPaint(); }
                    function onCcxChanged() { guide.requestPaint(); }
                    function onLedgerChanged() { guide.requestPaint(); }
                }
            }
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true; shadowColor: Theme.brass; shadowBlur: 0.4; shadowOpacity: 0.7
                shadowHorizontalOffset: 0; shadowVerticalOffset: 0; blurMax: 12
            }
        }

        // ---------------------------------------------------------------- ring of instruments
        Repeater {
            model: root.ledger ? [] : root.filtered

            Item {
                id: knob
                required property var modelData
                required property int index
                readonly property var p: root.knobPos(index, root.filtered.length)
                readonly property bool active: index === root.sel
                x: p.x
                y: p.y
                opacity: root.arrive

                Rectangle {
                    id: face
                    property real d: Theme.consoleKnob * (knob.active ? 1.1 : 1)
                    x: -d / 2
                    y: -d / 2
                    width: d
                    height: d
                    radius: d / 2
                    color: knob.active ? Theme.alpha(Theme.brassMuted, 0.95) : Theme.alpha(Theme.bgDark, 0.92)
                    border.width: knob.active ? 2 : 1
                    border.color: knob.active ? Theme.brassBright : Theme.brass
                    Behavior on d { NumberAnimation { duration: Theme.fast; easing.type: Theme.easing } }
                    Behavior on color { ColorAnimation { duration: Theme.fast } }

                    // inner ring, like a bezel
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 4
                        radius: width / 2
                        color: "transparent"
                        border.width: 0.8
                        border.color: Theme.alpha(Theme.brass, 0.35)
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: !iconImg.visible
                        text: knob.modelData.icon ?? ""
                        color: knob.active ? Theme.starlight : Theme.brass
                        font.family: Theme.fontData
                        font.pixelSize: Theme.consoleGlyph
                    }
                    IconImage {
                        id: iconImg
                        anchors.centerIn: parent
                        readonly property string ic: knob.modelData.icon ?? ""
                        visible: ic.length > 2 && (ic.startsWith("/") || Quickshell.hasThemeIcon(ic))
                        implicitSize: Theme.consoleGlyph + 6
                        source: visible ? (ic.startsWith("/") ? "file://" + ic : Quickshell.iconPath(ic)) : ""
                    }

                    layer.enabled: knob.active
                    layer.effect: MultiEffect {
                        shadowEnabled: true; shadowColor: Theme.brass; shadowBlur: 0.7; shadowOpacity: 0.9
                        shadowHorizontalOffset: 0; shadowVerticalOffset: 0; blurMax: 20
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Theme.consoleKnob / 2 + 8
                    width: Theme.consoleLabel
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: knob.modelData.text.replace(/^[●\s]+/, "").toLowerCase()
                    color: knob.active ? Theme.brassBright : Theme.fg
                    font.family: Theme.fontLabel
                    font.pixelSize: Theme.labelSize + 2
                    font.capitalization: Font.SmallCaps
                    font.letterSpacing: Theme.labelSpacing
                    font.weight: Font.DemiBold
                }
                MouseArea {
                    x: -Theme.consoleKnob / 2; y: -Theme.consoleKnob / 2
                    width: Theme.consoleKnob; height: Theme.consoleKnob + 26
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onEntered: root.sel = knob.index
                    onClicked: mouse => mouse.button === Qt.RightButton ? root.back() : root.activate(knob.modelData)
                }
            }
        }

        // ---------------------------------------------------------------- ledger (long menus)
        Item {
            id: ledgerPlate
            visible: root.ledger
            opacity: root.arrive
            x: root.ccx + Theme.consoleHub + 70
            y: root.ccy - height / 2
            width: Theme.consoleLedgerWidth
            height: Math.min(root.height * 0.72, ledgerView.contentHeight + 28)

            Rectangle {
                anchors.fill: parent
                color: Theme.alpha(Theme.bgDark, 0.92)
                border.width: 1
                border.color: Theme.alpha(Theme.brass, 0.7)
            }
            ListView {
                id: ledgerView
                anchors.fill: parent
                anchors.margins: 14
                clip: true
                model: root.ledger ? root.filtered : []
                currentIndex: root.sel
                highlightMoveDuration: Theme.fast
                highlightFollowsCurrentItem: true
                onContentYChanged: guide.requestPaint()
                highlight: Rectangle {
                    color: Theme.alpha(Theme.brassMuted, 0.6)
                    Rectangle { width: 2; height: parent.height; color: Theme.brassBright }
                }
                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    width: ledgerView.width
                    height: 30
                    Text {
                        id: glyph
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        text: row.modelData.icon?.length <= 2 ? row.modelData.icon : "·"
                        color: Theme.brass
                        font.family: Theme.fontData
                        font.pixelSize: Theme.dataSize + 2
                    }
                    Text {
                        anchors.left: glyph.right
                        anchors.leftMargin: 8
                        anchors.right: sub.left
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: row.modelData.text
                        color: row.index === root.sel ? Theme.starlight : Theme.fg
                        font.family: Theme.fontData
                        font.pixelSize: Theme.dataSize
                    }
                    Text {
                        id: sub
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, parent.width * 0.45)
                        elide: Text.ElideLeft
                        text: row.modelData.subtext ?? ""
                        color: Theme.phosphor
                        font.family: Theme.fontData
                        font.pixelSize: Theme.dataSizeSmall + 1
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onPositionChanged: mouse => { const p = mapToGlobal(mouse.x, mouse.y); if (p.x !== root.pointer.x || p.y !== root.pointer.y) { root.pointer = p; root.sel = row.index; } }
                        onClicked: mouse => mouse.button === Qt.RightButton ? root.back() : root.activate(row.modelData)
                    }
                }
            }
        }

        // ---------------------------------------------------------------- the hub
        Item {
            id: hub
            x: root.ccx - Theme.consoleHub
            y: root.ccy - Theme.consoleHub
            width: Theme.consoleHub * 2
            height: Theme.consoleHub * 2

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => { if (mouse.button === Qt.RightButton) root.back(); }
            }
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Theme.alpha(Theme.bgDark, 0.96)
                border.width: 1.6
                border.color: Theme.brass
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: 7
                radius: width / 2
                color: "transparent"
                border.width: 0.8
                border.color: Theme.alpha(Theme.brass, 0.35)
            }

            Column {
                anchors.centerIn: parent
                width: parent.width * 0.76
                spacing: 6

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideLeft
                    text: root.path
                    color: Theme.brass
                    font.family: Theme.fontLabel
                    font.pixelSize: Theme.labelSize
                    font.capitalization: Font.SmallCaps
                    font.letterSpacing: Theme.labelSpacing
                    font.weight: Font.DemiBold
                }
                Rectangle { width: parent.width; height: 1; color: Theme.alpha(Theme.brass, 0.3) }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: root.current ? root.current.text.replace(/^[●\s]+/, "")
                        : root.items.length ? "no match" : "…"
                    color: root.current ? Theme.brassBright : Theme.dim
                    font.family: Theme.fontLabel
                    font.pixelSize: Theme.labelSizeLarge + 6
                    font.weight: Font.DemiBold
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    visible: text !== ""
                    text: root.current?.subtext ?? ""
                    color: Theme.dim
                    font.family: Theme.fontData
                    font.pixelSize: Theme.dataSizeSmall + 1
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.query !== "" ? root.query + "▌" : ((root.current?.actions ?? [])[0] === "menus:open" ? "enter  ›  open" : "enter  ›  run")
                    color: root.query !== "" ? Theme.phosphor : Theme.alpha(Theme.dim, 0.8)
                    font.family: Theme.fontData
                    font.pixelSize: root.query !== "" ? Theme.dataSize + 3 : Theme.dataSizeSmall
                }
            }
        }
    }

    // ---------------------------------------------------------------- keyboard
    TextInput {
        id: input
        opacity: 0
        width: 1
        height: 1
        focus: ConsoleState.open
        text: root.query
        onTextEdited: root.query = text
        Keys.onPressed: event => {
            const k = event.key;
            if (k === Qt.Key_Escape) root.back();
            else if (k === Qt.Key_Backspace && root.query === "") root.back();
            else if (k === Qt.Key_Return || k === Qt.Key_Enter) root.activate(root.current);
            else if (k === Qt.Key_Right || k === Qt.Key_Down || (k === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier))) root.step(1);
            else if (k === Qt.Key_Left || k === Qt.Key_Up || k === Qt.Key_Backtab) root.step(-1);
            else return;
            event.accepted = true;
        }
    }
}
