pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../menus"
import "../desk"
import "../services"

// What's in the Start menu. The top level is 98's (Programs, Documents, Settings, Find, Help, Run,
// Log Off, Shut Down); the shared menus (~/.config/elephant/menus, the same ones Walker shows) fill
// it in: their Apps entry is Programs, Style goes under Settings, Power is Shut Down, and anything
// else on their root menu (Trigger…) gets its own cascade here. qs ipc call start toggle
Singleton {
    id: root

    readonly property string user: Quickshell.env("USER") ?? "user"

    function toggle(screen) {
        const s = screen ?? Quickshell.screens.find(x => x.name === Desk.focusedScreen()) ?? Quickshell.screens[0];
        if (Menus.open && Menus.kind === "start") { Menus.close(); return; }
        Menus.show(s.name, "start", topLevel, 0, s.height - 38 + 2, { up: true, big: true, banner: true });
    }

    // ---------------------------------------------------------------- top level
    // A loader: the shared root menu is read each time, so new entries show up
    function topLevel(done) {
        Elephant.query("menus:start", list => {
            const extra = Elephant.toItems(list, it => {
                const t = (it.text ?? "").toLowerCase();
                if (t === "apps" || t === "style" || t === "power") return null;   // placed below
                return undefined;
            }).map(i => Object.assign(i, { icon: i.icon === "folder" ? "applications-utilities" : i.icon }));
            const style = list.find(it => (it.text ?? "").toLowerCase() === "style");
            const power = list.find(it => (it.text ?? "").toLowerCase() === "power");
            done([
                { text: "Programs", icon: "applications-other", sub: programs },
                { text: "Documents", icon: "folder-documents", sub: documents },
                { text: "Settings", icon: "preferences-system", sub: settings(style) },
            ].concat(extra).concat([
                { text: "Find", icon: "system-search", sub: [
                    { text: "Files or Folders…", icon: "folder-saved-search", run: () => Quickshell.execDetached(["walker", "-m", "files"]) },
                    { text: "On the Internet…", icon: "internet-web-browser", run: () => Quickshell.execDetached(["walker", "-m", "websearch"]) },
                    { text: "Calculator…", icon: "accessories-calculator", run: () => Quickshell.execDetached(["walker", "-m", "calc"]) },
                    { text: "Symbols…", icon: "accessories-character-map", run: () => Quickshell.execDetached(["walker", "-m", "symbols"]) },
                ] },
                { text: "Help", icon: "help-browser", run: () => Desk.show("help") },
                { text: "Run…", icon: "system-run", run: () => Desk.show("run") },
                { sep: true },
                { text: `Log Off ${root.user}…`, icon: "system-log-out", run: () => Desk.show("logoff") },
                { text: "Shut Down…", icon: "system-shutdown", enabled: power !== undefined || true, run: () => Desk.show("shutdown") },
            ]));
        });
    }

    // Settings: Control Panel and friends, then the shared Style menu's entries (Setup, Theme…)
    function settings(style) {
        return done => {
            const fixed = [
                { text: "Control Panel", icon: "preferences-system", run: () => Desk.show("control") },
                { text: "Display", icon: "preferences-desktop-display", run: () => Desk.show("applet:display", { tab: "Appearance" }) },
                { text: "Taskbar & Notifications…", icon: "mail-inbox", run: () => Desk.show("messages") },
            ];
            if (!style) { done(fixed); return; }
            Elephant.query(style.identifier.split("::")[0], l => done(fixed.concat([{ sep: true }]).concat(Elephant.toItems(l))));
        };
    }

    // ---------------------------------------------------------------- Programs
    // Desktop entries by category, as 98's program groups; a few classics at the top level
    readonly property var groups: [
        ["Accessories", "applications-accessories", ["Utility", "TextEditor", "Accessibility", "Archiving", "Calculator"]],
        ["Games", "applications-games", ["Game"]],
        ["Graphics", "applications-graphics", ["Graphics"]],
        ["Internet", "applications-internet", ["Network", "WebBrowser", "Email", "Chat", "InstantMessaging"]],
        ["Multimedia", "applications-multimedia", ["AudioVideo", "Audio", "Video", "Player"]],
        ["Office", "applications-office", ["Office"]],
        ["Programming", "applications-development", ["Development", "IDE"]],
        ["Science & Education", "applications-science", ["Science", "Education"]],
        ["System Tools", "applications-system", ["System", "Settings", "Monitor", "PackageManager", "Security", "HardwareSettings"]],
    ]
    function entryItem(e) {
        return { text: e.name, icon: e.icon || "application-x-executable", run: () => e.execute() };
    }
    function programs(done) {
        const apps = DesktopEntries.applications.values.filter(a => !a.noDisplay)
            .sort((a, b) => a.name.localeCompare(b.name));
        const used = new Set();
        const folders = [];
        for (const [name, icon, cats] of groups) {
            const members = apps.filter(a => !used.has(a.id) && (a.categories ?? []).some(c => cats.includes(c)));
            members.forEach(a => used.add(a.id));
            if (members.length) folders.push({ text: name, icon: "folder", sub: members.map(entryItem) });
        }
        const rest = apps.filter(a => !used.has(a.id)).map(entryItem);
        const classics = [
            { text: "MS-DOS Prompt", icon: "utilities-terminal", run: () => Quickshell.execDetached(["gtk-launch", "kitty"]) },
            { text: "Windows Explorer", icon: "system-file-manager", run: () => Quickshell.execDetached(["thunar"]) },
        ];
        done(folders.concat(rest.length ? [{ sep: true }] : []).concat(rest).concat([{ sep: true }]).concat(classics));
    }

    // ---------------------------------------------------------------- Documents
    // The files you opened lately (GTK's recently-used list), newest first
    property var recent: []
    FileView {
        id: xbel
        path: Quickshell.env("HOME") + "/.local/share/recently-used.xbel"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const out = [];
            const re = /<bookmark href="([^"]+)"[^>]*modified="([^"]+)"[\s\S]*?mime-type type="([^"]+)"/g;
            let m;
            while ((m = re.exec(text())) !== null) out.push({ href: m[1], modified: m[2], mime: m[3] });
            out.sort((a, b) => b.modified.localeCompare(a.modified));
            root.recent = out.filter(r => r.href.startsWith("file://")).slice(0, 15);
        }
    }
    function mimeIcon(mime) {
        const exact = mime.replace("/", "-");
        if (Quickshell.hasThemeIcon(exact)) return exact;
        const major = mime.split("/")[0];
        return ({ image: "image-x-generic", audio: "audio-x-generic", video: "video-x-generic", text: "text-x-generic" })[major]
            ?? "text-x-generic";
    }
    function documents(done) {
        const home = Quickshell.env("HOME");
        const items = [{ text: "My Documents", icon: "folder-documents", run: () => Quickshell.execDetached(["thunar", home + "/Documents"]) },
                       { sep: true }];
        for (const r of root.recent) {
            const path = decodeURIComponent(r.href.slice(7));
            items.push({ text: path.split("/").pop(), icon: mimeIcon(r.mime), run: () => Quickshell.execDetached(["xdg-open", path]) });
        }
        if (root.recent.length === 0) items.push({ text: "(Empty)", enabled: false });
        done(items);
    }

    IpcHandler {
        target: "start"
        function toggle(): void { root.toggle(null); }
        function open(): void { if (!(Menus.open && Menus.kind === "start")) root.toggle(null); }
        function close(): void { Menus.close(); }
    }
}
