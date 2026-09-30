import QtQuick
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../widgets"
import "../../services"
import ".."

// Display Properties:
//   Background   the wallpapers of this colour scheme, previewed on 98's little monitor (skwd-helm applies)
//   Appearance   the colour scheme (Memphis's themes) with 98's preview of windows and a message box,
//                and the desktop setup
//   Settings     screens: arrangement (drag them), resolution ("Screen area"), refresh, scale,
//                rotation; Apply / OK ask you to keep them (desk/windows/MonitorKeep.qml), and put
//                them back after 15 s if you don't
//   Brightness   each monitor's brightness (DDC/CI)
Props {
    id: root

    title: "Display Properties"
    icon: "preferences-desktop-display"
    tabs: ["Background", "Appearance", "Settings", "Brightness"]
    applyEnabled: (current === 1 && (scheme !== curScheme || setup !== curSetup)) || (current === 2 && Displays.dirty)
    onApplied: {
        if (current === 1) {
            if (setup !== curSetup) Quickshell.execDetached([themeTool, "setup", setup]);
            else if (scheme !== curScheme) Quickshell.execDetached([themeTool, "set", scheme]);
        } else if (current === 2 && Displays.dirty) Displays.apply();
    }

    readonly property string themeTool: Quickshell.env("HOME") + "/.config/theme/theme"
    Component.onCompleted: {
        Displays.refresh();
        if (!Brightness.scanned) Brightness.scan();
    }

    // ---------------------------------------------------------------- data
    property var walls: []
    property string wallSel: ""
    property string wallNow: ""
    property var schemes: []            // [{ id, name }]
    property string scheme: ""
    property string curScheme: ""
    property var setups: []
    property string setup: ""
    property string curSetup: ""

    Process {
        running: true
        command: ["sh", "-c", "find -L \"$HOME/Pictures/Wallpapers\" -maxdepth 3 -type f \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.mp4' -o -iname '*.gif' \\) | sort; echo '--'; cat \"$HOME/.cache/skwd-wall-v2/last-wallpaper.json\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [list, last] = text.split("\n--\n");
                root.walls = list.split("\n").filter(l => l.trim());
                try { root.wallNow = JSON.parse(last).path ?? ""; } catch (e) {}
                root.wallSel = root.wallNow;
            }
        }
    }
    Process {
        running: true
        command: [root.themeTool, "rows", "themes"]
        stdout: StdioCollector {
            onStreamFinished: {
                const rows = text.split("\n").filter(l => l).map(l => l.split("\t"));
                root.schemes = rows.map(r => ({ id: r[0], name: r[1] }));
                const cur = rows.find(r => r[4] === "1");
                root.curScheme = root.scheme = cur ? cur[0] : "";
            }
        }
    }
    Process {
        running: true
        command: [root.themeTool, "rows", "setups"]
        stdout: StdioCollector {
            onStreamFinished: {
                const rows = text.split("\n").filter(l => l).map(l => l.split("\t"));
                root.setups = rows.map(r => ({ id: r[0], name: r[1], about: r[2] }));
                const cur = rows.find(r => r[5] === "1");
                root.curSetup = root.setup = cur ? cur[0] : "";
            }
        }
    }
    function base(p) { return p.split("/").pop().replace(/\.[^.]+$/, ""); }
    function isVideo(p) { return /\.(mp4|webm|mkv)$/i.test(p); }

    // 98's monitor: a beige box with a dark screen, on a little stand. `content` goes on the screen.
    component Monitor: Item {
        default property alias content: screenArea.data
        width: 200
        height: 170
        Bevel { x: 20; y: 0; width: 160; height: 124; kind: "button"; fill: Theme.face }
        Rectangle {
            id: screenArea
            x: 34; y: 12; width: 132; height: 98
            color: Theme.desktop
            clip: true
            border.width: 1
            border.color: Theme.dkShadow
        }
        // the power light
        Rectangle { x: 160; y: 114; width: 4; height: 3; color: "#00c000" }
        Bevel { x: 80; y: 124; width: 40; height: 12; kind: "button"; fill: Theme.face }
        Bevel { x: 52; y: 136; width: 96; height: 10; kind: "button"; fill: Theme.face }
    }

    // ---------------------------------------------------------------- Background
    Item {
        Monitor {
            id: mon1
            anchors.horizontalCenter: parent.horizontalCenter
            Image {
                anchors.fill: parent
                anchors.margins: 1
                visible: root.wallSel !== "" && !root.isVideo(root.wallSel)
                source: visible ? "file://" + root.wallSel : ""
                sourceSize.width: 264
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            Txt {
                anchors.centerIn: parent
                visible: root.isVideo(root.wallSel)
                text: "(moving picture)"
                color: "#ffffff"
            }
        }
        Txt { id: wallLabel; y: mon1.height + 4; text: "Wallpaper" }
        Txt { y: mon1.height + 4; anchors.right: parent.right; text: "Select a picture to see it; OK or Apply sets it." ; color: Theme.grayText; visible: false }
        ListBox {
            id: wallList
            y: wallLabel.y + 24
            width: parent.width - 120
            height: parent.height - y
            model: root.walls
            currentIndex: root.walls.indexOf(root.wallSel)
            iconOf: p => root.isVideo(p) ? "video-x-generic" : "image-x-generic"
            textOf: p => root.base(p) + (p === root.wallNow ? "  (current)" : "")
            onClicked: i => root.wallSel = root.walls[i]
            onActivated: i => { Quickshell.execDetached(["skwd-helm", "apply", root.walls[i]]); root.wallNow = root.walls[i]; }
        }
        Column {
            x: wallList.width + 10
            y: wallList.y
            spacing: 6
            Btn {
                text: "Set"
                enabled: root.wallSel !== "" && root.wallSel !== root.wallNow
                onClicked: { Quickshell.execDetached(["skwd-helm", "apply", root.wallSel]); root.wallNow = root.wallSel; }
            }
            Btn { text: "Random"; onClicked: Quickshell.execDetached([root.themeTool, "wall"]) }
            Btn {
                text: "Browse…"
                onClicked: browse.running = true
            }
        }
        Process {
            id: browse
            command: ["zenity", "--file-selection", "--title=Browse", "--file-filter=Pictures | *.png *.jpg *.jpeg *.webp *.gif *.mp4"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const p = text.trim();
                    if (p) { Quickshell.execDetached(["skwd-helm", "apply", p]); root.wallNow = root.wallSel = p; }
                }
            }
        }
    }

    // ---------------------------------------------------------------- Appearance
    Item {
        // 98's preview: two windows and a message box on the desktop colour
        Bevel {
            id: preview
            width: parent.width
            height: 250
            kind: "sunken"
            fill: Theme.desktop

            Win {
                x: 14; y: 12; width: 300; height: 110
                title: "Inactive Window"
                active: false
                closable: true
                minButton: true
            }
            Win {
                x: 34; y: 44; width: 330; height: 150
                title: "Active Window"
                minButton: true
                menus: [{ title: "Normal" }, { title: "Disabled" }, { title: "Selected" }]
                Bevel {
                    anchors.fill: parent
                    anchors.margins: 2
                    kind: "sunken"
                    fill: Theme.window
                    Txt { x: 6; y: 4; height: 20; text: "Window Text"; color: Theme.windowText }
                }
            }
            Win {
                x: 200; y: 130; width: 220; height: 108
                title: "Message Box"
                Txt { x: 10; y: 6; text: "Message Text" }
                Btn { anchors.horizontalCenter: parent.horizontalCenter; y: 34; text: "OK"; isDefault: true; implicitWidth: 80 }
            }
        }
        Column {
            y: preview.height + 12
            width: parent.width
            spacing: 6
            Txt { text: "Scheme:" }
            Row {
                spacing: 8
                Combo {
                    width: 300
                    model: root.schemes
                    textOf: s => s.name
                    currentIndex: root.schemes.findIndex(s => s.id === root.scheme)
                    onChosen: i => root.scheme = root.schemes[i].id
                }
                Txt { height: Theme.field; text: root.scheme !== root.curScheme ? "Click Apply to use it." : ""; color: Theme.grayText }
            }
            Item { width: 1; height: 8 }
            Txt { text: "Desktop setup (the whole desktop: shell, fonts, colours):" }
            Row {
                spacing: 8
                Combo {
                    width: 300
                    model: root.setups
                    textOf: s => s.name + "  —  " + s.about
                    currentIndex: root.setups.findIndex(s => s.id === root.setup)
                    onChosen: i => root.setup = root.setups[i].id
                }
            }
        }
    }

    // ---------------------------------------------------------------- Settings
    Item {
        id: settings
        property string selected: Displays.draft.find(m => m.focused)?.name ?? Displays.draft[0]?.name ?? ""
        readonly property var mon: Displays.draft.find(m => m.name === selected) ?? Displays.draft[0] ?? null
        readonly property var enabledMonitors: Displays.draft.filter(m => m.enabled)
        // Change the selected screen's mode / scale / rotation. When its size on the desktop changes,
        // the screens to its right and below move by the same amount so they still touch it (else a
        // smaller mode left a gap, and the pointer couldn't cross between the screens).
        function change(changes) {
            const m = mon;
            if (!m) return;
            const before = Displays.logical(m), after = Displays.logical(Object.assign({}, m, changes));
            const dw = after.w - before.w, dh = after.h - before.h;
            const shifts = [];
            for (const o of Displays.draft) {
                if (o.name === m.name || !o.enabled) continue;
                const s = {};
                if (dw && o.x >= m.x + before.w - 1) s.x = Math.round(o.x + dw);
                if (dh && o.y >= m.y + before.h - 1) s.y = Math.round(o.y + dh);
                if (Object.keys(s).length) shifts.push([o.name, s]);
            }
            Displays.update(m.name, changes);
            for (const [n, s] of shifts) Displays.update(n, s);
        }
        readonly property var resolutions: {
            const seen = new Set();
            return (mon?.modes ?? []).filter(m => { const k = m.width + "x" + m.height; if (seen.has(k)) return false; seen.add(k); return true; })
                .sort((a, b) => a.width * a.height - b.width * b.height);
        }
        readonly property var rates: (mon?.modes ?? []).filter(m => m.width === mon.width && m.height === mon.height).sort((a, b) => b.refresh - a.refresh)
        readonly property var scales: {
            const w = mon?.width ?? 0, h = mon?.height ?? 0;
            const ok = [];
            for (let i = 30; i <= 360; i++) if ((w * 120) % i === 0 && (h * 120) % i === 0) ok.push(i / 120);
            const near = s => ok.reduce((a, b) => Math.abs(b - s) < Math.abs(a - s) ? b : a, 1);
            const out = [];
            for (const want of [0.75, 1, 1.25, 1.5, 1.75, 2]) { const s = near(want); if (!out.some(x => Math.abs(x - s) < 0.001)) out.push(s); }
            // the screen's own scale is always offered (else the list shows blank, e.g. 83%)
            const cur = mon?.scale ?? 1;
            if (!out.some(x => Math.abs(x - cur) < 0.005)) out.push(cur);
            return out.sort((a, b) => a - b);
        }

        // the arrangement: each screen a numbered monitor; drag to move (snaps to edges)
        Bevel {
            id: arrange
            width: parent.width
            height: 200
            kind: "sunken"
            fill: Theme.desktop

            readonly property var bounds: {
                const list = settings.enabledMonitors.filter(m => !m.mirror);
                if (!list.length) return { x: 0, y: 0, w: 1, h: 1 };
                const xs = [], ys = [], xe = [], ye = [];
                for (const m of list) { const s = Displays.logical(m); xs.push(m.x); ys.push(m.y); xe.push(m.x + s.w); ye.push(m.y + s.h); }
                const x = Math.min(...xs), y = Math.min(...ys);
                return { x: x, y: y, w: Math.max(...xe) - x, h: Math.max(...ye) - y };
            }
            readonly property real k: Math.min((width - 40) / bounds.w, (height - 40) / bounds.h)
            readonly property real ox: (width - bounds.w * k) / 2
            readonly property real oy: (height - bounds.h * k) / 2

            Repeater {
                model: settings.enabledMonitors.filter(m => !m.mirror)
                Item {
                    id: box
                    required property var modelData
                    required property int index
                    readonly property var size: Displays.logical(modelData)
                    readonly property bool sel: settings.mon?.name === modelData.name
                    function place() {
                        x = Qt.binding(() => arrange.ox + (modelData.x - arrange.bounds.x) * arrange.k);
                        y = Qt.binding(() => arrange.oy + (modelData.y - arrange.bounds.y) * arrange.k);
                    }
                    Component.onCompleted: place()
                    width: size.w * arrange.k
                    height: size.h * arrange.k
                    z: grab.drag.active ? 10 : 1
                    Bevel { anchors.fill: parent; kind: "button"; fill: Theme.face }
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 5
                        color: box.sel ? Theme.select : Theme.title2
                        border.width: 1
                        border.color: Theme.dkShadow
                        Text {
                            anchors.centerIn: parent
                            text: Displays.draft.findIndex(m => m.name === box.modelData.name) + 1
                            color: "#ffffff"
                            font.family: Theme.fontBanner
                            font.pixelSize: Math.min(parent.height * 0.6, 40)
                        }
                    }
                    MouseArea {
                        id: grab
                        anchors.fill: parent
                        drag.target: box
                        drag.threshold: 4
                        // inside the arrangement area
                        drag.minimumX: 0
                        drag.maximumX: arrange.width - box.width
                        drag.minimumY: 0
                        drag.maximumY: arrange.height - box.height
                        onPressed: settings.selected = box.modelData.name
                        // Commit when the drag ends: by `released`, drag.active is already false, so
                        // checking it there skipped every move (the box stayed put, Apply stayed grey)
                        drag.onActiveChanged: if (!drag.active) box.commit()
                    }
                    function commit() {
                        let nx = arrange.bounds.x + (box.x - arrange.ox) / arrange.k;
                        let ny = arrange.bounds.y + (box.y - arrange.oy) / arrange.k;
                        const snap = 20 / arrange.k, me = box.size;
                        let bx = null, by = null;
                        for (const o of settings.enabledMonitors) {
                            if (o.name === box.modelData.name || o.mirror) continue;
                            const s = Displays.logical(o);
                            for (const c of [o.x + s.w, o.x - me.w, o.x, o.x + s.w - me.w])
                                if (Math.abs(nx - c) < snap && (bx === null || Math.abs(nx - c) < Math.abs(nx - bx))) bx = c;
                            for (const c of [o.y, o.y + s.h, o.y - me.h, o.y + s.h - me.h])
                                if (Math.abs(ny - c) < snap && (by === null || Math.abs(ny - c) < Math.abs(ny - by))) by = c;
                        }
                        const x = Math.round(bx ?? nx), y = Math.round(by ?? ny);
                        // unchanged: put the box back. Changed: the update rebuilds the boxes (this one
                        // included, so don't touch it after), and the new one is placed from the draft
                        if (x === box.modelData.x && y === box.modelData.y) box.place();
                        else Displays.update(box.modelData.name, { x: x, y: y });
                    }
                }
            }
        }

        Column {
            y: arrange.height + 10
            width: parent.width
            spacing: 6
            Row {
                spacing: 8
                Txt { width: 90; height: Theme.field; text: "Display:" }
                Combo {
                    width: parent.parent.width - 98
                    model: Displays.draft
                    // by name: the list hands textOf copies, so indexOf(m) was always -1 ("0.")
                    textOf: m => (Displays.draft.findIndex(x => x.name === m.name) + 1) + ". " + m.name + (m.model ? " on " + m.model : "")
                    currentIndex: Displays.draft.findIndex(m => m.name === settings.selected)
                    onChosen: i => settings.selected = Displays.draft[i].name
                }
            }
            Row {
                spacing: 18
                Check {
                    text: "Use this screen"
                    checked: settings.mon?.enabled ?? false
                    enabled: !(settings.mon?.enabled && settings.enabledMonitors.length === 1)
                    onToggled: Displays.update(settings.mon.name, { enabled: !settings.mon.enabled, mirror: "" })
                }
                Check {
                    visible: settings.enabledMonitors.length > 1 || Displays.mirrored
                    text: "Mirror the other screen"
                    checked: !!settings.mon?.mirror
                    onToggled: Displays.setMirror(!settings.mon?.mirror, settings.mon?.mirror || settings.mon?.name)
                }
            }
            Row {
                spacing: 10
                enabled: settings.mon?.enabled ?? false
                Group {
                    title: "Screen area"
                    width: 250
                    TrackBar {
                        width: parent.width
                        ticks: settings.resolutions.length
                        readonly property int idx: settings.resolutions.findIndex(m => m.width === settings.mon?.width && m.height === settings.mon?.height)
                        value: settings.resolutions.length > 1 ? idx / (settings.resolutions.length - 1) : 0
                        onMoved: v => {
                            const m = settings.resolutions[Math.round(v * (settings.resolutions.length - 1))];
                            if (!m) return;
                            const rates = settings.mon.modes.filter(x => x.width === m.width && x.height === m.height).map(x => x.refresh);
                            settings.change({ width: m.width, height: m.height, refresh: Math.max(...rates) });
                        }
                    }
                    Item {
                        width: parent.width; height: 18
                        Txt { text: "Less" }
                        Txt { anchors.right: parent.right; text: "More" }
                    }
                    Txt { anchors.horizontalCenter: parent.horizontalCenter; text: settings.mon ? settings.mon.width + " by " + settings.mon.height + " pixels" : "" }
                }
                Column {
                    spacing: 4
                    Txt { text: "Refresh rate:" }
                    Combo {
                        width: 190
                        model: settings.rates
                        textOf: m => m.refresh.toFixed(2) + " Hertz"
                        currentIndex: settings.rates.findIndex(m => Math.abs(m.refresh - (settings.mon?.refresh ?? 0)) < 0.01)
                        onChosen: i => Displays.update(settings.mon.name, { refresh: settings.rates[i].refresh })
                    }
                    Row {
                        spacing: 6
                        Column {
                            spacing: 4
                            Txt { text: "Scale:" }
                            Combo {
                                width: 92
                                model: settings.scales
                                textOf: s => Math.round(s * 100) + "%"
                                currentIndex: settings.scales.findIndex(s => Math.abs(s - (settings.mon?.scale ?? 1)) < 0.005)
                                onChosen: i => settings.change({ scale: settings.scales[i] })
                            }
                        }
                        Column {
                            spacing: 4
                            Txt { text: "Rotation:" }
                            Combo {
                                width: 92
                                model: ["Normal", "90°", "180°", "270°"]
                                currentIndex: settings.mon?.transform ?? 0
                                onChosen: i => settings.change({ transform: i })
                            }
                        }
                    }
                }
            }
            Txt { visible: Displays.error !== ""; width: parent.width; wrapMode: Text.Wrap; color: Theme.danger; text: Displays.error }
        }

    }

    // ---------------------------------------------------------------- Brightness
    Column {
        spacing: 10
        Txt {
            visible: Brightness.scanned && (!Brightness.available || Brightness.displays.length === 0)
            width: parent.width
            wrapMode: Text.Wrap
            text: !Brightness.available ? "Install ddcutil (and load i2c-dev) to set your monitors' brightness from here."
                : "None of your monitors will take brightness over DDC/CI."
        }
        Txt { visible: Brightness.scanning; text: "Looking for monitors…" }
        Repeater {
            model: Brightness.displays
            Group {
                required property var modelData
                required property int index
                title: modelData.name || ("Monitor " + (index + 1))
                width: parent.width
                Row {
                    spacing: 10
                    Icon { name: "video-display"; size: 32 }
                    TrackBar { width: 330; value: modelData.value; onMoved: v => Brightness.set(index, v) }
                    Txt { height: 34; text: Math.round(modelData.value * 100) + "%" }
                }
            }
        }
        Btn { text: "Look Again"; enabled: !Brightness.scanning; onClicked: Brightness.scan() }
    }
}
