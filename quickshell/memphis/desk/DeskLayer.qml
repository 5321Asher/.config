import QtQuick
import Quickshell
import Quickshell.Wayland
import "../theme"
import "windows"
import "applets"

// Draws the shell's windows (Desk.wins) for one screen. It's a layer surface over the whole
// screen, above application windows, but it only takes input where a window is (the mask), so
// the rest of the desktop works as usual. The keyboard follows a click (or, for Run / Shut Down,
// comes straight here).
PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    readonly property var mine: Desk.ids.filter(id => Desk.wins[id].screen === modelData.name)
    readonly property bool grabbing: Desk.wantsKeys && mine.includes(Desk.top)

    visible: mine.length > 0
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Normal
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "memphis-desk"
    WlrLayershell.keyboardFocus: grabbing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand

    // Where a window goes: where it was dragged, else centred (cascading a little per window)
    function place(id) {
        const w = Desk.wins[id];
        if (!w) return { x: 0, y: 0, w: 0, h: 0 };
        // the screen's size, not the layer's (which is 0 until it's first mapped)
        const W = modelData.width, H = modelData.height - Theme.taskbarHeight;
        const n = mine.indexOf(id);
        // x / y are null until the window is first shown (then pinned where it appeared)
        const x = w.x ?? Math.round((W - w.w) / 2 + (n % 5) * 26 - 52);
        const y = w.y ?? Math.round((H - w.h) / 2 + (n % 5) * 26 - 52);
        const p = clampPos(x, y, w.w);
        return { x: p.x, y: p.y, w: w.w, h: w.h };
    }
    // The one rule for where a window may be (placing and dragging both use it): at least 80 px of
    // it stays on screen sideways, and its caption stays between the top edge and the taskbar
    function clampPos(x, y, w) {
        const W = modelData.width, H = modelData.height - Theme.taskbarHeight;
        return {
            x: Math.round(Math.max(80 - w, Math.min(W - 80, x))),
            y: Math.round(Math.max(0, Math.min(H - Theme.titleHeight - 8, y)))
        };
    }

    mask: Region { regions: regionList.instances }
    Variants {
        id: regionList
        model: root.mine
        Region {
            required property var modelData
            readonly property var g: root.place(modelData)
            x: g.x; y: g.y; width: g.w; height: g.h
        }
    }

    // ScriptModel keeps each window's delegate while others open, close, move or rise
    Repeater {
        model: ScriptModel { values: root.mine }

        Item {
            id: slot
            required property var modelData
            readonly property string wid: modelData
            property point dragFrom         // where the window was when its caption was pressed
            readonly property var g: root.place(wid)
            x: g.x
            y: g.y
            z: Desk.wins[wid]?.z ?? 0
            width: g.w
            height: g.h
            // pin the centred spot on first showing, so a window that grows (Run) grows downwards
            Component.onCompleted: if ((Desk.wins[wid]?.x ?? null) === null) Qt.callLater(() => Desk.moveTo(wid, g.x, g.y))

            Loader {
                id: loader
                anchors.fill: parent
                sourceComponent: {
                    const id = slot.wid;
                    if (id.startsWith("applet:")) return applets[id.slice(7)] ?? null;
                    return windows[id] ?? null;
                }
                onLoaded: if (Desk.top === slot.wid) item.forceActiveFocus()
            }
            Binding { target: loader.item; property: "active"; value: Desk.top === slot.wid; when: loader.item !== null }
            Binding { target: loader.item; property: "tab"; value: Desk.wins[slot.wid]?.tab ?? ""; when: loader.item !== null && loader.item.tab !== undefined }
            Connections {
                target: loader.item
                ignoreUnknownSignals: true
                function onCloseRequested() { Desk.close(slot.wid); }
                function onPressed() { Desk.raise(slot.wid); }
                function onDragStarted() { slot.dragFrom = Qt.point(slot.x, slot.y); }
                function onDragBy(dx, dy) {
                    const p = root.clampPos(slot.dragFrom.x + dx, slot.dragFrom.y + dy, slot.width);
                    Desk.moveTo(slot.wid, p.x, p.y);
                }
            }
            Connections {
                target: Desk
                function onTopChanged() { if (Desk.top === slot.wid && loader.item) loader.item.forceActiveFocus(); }
            }
        }
    }

    // Window ids -> their components (as types, so live reload sees edits)
    readonly property var windows: ({
        control: controlWin, run: runWin, shutdown: shutdownWin, logoff: logoffWin, help: helpWin,
        messages: messagesWin, media: mediaWin, volume: volumeWin, monitorkeep: monitorKeepWin,
    })
    readonly property var applets: ({
        datetime: datetimeApplet, display: displayApplet, multimedia: multimediaApplet, network: networkApplet,
        system: systemApplet, lighting: lightingApplet, timer: timerApplet, claude: claudeApplet, power: powerApplet,
    })
    Component { id: controlWin; ControlPanel {} }
    Component { id: runWin; RunDialog {} }
    Component { id: shutdownWin; ShutDownDialog {} }
    Component { id: logoffWin; LogOffDialog {} }
    Component { id: helpWin; HelpWindow {} }
    Component { id: messagesWin; Messages {} }
    Component { id: mediaWin; MediaPlayer {} }
    Component { id: volumeWin; VolumeControl {} }
    Component { id: monitorKeepWin; MonitorKeep {} }
    Component { id: datetimeApplet; DateTime {} }
    Component { id: displayApplet; Display {} }
    Component { id: multimediaApplet; Multimedia {} }
    Component { id: networkApplet; Network {} }
    Component { id: systemApplet; SystemProps {} }
    Component { id: lightingApplet; Lighting {} }
    Component { id: timerApplet; Timer98 {} }
    Component { id: claudeApplet; ClaudeProps {} }
    Component { id: powerApplet; PowerProps {} }
}
