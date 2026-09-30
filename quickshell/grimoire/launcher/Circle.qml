import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import "../theme"
import "../widgets"
import "../utilities"

// The seal-book: Grimoire's app launcher (SUPER + CTRL + Space). Nothing on screen but what you've
// written, small at the top, and in the middle the seal of the program it finds, drawn out in gold. Every program has its own seal
// and every part of it means something (launcher/seal.js): the sigil in the middle says what kind of
// program it is, the signs round it what it does, the tick band counts its name's letters, and a
// seal you summon often is drawn with more rings. Enter closes the ring: the seal glows and the
// program is summoned. ↑ ↓ step through the other matches (redrawing the seal), Esc dismisses; nothing matching, Enter runs what you wrote.
// (Its IPC is still `circle`, as setup.toml and older notes call it.)
//   qs ipc call circle toggle | type <words> | cast
PanelWindow {
    id: root

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
    // nothing written, nothing chosen: no seal until the first key
    readonly property var chosen: query.trim() === "" ? null : (results[pick] ?? null)
    onQueryChanged: pick = 0
    onResultsChanged: if (pick >= results.length) pick = 0

    // the seal follows the choice a moment later, so typing quickly doesn't restart it on every key
    property var sealed: null
    onChosenChanged: settle.restart()
    Timer { id: settle; interval: 90; onTriggered: root.sealed = root.chosen }

    FileView {
        id: usage
        path: Quickshell.statePath("circle-launches.json")
        printErrors: false
        onLoaded: { try { root.launches = JSON.parse(text()); } catch (e) {} }
    }

    // ---------------------------------------------------------------- casting
    property bool casting: false
    function cast() {
        if (casting) return;
        const a = chosen;
        const q = query.trim();
        if (!a && !q) { CircleState.open = false; return; }
        if (a) {
            settle.stop();
            root.sealed = a;
            const counts = Object.assign({}, launches);
            counts[a.id] = (counts[a.id] ?? 0) + 1;
            launches = counts;
            usage.setText(JSON.stringify(launches));
            a.execute();
            casting = true;
            castAnim.restart();
        } else {
            Quickshell.execDetached(["sh", "-c", q]);
            CircleState.open = false;
        }
    }
    // the ring closes and the seal glows (the program is already starting), then it's gone
    SequentialAnimation {
        id: castAnim
        PropertyAction { target: seal; property: "drawn"; value: 1 }
        PauseAnimation { duration: 480 }
        ScriptAction { script: CircleState.open = false }
        PauseAnimation { duration: Theme.normal }
        ScriptAction { script: root.casting = false }
    }

    Connections {
        target: CircleState
        function onTyped(text) { input.text = text; root.query = text; }
        function onCastRequested() { root.cast(); }
        function onOpenChanged() {
            if (CircleState.open) {
                castAnim.stop();
                root.casting = false;
                root.query = "";
                root.pick = 0;
                input.text = "";
                input.forceActiveFocus();
                usage.reload();
                root.sealed = null;
                settle.restart();
            }
        }
    }

    Item {
        id: body
        anchors.fill: parent

        Rectangle { anchors.fill: parent; color: Theme.alpha(Theme.mix(Theme.veil, "#000000", 0.4), 0.72 * root.shown) }
        MouseArea { anchors.fill: parent; onClicked: CircleState.open = false }

        // what you've written, small, at the top middle (the keys go to a hidden input)
        TextInput {
            id: input
            width: 1; height: 1
            opacity: 0
            focus: true
            onTextEdited: root.query = text
            Keys.onPressed: e => {
                const n = root.results.length;
                if (e.key === Qt.Key_Escape) CircleState.open = false;
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.cast();
                else if (e.key === Qt.Key_Down || e.key === Qt.Key_Tab || e.key === Qt.Key_Right) root.pick = n ? (root.pick + 1) % n : 0;
                else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab || e.key === Qt.Key_Left) root.pick = n ? (root.pick - 1 + n) % n : 0;
                else return;
                e.accepted = true;
            }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(root.height * 0.07)
            opacity: root.shown
            spacing: 2
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.query.toLowerCase()
                color: Theme.goldBright
                font.family: Theme.body
                font.italic: true
                font.pixelSize: 16
                font.letterSpacing: 1.5
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1.5; height: 16
                color: Theme.gold
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.1; duration: 650; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 650; easing.type: Easing.InOutSine }
                }
            }
        }

        // the seal, in the middle, drawn in gold ink on the dark
        SealView {
            id: seal
            readonly property real d: Math.min(560, root.height * 0.58, root.width * 0.8)
            width: d; height: d
            anchors.centerIn: parent
            opacity: root.shown
            scale: 0.97 + 0.03 * root.shown
            app: root.sealed
            uses: root.sealed ? (root.launches[root.sealed.id] ?? 0) : 0
            closed: root.casting
            ink: Theme.goldBright
            glowColor: Theme.gold
        }
    }
}
