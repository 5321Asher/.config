import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"
import "../widgets"
import "../services"
import "../settings"

// The Start menu. The search box (typing anywhere starts a search), Pinned (six across, three rows
// to a page; right-click to unpin or pin to the taskbar), All apps (A to Z), Recommended (the
// shared menus, Trigger, Style… as Windows' suggestions, then the files you opened lately), and the
// bottom strip: you (account menu) and, at the right, Settings, File Explorer and Power.
Item {
    id: root

    required property string screenName
    property bool active: false
    property bool allApps: false
    onActiveChanged: if (active) { allApps = false; search.text = ""; pinGrid.contentY = 0; }

    // ---------------------------------------------------------------- the shared menus
    property var shared: []
    function loadShared() {
        Elephant.query("menus:start", list => root.shared = list.filter(it => {
            const t = (it.text ?? "").toLowerCase();
            return t !== "apps" && t !== "power";
        }));
    }
    Component.onCompleted: loadShared()
    onAllAppsChanged: if (!allApps) loadShared()

    readonly property string user: Quickshell.env("USER") ?? "user"
    property string fullName: ""
    Process {
        running: true
        command: ["sh", "-c", 'getent passwd "$USER" | cut -d: -f5 | cut -d, -f1']
        stdout: StdioCollector { onStreamFinished: root.fullName = text.trim() }
    }

    function menuAt(item, items, px, py) {
        const p = item.mapToItem(null, px ?? item.width / 2, py ?? 0);
        Flyouts.menu(screenName, items, p.x, p.y, true);
    }
    function appMenu(item, e, px, py) {
        const inStart = Apps.isPinned("start", e), inBar = Apps.isPinned("taskbar", e);
        const acts = (e.actions ?? []).map(a => ({ text: a.name, run: () => a.execute() }));
        menuAt(item, [
            { text: inStart ? "Unpin from Start" : "Pin to Start", glyph: inStart ? "" : "", run: () => Apps.togglePin("start", e) },
            { text: inBar ? "Unpin from taskbar" : "Pin to taskbar", glyph: inBar ? "" : "", run: () => Apps.togglePin("taskbar", e) },
        ].concat(inStart ? [{ text: "Move to front", glyph: "", run: () => Apps.movePin("start", e, 0) }] : [])
         .concat(acts.length ? [{ sep: true }].concat(acts) : []), px, py);
    }
    function launch(e) { Flyouts.close(); Apps.launch(e); }

    Acrylic { anchors.fill: parent }
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton; onClicked: if (Flyouts.levels.length) Flyouts.closeMenu() }

    // typing anywhere goes to Search, with what was typed
    Keys.onPressed: e => {
        if (e.text && e.text.length === 1 && e.text >= " " && !(e.modifiers & Qt.ControlModifier)) {
            Flyouts.show("search", root.screenName, { text: e.text });
            e.accepted = true;
        }
    }
    focus: active

    // ---------------------------------------------------------------- search box
    Item {
        id: top
        x: 32; y: 24
        width: parent.width - 64
        height: 36
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Theme.dark ? Qt.alpha("#000000", 0.25) : "#ffffff"
            border.width: 1
            border.color: Theme.controlStroke
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: parent.radius; rightMargin: parent.radius }
                height: 1
                color: Theme.accent
            }
        }
        Glyph { x: 14; anchors.verticalCenter: parent.verticalCenter; g: ""; size: 14; color: Theme.text2; rotation: 0 }
        Txt { id: search; property string text: ""; x: 40; height: parent.height; level: 2 }
        Txt { x: 40; height: parent.height; level: 2; text: "Search for apps, settings, and documents" }
        MouseArea { anchors.fill: parent; cursorShape: Qt.IBeamCursor; onClicked: Flyouts.show("search", root.screenName, {}) }
    }

    // ---------------------------------------------------------------- the two pages
    Item {
        id: pages
        x: 0
        y: top.y + top.height + 16
        width: parent.width
        height: bottom.y - y
        clip: true

        // ---- Pinned + Recommended
        Item {
            id: home
            width: parent.width
            height: parent.height
            x: root.allApps ? -width * 0.3 : 0
            opacity: root.allApps ? 0 : 1
            visible: opacity > 0
            Behavior on x { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: Theme.fast } }

            Txt { x: 52; y: 8; text: "Pinned"; strong: true }
            Btn {
                x: parent.width - width - 44; y: 2
                height: 28
                text: "All apps"
                glyph: ""
                onClicked: root.allApps = true
                Glyph { anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; g: ""; size: 10 }
                padding: 16
            }

            GridView {
                id: pinGrid
                x: 38; y: 44
                width: parent.width - 76
                readonly property int rows: Math.max(1, Math.min(3, Math.floor((pages.height - 44 - 190) / 90)))
                height: rows * 90
                cellWidth: width / 6
                cellHeight: 90
                clip: true
                model: Apps.startEntries
                snapMode: GridView.SnapOneRow
                boundsBehavior: Flickable.StopAtBounds
                highlightRangeMode: GridView.NoHighlightRange
                delegate: Item {
                    id: tile
                    required property var modelData
                    width: pinGrid.cellWidth
                    height: pinGrid.cellHeight
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: Theme.radius
                        color: tileMouse.pressed ? Theme.subtle2 : tileMouse.containsMouse ? Theme.subtle : "transparent"
                    }
                    AppIcon { anchors.horizontalCenter: parent.horizontalCenter; y: 14; size: 32; name: tile.modelData.icon }
                    Txt {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 54
                        width: parent.width - 8
                        horizontalAlignment: Text.AlignHCenter
                        text: Apps.nameOf(tile.modelData)
                        size: Theme.caption
                    }
                    MouseArea {
                        id: tileMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: e => e.button === Qt.RightButton ? root.appMenu(tile, tile.modelData, e.x, e.y) : root.launch(tile.modelData)
                    }
                }
            }
            // page dots, when there are more pins than fit
            Column {
                visible: Apps.startEntries.length > pinGrid.rows * 6
                x: parent.width - 22
                anchors.verticalCenter: pinGrid.verticalCenter
                spacing: 6
                Repeater {
                    model: Math.ceil(Apps.startEntries.length / (pinGrid.rows * 6))
                    Rectangle {
                        required property int index
                        readonly property bool cur: Math.round(pinGrid.contentY / pinGrid.height) === index
                        width: 6; height: cur ? 12 : 6; radius: 3
                        color: cur ? Theme.text2 : Theme.text3
                        MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: pinGrid.contentY = index * pinGrid.height }
                    }
                }
            }

            // ---- Recommended
            Txt { id: recTitle; x: 52; y: pinGrid.y + pinGrid.height + 16; text: "Recommended"; strong: true }
            Grid {
                id: rec
                x: 36; y: recTitle.y + 36
                width: parent.width - 72
                columns: 2
                columnSpacing: 8
                rowSpacing: 4
                readonly property int fit: Math.max(2, Math.floor((pages.height - y) / 58) * 2)
                readonly property var entries: root.shared.map(s => ({ kind: "menu", it: s }))
                    .concat(Apps.recent.map(r => ({ kind: "file", it: r }))).slice(0, fit)
                Repeater {
                    model: rec.entries
                    Item {
                        id: recItem
                        required property var modelData
                        width: (rec.width - rec.columnSpacing) / 2
                        height: 54
                        readonly property bool isMenu: modelData.kind === "menu"
                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radius
                            color: recMouse.pressed ? Theme.subtle2 : recMouse.containsMouse ? Theme.subtle : "transparent"
                        }
                        // shared menus get a coloured square with their Fluent glyph, like a Store app
                        Rectangle {
                            visible: recItem.isMenu
                            x: 12; anchors.verticalCenter: parent.verticalCenter
                            width: 32; height: 32; radius: Theme.radius
                            color: Theme.accent
                            Glyph { anchors.centerIn: parent; g: root.menuGlyph(recItem.modelData.it.text); color: Theme.accentText; size: 16 }
                        }
                        AppIcon {
                            visible: !recItem.isMenu
                            x: 12; anchors.verticalCenter: parent.verticalCenter
                            size: 32
                            name: recItem.isMenu ? "" : Apps.mimeIcon(recItem.modelData.it.mime)
                        }
                        Column {
                            x: 56
                            width: parent.width - 64
                            anchors.verticalCenter: parent.verticalCenter
                            Txt { width: parent.width; text: recItem.isMenu ? recItem.modelData.it.text : recItem.modelData.it.name; size: Theme.caption; strong: false }
                            Txt { width: parent.width; size: Theme.caption; level: 2
                                  text: recItem.isMenu ? (recItem.modelData.it.subtext || "Shared menu") : Apps.ago(recItem.modelData.it.when) }
                        }
                        MouseArea {
                            id: recMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                const it = recItem.modelData.it;
                                if (!recItem.isMenu) { Flyouts.close(); Apps.open(it.path); return; }
                                const isSub = ((it.actions ?? [])[0] ?? "") === "menus:open";
                                if (!isSub) { Flyouts.close(); Elephant.activate(it); return; }
                                const p = recItem.mapToItem(null, recItem.width - 8, 8);
                                Flyouts.menu(root.screenName, done => Elephant.query(it.identifier.split("::")[0], l => done(Elephant.toItems(l))), p.x, p.y, false);
                            }
                        }
                    }
                }
            }
        }

        // ---- All apps
        Item {
            id: all
            width: parent.width
            height: parent.height
            x: root.allApps ? 0 : width * 0.3
            opacity: root.allApps ? 1 : 0
            visible: opacity > 0
            Behavior on x { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: Theme.fast } }

            Txt { x: 52; y: 8; text: "All apps"; strong: true }
            Btn {
                x: parent.width - width - 44; y: 2
                height: 28
                text: "Back"
                padding: 16
                onClicked: root.allApps = false
            }
            ListView {
                id: allList
                x: 36; y: 44
                width: parent.width - 72
                height: parent.height - y
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: {
                    const out = [];
                    let letter = "";
                    for (const e of Apps.all) {
                        const c = /[a-z]/i.test(Apps.nameOf(e)[0]) ? Apps.nameOf(e)[0].toUpperCase() : "#";
                        if (c !== letter) { out.push({ header: c }); letter = c; }
                        out.push({ e: e });
                    }
                    return out;
                }
                delegate: Item {
                    id: appRow
                    required property var modelData
                    readonly property var entry: modelData.e ?? null
                    width: allList.width
                    height: 40
                    Txt { visible: !!appRow.modelData.header; x: 16; height: parent.height; text: appRow.modelData.header ?? ""; strong: true }
                    Rectangle {
                        visible: !appRow.modelData.header
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: Theme.radius
                        color: appMouse.pressed ? Theme.subtle2 : appMouse.containsMouse ? Theme.subtle : "transparent"
                    }
                    AppIcon { visible: !!appRow.entry; x: 16; anchors.verticalCenter: parent.verticalCenter; size: 24; name: appRow.entry?.icon ?? "" }
                    Txt { visible: !!appRow.entry; x: 56; width: parent.width - 64; height: parent.height; text: Apps.nameOf(appRow.entry) }
                    MouseArea {
                        id: appMouse
                        enabled: !!appRow.entry
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: e => e.button === Qt.RightButton ? root.appMenu(appRow, appRow.entry, e.x, e.y) : root.launch(appRow.entry)
                    }
                }
                Rectangle {
                    parent: allList
                    anchors.right: parent.right
                    width: 2; radius: 1
                    visible: allList.contentHeight > allList.height
                    height: Math.max(30, allList.height * allList.height / allList.contentHeight)
                    y: allList.visibleArea.yPosition * allList.height
                    color: Qt.alpha(Theme.text, 0.4)
                }
            }
        }
    }

    // ---------------------------------------------------------------- the bottom strip
    Item {
        id: bottom
        width: parent.width
        height: 64
        y: parent.height - height
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            color: Theme.dark ? Qt.alpha("#000000", 0.18) : Qt.alpha("#000000", 0.03)
            bottomLeftRadius: Theme.radiusLarge - 1
            bottomRightRadius: Theme.radiusLarge - 1
        }
        Rectangle { width: parent.width; height: 1; color: Theme.divider }

        // you
        Item {
            id: me
            x: 40
            anchors.verticalCenter: parent.verticalCenter
            width: meRow.width + 24
            height: 40
            Rectangle { anchors.fill: parent; radius: Theme.radius; color: meMouse.containsMouse ? Theme.subtle : "transparent" }
            Row {
                id: meRow
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12
                Avatar { size: 32 }
                Txt { anchors.verticalCenter: parent.verticalCenter; text: root.fullName || root.user; size: Theme.caption }
            }
            MouseArea {
                id: meMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.menuAt(me, [
                    { text: "Change account settings", glyph: "", run: () => SettingsApp.open("accounts") },
                    { sep: true },
                    { text: "Lock", glyph: "", run: () => Quickshell.execDetached(["loginctl", "lock-session"]) },
                    { text: "Sign out", glyph: "", run: () => Quickshell.execDetached(["sh", "-c", "hyprctl dispatch 'hl.dsp.exit()'"]) },
                ], meMouse.mouseX, 0)
            }
        }

        // Settings and File Explorer (Windows lets you put folders beside Power), and Power
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 40
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Btn { kind: "subtle"; glyph: ""; width: 40; height: 40; onClicked: { Flyouts.close(); Quickshell.execDetached(["thunar"]); } }
            Btn { kind: "subtle"; glyph: ""; width: 40; height: 40; onClicked: { Flyouts.close(); SettingsApp.open("home"); } }
            Btn {
                id: power
                kind: "subtle"; glyph: ""; width: 40; height: 40
                onClicked: Elephant.query("menus:power", list => {
                    const glyphs = { lock: "", suspend: "", logout: "", reboot: "", shutdown: "" };
                    const words = { lock: "Lock", suspend: "Sleep", logout: "Sign out", reboot: "Restart", shutdown: "Shut down" };
                    const key = t => { t = t.toLowerCase(); return t.includes("lock") ? "lock" : t.includes("suspend") || t.includes("sleep") ? "suspend"
                        : t.includes("log") ? "logout" : t.includes("reboot") || t.includes("restart") ? "reboot" : t.includes("shut") || t.includes("power") ? "shutdown" : ""; };
                    const order = ["lock", "suspend", "logout", "shutdown", "reboot"];
                    const items = list.map(it => ({ k: key(it.text ?? ""), it: it }))
                        .sort((a, b) => order.indexOf(a.k) - order.indexOf(b.k))
                        .map(x => ({ text: words[x.k] ?? x.it.text, glyph: glyphs[x.k] ?? "", run: () => Elephant.activate(x.it) }));
                    root.menuAt(power, items.length ? items : [{ text: "No power menu", enabled: false }]);
                })
            }
        }
    }

    // a Fluent glyph for a shared-menu entry, by its name
    function menuGlyph(t) {
        t = (t ?? "").toLowerCase();
        if (t.includes("trigger")) return "";
        if (t.includes("style")) return "";
        if (t.includes("capture") || t.includes("screen")) return "";
        if (t.includes("web")) return "";
        if (t.includes("wall")) return "";
        if (t.includes("key")) return "";
        if (t.includes("config")) return "";
        return "";
    }
}
