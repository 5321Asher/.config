import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../theme"
import "../widgets"

// The index (SUPER + Space): Glyph's root menu, as a rotary dial. The screen goes almost black; on
// the left a column of words in Doto turns like a dial, the selected word big with the red dot,
// its neighbours smaller and dimmer the further they are. On the right a ring of dots, one per
// entry, with the selected one lit, and the entry's glyph drawn as a dot matrix in the middle.
// ↑↓ / wheel turn, → / Enter open a menu (the column slides away and the next one turns in),
// ← / right-click go back, Enter runs, typing filters, Esc closes. State: IndexState.
PanelWindow {
    id: root

    Binding on screen {
        when: !root.visible
        value: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        restoreMode: Binding.RestoreNone
    }
    readonly property real s: Theme.scaleFor(screen)

    property real t: IndexState.open ? 1 : 0
    Behavior on t { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
    visible: t > 0

    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: IndexState.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "glyph-index"

    readonly property var level: IndexState.level
    property string filter: ""
    readonly property var items: {
        const all = (level?.items ?? []).map((it, i) => Object.assign({ i: i }, it));
        const q = filter.trim().toLowerCase();
        return q ? all.filter(it => it.text.toLowerCase().includes(q) || (it.sub ?? "").toLowerCase().includes(q)) : all;
    }
    property int sel: 0
    readonly property var cur: items[Math.min(sel, items.length - 1)] ?? null
    onItemsChanged: sel = Math.max(0, Math.min(sel, items.length - 1))
    onFilterChanged: sel = 0

    // a new level slides in from the right, going back slides in from the left
    property int depth: IndexState.stack.length
    property int dir: 1
    onDepthChanged: { filter = ""; sel = IndexState.level?.sel ?? 0; slide.restart(); }
    NumberAnimation { id: slide; target: col; property: "shift"; from: 1; to: 0; duration: Theme.t + 100; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide }

    Connections {
        target: IndexState
        function onOpenChanged() {
            if (!IndexState.open) return;
            root.filter = "";
            root.sel = 0;
            keys.forceActiveFocus();
        }
        function onStackChanged() {
            const d = IndexState.stack.length;
            root.dir = d >= root.depth ? 1 : -1;
        }
    }

    function go(d) {
        if (!items.length) return;
        sel = (sel + d + items.length) % items.length;
    }
    function enter() {
        if (!cur) return;
        IndexState.select(cur.i);
        IndexState.enter(cur.i);
    }
    function back() {
        if (filter) { filter = ""; return; }
        IndexState.back();
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.fade(Theme.bg, 0.96)
        opacity: root.t
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: e => e.button === Qt.RightButton ? root.back() : IndexState.close()
            onWheel: e => root.go(e.angleDelta.y > 0 ? -1 : 1)
        }
    }

    FocusScope {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: e => {
            const k = e.key;
            if (k === Qt.Key_Escape) IndexState.close();
            else if (k === Qt.Key_Up || (k === Qt.Key_K && e.modifiers & Qt.ControlModifier) || k === Qt.Key_Backtab) root.go(-1);
            else if (k === Qt.Key_Down || (k === Qt.Key_J && e.modifiers & Qt.ControlModifier) || k === Qt.Key_Tab) root.go(1);
            else if (k === Qt.Key_PageUp) root.go(-5);
            else if (k === Qt.Key_PageDown) root.go(5);
            else if (k === Qt.Key_Right || k === Qt.Key_Return || k === Qt.Key_Enter) root.enter();
            else if (k === Qt.Key_Left) root.back();
            else if (k === Qt.Key_Backspace) { if (root.filter) root.filter = root.filter.slice(0, -1); else root.back(); }
            else if (e.text && e.text.charCodeAt(0) > 32 && !(e.modifiers & Qt.ControlModifier)) root.filter += e.text;
            else if (e.text === " " && root.filter) root.filter += " ";
            else return;
            e.accepted = true;
        }
    }

    Stage {
        id: stage
        s: root.s
        opacity: root.t
        readonly property bool wide: width >= 1500
        readonly property real dialSize: wide ? 460 : 300
        readonly property real lx: wide ? 240 : 80

        // the path, top left: INDEX · STYLE · THEME, then the filter while typing
        Row {
            x: stage.lx
            y: 92
            spacing: 18
            Ring { anchors.verticalCenter: parent.verticalCenter; width: 22; height: 22; n: 12; dot: 2.5 }
            Repeater {
                model: IndexState.path
                Row {
                    required property string modelData
                    required property int index
                    spacing: 18
                    Lb { visible: index > 0; text: "·"; anchors.verticalCenter: parent.verticalCenter }
                    Lb {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData
                        px: 13
                        color: index === IndexState.path.length - 1 ? Theme.fg : Theme.grey
                    }
                }
            }
            Lb { visible: root.filter !== ""; anchors.verticalCenter: parent.verticalCenter; text: "·   filter"; px: 13 }
            Text {
                visible: root.filter !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: root.filter
                font { family: Theme.ui; pixelSize: 20 }
                color: Theme.fg
                Rectangle { anchors { left: parent.right; leftMargin: 3; verticalCenter: parent.verticalCenter } width: 2; height: 22; color: Theme.red }
            }
        }

        // the dial of words
        Item {
            id: col
            property real shift: 0
            x: stage.lx + 80 * shift * root.dir
            y: 0
            width: stage.width - stage.lx - stage.dialSize - (stage.wide ? 200 : 60) - 60
            height: stage.height
            opacity: 1 - shift
            clip: false

            ListView {
                id: list
                anchors.fill: parent
                anchors.topMargin: 150
                anchors.bottomMargin: 150
                model: root.items.length
                currentIndex: root.sel
                interactive: false
                highlightRangeMode: ListView.StrictlyEnforceRange
                preferredHighlightBegin: height / 2 - 80
                preferredHighlightEnd: height / 2 + 80
                highlightMoveDuration: Theme.t
                highlightMoveVelocity: -1
                spacing: 18
                clip: true

                delegate: Item {
                    id: row
                    required property int index
                    readonly property var it: root.items[index] ?? ({ text: "" })
                    readonly property int d: Math.abs(index - root.sel)
                    readonly property bool on: d === 0
                    width: list.width
                    height: word.height
                    opacity: d >= 6 ? 0 : 1 - Math.max(0, d - 3) * 0.3
                    Behavior on opacity { NumberAnimation { duration: Theme.t } }

                    Rectangle {
                        id: red
                        anchors.verticalCenter: word.verticalCenter
                        width: 30
                        height: 30
                        radius: 15
                        color: Theme.red
                        scale: row.on ? 1 : 0
                        Behavior on scale { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
                    }
                    Num {
                        id: word
                        x: row.on ? 60 : 0
                        width: list.width - x
                        text: row.it.text.toUpperCase()
                        fontSizeMode: Text.HorizontalFit
                        minimumPixelSize: 30
                        elide: Text.ElideRight
                        font.pixelSize: row.d === 0 ? 150 : row.d === 1 ? 66 : row.d === 2 ? 54 : 46
                        color: row.on ? Theme.fg : row.it.on ? Theme.grey : Theme.mute
                        Behavior on font.pixelSize { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
                        Behavior on x { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
                        Behavior on color { ColorAnimation { duration: Theme.t } }
                    }
                    // an entry that's "on" (the current theme, a running toggle): a small white dot
                    Rectangle {
                        visible: !!row.it.on && !row.on
                        anchors { right: word.left; rightMargin: 14; verticalCenter: word.verticalCenter }
                        x: -20
                        width: 10
                        height: 10
                        radius: 5
                        color: Theme.fg
                    }
                    MouseArea {
                        anchors.fill: word
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: e => {
                            if (e.button === Qt.RightButton) root.back();
                            else if (row.on) root.enter();
                            else root.sel = row.index;
                        }
                        onWheel: e => root.go(e.angleDelta.y > 0 ? -1 : 1)
                    }
                }
            }

            // nothing (yet)
            Num {
                visible: IndexState.level?.loading || root.items.length === 0
                anchors.verticalCenter: parent.verticalCenter
                text: IndexState.level?.loading ? "· · ·" : "NOTHING"
                font.pixelSize: 110
                color: Theme.mute
                SequentialAnimation on opacity {
                    running: IndexState.level?.loading ?? false
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 500 }
                    NumberAnimation { to: 1; duration: 500 }
                }
            }
        }

        // the dial: one dot per entry (the selected one lit), the entry's glyph as dots inside
        Item {
            id: dial
            x: stage.width - (stage.wide ? 200 : 60) - stage.dialSize
            anchors.verticalCenter: parent.verticalCenter
            width: stage.dialSize
            height: stage.dialSize
            readonly property int n: Math.max(12, Math.min(60, root.items.length))
            readonly property int at: root.items.length ? Math.round(root.sel / Math.max(1, root.items.length) * n) % n : -1

            Repeater {
                model: dial.n
                Rectangle {
                    required property int index
                    readonly property real a: index / dial.n * 2 * Math.PI - Math.PI / 2
                    readonly property bool lit: index === dial.at
                    readonly property bool real_: index < root.items.length || root.items.length > dial.n
                    x: dial.width / 2 * (1 + Math.cos(a)) - width / 2
                    y: dial.height / 2 * (1 + Math.sin(a)) - height / 2
                    width: lit ? 18 : 10
                    height: width
                    radius: width / 2
                    color: lit ? Theme.fg : real_ ? Theme.s3 : Theme.s2
                    Behavior on width { NumberAnimation { duration: Theme.t } }
                }
            }

            Column {
                anchors.centerIn: parent
                width: parent.width * 0.62
                spacing: 18
                Icon {
                    id: glyph
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.cur?.glyph && root.cur.glyph.length <= 2 ? root.cur.glyph : root.cur?.open ? "\u{F024B}" : "\u{F0412}"
                    font.pixelSize: stage.dialSize * 0.3
                    layer.enabled: true
                    layer.effect: Dm { step: stage.dialSize / 76 }
                }
                Lb {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    text: root.cur?.sub || root.cur?.text || ""
                    px: 12
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: hint.width + 36
                    height: 36
                    radius: 18
                    color: root.cur?.on ? Theme.fg : Theme.s2
                    Lb {
                        id: hint
                        anchors.centerIn: parent
                        text: root.cur?.on ? "active" : root.cur?.open ? "→ open" : "↵ run"
                        px: 11
                        color: root.cur?.on ? Theme.ink : Theme.fg
                    }
                }
            }
            // where in the list: "07 / 23" under the ring
            Lb {
                anchors { horizontalCenter: parent.horizontalCenter; top: parent.bottom; topMargin: 34 }
                text: root.items.length ? `${String(root.sel + 1).padStart(2, "0")} / ${String(root.items.length).padStart(2, "0")}` : ""
                px: 12
            }
        }

        Row {
            x: stage.lx
            anchors { bottom: parent.bottom; bottomMargin: 70 }
            spacing: 34
            Lb { text: "↑↓ turn" }
            Lb { text: "→ open" }
            Lb { text: "← back" }
            Lb { text: "↵ run" }
            Lb { text: "type to filter" }
            Lb { text: "esc close" }
        }
    }
}
