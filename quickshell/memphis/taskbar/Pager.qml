import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../theme"
import "../widgets"
import "../utilities"

// Workspaces, as a row of small numbered buttons beside Start (98 had one desktop; this is where
// its Quick Launch icons sat). The one showing on this screen is held in; empty ones are grey.
// Click to go there; scroll to step through them. Right-click opens the overview.
Row {
    id: root

    required property HyprlandMonitor monitor
    readonly property int count: Math.max(5, ...Hyprland.workspaces.values.filter(w => w.id > 0).map(w => w.id))

    spacing: 0

    function go(id) { Hyprland.dispatch(`hl.dsp.focus({ workspace = ${id} })`); }

    Repeater {
        model: root.count
        Btn {
            id: b
            required property int index
            readonly property int wsId: index + 1
            readonly property var ws: Hyprland.workspaces.values.find(w => w.id === wsId) ?? null
            readonly property bool here: root.monitor?.activeWorkspace?.id === wsId
            readonly property bool busy: (ws?.toplevels?.values?.length ?? 0) > 0
            width: Theme.pagerButton
            height: Theme.taskButton
            implicitWidth: Theme.pagerButton
            padding: 0
            flat: !here
            checked: here
            activeFocusOnTab: false
            text: String(wsId)
            bold: here
            onClicked: root.go(wsId)
            onRightClicked: OverviewState.toggle()

            // grey the number when nothing's there
            opacity: b.busy || b.here ? 1 : 0.55

            Tip {
                target: b
                hovered: b.hovered
                text: `Workspace ${b.wsId}` + (b.ws ? ` · ${b.ws.toplevels.values.length} window${b.ws.toplevels.values.length === 1 ? "" : "s"}` : " · empty")
            }
        }
    }

    WheelHandler {
        onWheel: e => {
            const cur = root.monitor?.activeWorkspace?.id ?? 1;
            const next = Math.max(1, Math.min(root.count, cur + (e.angleDelta.y < 0 ? 1 : -1)));
            if (next !== cur) root.go(next);
        }
    }
}
