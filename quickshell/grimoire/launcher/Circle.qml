import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import "../theme"
import "../widgets"
import "../utilities"

// The index: Grimoire's app launcher (SUPER + CTRL + Space). The desk blurs and dims, and a slim
// leaf of black leather comes down from above: a line to write on, and under it the programs that
// answer, the likeliest first (the ones you summon most rise to the top). ↑ ↓ choose, Enter
// summons, Esc dismisses; nothing matching, Enter runs what you wrote as a command.
// (Its IPC is still called `circle`: the setup's [menus] and older notes call it by that name.)
//   qs ipc call circle toggle | type <words> | cast
PanelWindow {
    id: root

    // Follows the focused monitor only while hidden (moving a shown window rebuilds its surface)
    Binding on screen {
        when: !root.visible
        value: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        restoreMode: Binding.RestoreNone
    }
    visible: CircleState.open || shown > 0.01

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "grimoire-circle"
    WlrLayershell.keyboardFocus: CircleState.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: CircleState.open ? null : noInput
    Region { id: noInput }

    property real shown: CircleState.open ? 1 : 0
    Behavior on shown { NumberAnimation { duration: CircleState.open ? Theme.normal : Theme.fast; easing.type: Theme.easing } }

    Connections {
        target: Debug
        function onGrab(what, path) { if (what === "circle") body.grabToImage(r => r.saveToFile(path)); }
    }

    // ---------------------------------------------------------------- the programs
    readonly property var apps: DesktopEntries.applications.values.filter(a => !a.noDisplay).sort((a, b) => a.name.localeCompare(b.name))
    readonly property int rows: 7
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
        if (q === "")
            return apps.slice().sort((a, b) => boost(b) - boost(a) || a.name.localeCompare(b.name)).slice(0, rows);
        return apps.map(a => ({ a: a, s: match(a, q) })).filter(m => m.s > 0)
            .map(m => Object.assign(m, { s: m.s + boost(m.a) }))
            .sort((x, y) => y.s - x.s || x.a.name.localeCompare(y.a.name)).slice(0, rows).map(m => m.a);
    }
    readonly property var chosen: results[pick] ?? null
    onQueryChanged: pick = 0
    onResultsChanged: if (pick >= results.length) pick = 0

    FileView {
        id: usage
        path: Quickshell.statePath("circle-launches.json")
        printErrors: false
        onLoaded: { try { root.launches = JSON.parse(text()); } catch (e) {} }
    }

    function iconFor(a) { return Quickshell.iconPath(a?.icon || "application-x-executable", "application-x-executable"); }

    // summon the chosen program (or run what was written), then go
    function cast() {
        const a = chosen;
        const q = query.trim();
        CircleState.open = false;
        if (a) {
            const counts = Object.assign({}, launches);
            counts[a.id] = (counts[a.id] ?? 0) + 1;
            launches = counts;
            usage.setText(JSON.stringify(launches));
            a.execute();
        } else if (q) Quickshell.execDetached(["sh", "-c", q]);
    }

    Connections {
        target: CircleState
        function onTyped(text) { input.text = text; root.query = text; }
        function onCastRequested() { root.cast(); }
        function onOpenChanged() {
            if (CircleState.open) {
                root.query = "";
                root.pick = 0;
                input.text = "";
                input.forceActiveFocus();
                usage.reload();
            }
        }
    }

    Item {
        id: body
        anchors.fill: parent

        Rectangle { anchors.fill: parent; color: Theme.alpha(Theme.mix(Theme.veil, "#000000", 0.3), 0.55 * root.shown) }
        MouseArea { anchors.fill: parent; onClicked: CircleState.open = false }

        // ---------------------------------------------------------------- the leaf
        Item {
            id: leaf
            width: Math.min(640, root.width - 48)
            height: 86 + list.height + 56
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(root.height * 0.2) - (1 - root.shown) * 14
            opacity: root.shown

            MouseArea { anchors.fill: parent }

            Rectangle {
                anchors.fill: parent
                anchors.topMargin: 12
                anchors.bottomMargin: -22
                anchors.leftMargin: 2
                anchors.rightMargin: -6
                radius: 16
                color: Qt.alpha("#000000", 0.55)
                layer.enabled: true
                layer.effect: MultiEffect { blurEnabled: true; blur: 1; blurMax: 40 }
            }
            Leather { anchors.fill: parent; radius: 12; tooled: false; color: Theme.mix(Theme.leatherDark, "#000000", 0.3); seed: 0.47 }
            Rectangle { anchors.fill: parent; radius: 12; color: "transparent"; border.width: 1; border.color: Theme.alpha(Theme.goldDeep, 0.9) }
            Rectangle { anchors.fill: parent; anchors.margins: 6; radius: 8; color: "transparent"; border.width: 1; border.color: Theme.alpha(Theme.gold, 0.35) }

            // ------------------------------------------------------------ the line to write on
            Item {
                id: line
                x: 30
                width: parent.width - 60
                height: 78
                Text {
                    id: sigil
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 3
                    text: "✦"
                    color: Theme.gold
                    font.family: Theme.symbols
                    font.pixelSize: 16
                }
                TextInput {
                    id: input
                    anchors.left: sigil.right
                    anchors.leftMargin: 16
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 3
                    color: Theme.goldBright
                    selectionColor: Theme.alpha(Theme.gold, 0.4)
                    font.family: Theme.body
                    font.italic: true
                    font.pixelSize: 25
                    focus: true
                    cursorDelegate: Rectangle {
                        width: 2
                        color: Theme.gold
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.15; duration: 650; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1; duration: 650; easing.type: Easing.InOutSine }
                        }
                    }
                    onTextEdited: root.query = text
                    Keys.onPressed: e => {
                        const n = root.results.length;
                        if (e.key === Qt.Key_Escape) CircleState.open = false;
                        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.cast();
                        else if (e.key === Qt.Key_Down || e.key === Qt.Key_Tab) root.pick = n ? (root.pick + 1) % n : 0;
                        else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab) root.pick = n ? (root.pick - 1 + n) % n : 0;
                        else return;
                        e.accepted = true;
                    }
                    Body {
                        visible: input.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Summon…"
                        italic: true
                        color: Theme.alpha(Theme.dim, 0.7)
                        font.pixelSize: 25
                    }
                }
            }
            // a gilt rule under it, fading out at both ends
            Rectangle {
                x: 24
                y: line.height
                width: parent.width - 48
                height: 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 0.5; color: Theme.alpha(Theme.gold, 0.7) }
                    GradientStop { position: 1; color: "transparent" }
                }
            }

            // ------------------------------------------------------------ what answers
            ListView {
                id: list
                x: 14
                y: line.height + 10
                width: parent.width - 28
                height: Math.max(1, count) * 50
                interactive: false
                model: root.results.length ? root.results : root.query.trim() ? [null] : []
                currentIndex: root.pick
                highlightMoveDuration: Theme.fast
                highlight: Item {
                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: Theme.alpha(Theme.gold, 0.16) }
                            GradientStop { position: 1; color: Theme.alpha(Theme.gold, 0.02) }
                        }
                    }
                    Rectangle { x: 0; width: 2; height: parent.height - 16; anchors.verticalCenter: parent.verticalCenter; color: Theme.gold }
                }
                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool here: ListView.isCurrentItem
                    width: list.width
                    height: 50

                    Image {
                        id: icon
                        x: 18
                        anchors.verticalCenter: parent.verticalCenter
                        width: 30; height: 30
                        sourceSize: Qt.size(60, 60)
                        source: row.modelData ? root.iconFor(row.modelData) : ""
                        visible: !!row.modelData
                        opacity: row.here ? 1 : 0.8
                    }
                    Text {
                        visible: !row.modelData
                        anchors.centerIn: icon
                        text: "\u{f018d}"
                        color: Theme.gold
                        font.family: Theme.glyphs
                        font.pixelSize: 22
                    }
                    Body {
                        id: name
                        x: 64
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, parent.width - x - 20)
                        elide: Text.ElideRight
                        text: row.modelData ? row.modelData.name : "Run “" + root.query.trim() + "”"
                        color: row.here ? Theme.goldBright : Theme.fg
                        font.pixelSize: 18
                    }
                    Body {
                        anchors.left: name.right
                        anchors.leftMargin: 14
                        anchors.right: parent.right
                        anchors.rightMargin: 18
                        anchors.baseline: name.baseline
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                        text: row.modelData ? (row.modelData.genericName || row.modelData.comment || "") : "as a command"
                        italic: true
                        color: Theme.alpha(Theme.dim, row.here ? 0.9 : 0.6)
                        font.pixelSize: 14
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.pick = row.index
                        onClicked: { root.pick = row.index; root.cast(); }
                    }
                }
            }
            Body {
                visible: list.count === 0
                anchors.horizontalCenter: parent.horizontalCenter
                y: list.y + 12
                text: "nothing answers"
                italic: true
                color: Theme.alpha(Theme.dim, 0.6)
            }

            Caps {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 16
                text: "↑ ↓  choose   ·   enter  summons   ·   esc  dismisses"
                color: Theme.alpha(Theme.gold, 0.45)
                font.pixelSize: 10
                font.letterSpacing: 3
            }
        }
    }
}
