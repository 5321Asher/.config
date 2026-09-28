import QtQuick
import Quickshell
import "../theme"
import "../widgets"
import "../settings"

// Search, as Windows 11's: a search box, then either your top apps and recent files, or results
// (Best match first, then Apps, Settings, Documents, a sum if you typed one, the web) with the
// selected one's details and actions at the right. ↑ ↓ choose, Enter opens, Esc closes.
Item {
    id: root

    required property string screenName
    property bool active: false
    property int sel: 0

    onActiveChanged: if (active) {
        field.text = Flyouts.opts.text ?? "";
        sel = 0;
        focusLater.restart();
    }
    Timer { id: focusLater; interval: 30; onTriggered: { field.focusField(); field.input.cursorPosition = field.text.length; } }

    readonly property string q: field.text.trim()

    // a sum, if the query is one ("12*7", "(3+4)/2")
    readonly property string sum: {
        if (!/^[\d\s+\-*/().,%^]+$/.test(q) || !/\d/.test(q) || !/[+\-*/^%]/.test(q)) return "";
        try {
            const v = Function(`"use strict"; return (${q.replace(/\^/g, "**").replace(/,/g, ".")})`)();
            return typeof v === "number" && isFinite(v) ? String(Math.round(v * 1e10) / 1e10) : "";
        } catch (e) { return ""; }
    }

    readonly property var results: {
        if (!q) return [];
        const out = [];
        if (sum) out.push({ kind: "calc", title: sum, sub: q + " =", glyph: "", group: "Calculator",
                            run: () => Quickshell.execDetached(["wl-copy", sum]), action: "Copy the result" });
        for (const e of Apps.find(q).slice(0, 8))
            out.push({ kind: "app", title: e.name, sub: "App", icon: e.icon, entry: e, group: "Apps", run: () => Apps.launch(e) });
        const ql = q.toLowerCase();
        for (const s of SettingsApp.index.filter(s => (s.title + " " + (s.keywords ?? "")).toLowerCase().includes(ql)).slice(0, 5))
            out.push({ kind: "setting", title: s.title, sub: "System settings", glyph: s.glyph, group: "Settings", run: () => SettingsApp.open(s.id) });
        for (const r of Apps.recent.filter(r => r.name.toLowerCase().includes(ql)).slice(0, 4))
            out.push({ kind: "file", title: r.name, sub: r.path.replace(Quickshell.env("HOME"), "~"), icon: Apps.mimeIcon(r.mime), group: "Documents", run: () => Apps.open(r.path) });
        out.push({ kind: "web", title: q, sub: "See web results", glyph: "", group: "Search the web",
                   run: () => Quickshell.execDetached(["xdg-open", "https://www.google.com/search?q=" + encodeURIComponent(q)]) });
        return out;
    }
    readonly property var current: results[Math.min(sel, results.length - 1)] ?? null
    onResultsChanged: sel = 0
    // the list as shown: a heading before each group
    readonly property var rows: {
        const out = [];
        let g = "";
        results.forEach((r, i) => {
            const group = i === 0 && r.kind !== "web" ? "Best match" : r.group;
            if (group !== g) { out.push({ header: group }); g = group; }
            out.push(Object.assign({ idx: i }, r));
        });
        return out;
    }

    function go(r) {
        if (!r) return;
        Flyouts.close();
        r.run();
    }

    Acrylic { anchors.fill: parent }
    MouseArea { anchors.fill: parent; onClicked: if (Flyouts.levels.length) Flyouts.closeMenu() }

    // ---------------------------------------------------------------- the box
    Field {
        id: field
        x: 24; y: 20
        width: parent.width - 48
        height: 36
        radius: 18
        placeholder: "Type here to search"
        glyph: ""
        input.Keys.onPressed: e => {
            if (e.key === Qt.Key_Down) { root.sel = Math.min(root.results.length - 1, root.sel + 1); e.accepted = true; }
            else if (e.key === Qt.Key_Up) { root.sel = Math.max(0, root.sel - 1); e.accepted = true; }
            else if (e.key === Qt.Key_Escape) { Flyouts.close(); e.accepted = true; }
        }
        onAccepted: {
            if (root.current) root.go(root.current);
            else if (Apps.topApps.length && !root.q) root.go({ run: () => Apps.launch(Apps.topApps[0]) });
        }
    }

    // ---------------------------------------------------------------- nothing typed yet
    Item {
        visible: root.q === ""
        x: 24; y: field.y + field.height + 20
        width: parent.width - 48
        height: parent.height - y - 20

        Txt { id: topTitle; text: "Top apps"; strong: true }
        Row {
            id: topRow
            y: topTitle.height + 12
            spacing: 8
            Repeater {
                model: Apps.topApps
                Item {
                    id: topApp
                    required property var modelData
                    width: 100; height: 88
                    Rectangle { anchors.fill: parent; radius: Theme.radius; color: tm.containsMouse ? Theme.subtle : "transparent" }
                    Card { anchors.fill: parent; color: "transparent"; opacity: tm.containsMouse ? 0 : 0.8 }
                    AppIcon { anchors.horizontalCenter: parent.horizontalCenter; y: 14; size: 32; name: topApp.modelData.icon }
                    Txt { anchors.horizontalCenter: parent.horizontalCenter; y: 54; width: parent.width - 10; horizontalAlignment: Text.AlignHCenter; size: Theme.caption; text: topApp.modelData.name }
                    MouseArea { id: tm; anchors.fill: parent; hoverEnabled: true; onClicked: root.go({ run: () => Apps.launch(topApp.modelData) }) }
                }
            }
        }
        Txt { id: recentTitle; y: topRow.y + topRow.height + 24; text: "Recent"; strong: true }
        Column {
            y: recentTitle.y + recentTitle.height + 8
            width: parent.width
            Txt { visible: Apps.recent.length === 0; text: "Files you open show up here."; level: 2 }
            Repeater {
                model: Apps.recent.slice(0, Math.max(0, Math.floor((root.height - 300) / 44)))
                Item {
                    id: rf
                    required property var modelData
                    width: parent.width; height: 44
                    Rectangle { anchors.fill: parent; radius: Theme.radius; color: rfm.containsMouse ? Theme.subtle : "transparent" }
                    AppIcon { x: 12; anchors.verticalCenter: parent.verticalCenter; size: 24; name: Apps.mimeIcon(rf.modelData.mime) }
                    Txt { x: 48; width: parent.width - 200; height: parent.height; text: rf.modelData.name }
                    Txt { anchors.right: parent.right; anchors.rightMargin: 12; height: parent.height; text: Apps.ago(rf.modelData.when); level: 2; size: Theme.caption }
                    MouseArea { id: rfm; anchors.fill: parent; hoverEnabled: true; onClicked: root.go({ run: () => Apps.open(rf.modelData.path) }) }
                }
            }
        }
    }

    // ---------------------------------------------------------------- results
    Item {
        visible: root.q !== ""
        x: 16; y: field.y + field.height + 16
        width: parent.width - 32
        height: parent.height - y - 16

        ListView {
            id: list
            width: Math.round(parent.width * 0.5)
            height: parent.height
            clip: true
            model: root.rows
            boundsBehavior: Flickable.StopAtBounds
            delegate: Item {
                id: res
                required property var modelData
                readonly property int index: modelData.idx ?? -1
                readonly property bool best: index === 0 && modelData.kind !== "web"
                width: list.width
                height: modelData.header ? 34 : best ? 64 : 40
                Txt { visible: !!res.modelData.header; height: 34; leftPadding: 12; text: res.modelData.header ?? ""; strong: true }
                Rectangle {
                    visible: !res.modelData.header
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: Theme.radius
                    color: index === root.sel ? Theme.subtle : resMouse.containsMouse ? Theme.subtle2 : "transparent"
                    Rectangle {
                        visible: index === root.sel
                        width: 3; height: 16; radius: 1.5
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.accent
                    }
                }
                AppIcon {
                    visible: !!res.modelData.icon
                    x: 14; anchors.verticalCenter: parent.verticalCenter
                    size: res.best ? 32 : 20
                    name: res.modelData.icon ?? ""
                }
                Glyph {
                    visible: !res.modelData.icon && !res.modelData.header
                    x: 14; width: res.best ? 32 : 20
                    anchors.verticalCenter: parent.verticalCenter
                    g: res.modelData.glyph ?? ""
                    size: res.best ? 22 : 16
                }
                Column {
                    visible: !res.modelData.header
                    x: res.best ? 58 : 46
                    width: parent.width - x - 12
                    anchors.verticalCenter: parent.verticalCenter
                    Txt { width: parent.width; text: res.modelData.title; size: res.best ? Theme.bodyLarge - 2 : Theme.body; strong: res.best }
                    Txt { visible: res.best || res.modelData.kind === "web"; width: parent.width; text: res.modelData.sub; size: Theme.caption; level: 2 }
                }
                MouseArea {
                    id: resMouse
                    enabled: !res.modelData.header
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: { root.sel = res.index; root.go(res.modelData); }
                    onEntered: root.sel = res.index
                }
            }
        }

        // the details of what's selected
        Card {
            x: list.width + 12
            width: parent.width - x
            height: parent.height
            visible: root.current !== null
            color: Qt.alpha(Theme.card, 0.7)

            Column {
                id: detail
                x: 24; y: 32
                width: parent.width - 48
                spacing: 8
                Item {
                    width: parent.width; height: 64
                    AppIcon {
                        visible: !!root.current?.icon
                        anchors.horizontalCenter: parent.horizontalCenter
                        size: 64
                        name: root.current?.icon ?? ""
                    }
                    Glyph {
                        visible: !root.current?.icon
                        anchors.centerIn: parent
                        g: root.current?.glyph ?? ""
                        size: 44
                    }
                }
                Txt { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: root.current?.title ?? ""; size: Theme.subtitle; strong: true }
                Txt { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: root.current?.kind === "app" ? "App" : (root.current?.sub ?? ""); level: 2 }
                Item { width: 1; height: 8 }
                Divider { width: parent.width }
                Item { width: 1; height: 4 }
                Repeater {
                    model: {
                        const r = root.current;
                        if (!r) return [];
                        if (r.kind === "app") {
                            const e = r.entry;
                            return [
                                { t: "Open", g: "", run: () => root.go(r) },
                                { t: Apps.isPinned("start", e) ? "Unpin from Start" : "Pin to Start", g: "", run: () => Apps.togglePin("start", e), stay: true },
                                { t: Apps.isPinned("taskbar", e) ? "Unpin from taskbar" : "Pin to taskbar", g: "", run: () => Apps.togglePin("taskbar", e), stay: true },
                            ].concat((e.actions ?? []).map(a => ({ t: a.name, g: "", run: () => { Flyouts.close(); a.execute(); } })));
                        }
                        if (r.kind === "file") return [
                            { t: "Open", g: "", run: () => root.go(r) },
                            { t: "Open file location", g: "", run: () => { Flyouts.close(); Quickshell.execDetached(["thunar", r.sub.replace(/^~/, Quickshell.env("HOME")).replace(/\/[^/]*$/, "")]); } },
                            { t: "Copy path", g: "", run: () => { Flyouts.close(); Quickshell.execDetached(["wl-copy", r.sub.replace(/^~/, Quickshell.env("HOME"))]); } },
                        ];
                        return [{ t: r.action ?? "Open", g: "", run: () => root.go(r) }];
                    }
                    Item {
                        id: act
                        required property var modelData
                        width: detail.width; height: 36
                        Rectangle { anchors.fill: parent; radius: Theme.radius; color: am.containsMouse ? Theme.subtle : "transparent" }
                        Glyph { x: 10; anchors.verticalCenter: parent.verticalCenter; g: act.modelData.g; size: 14; color: Theme.accentLink }
                        Txt { x: 38; height: parent.height; text: act.modelData.t }
                        MouseArea { id: am; anchors.fill: parent; hoverEnabled: true; onClicked: act.modelData.run() }
                    }
                }
            }
        }
    }
}
