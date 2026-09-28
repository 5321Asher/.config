pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// The Settings app: whether it's open and which page it shows. Pages have ids (below); each has a
// parent (the breadcrumb: System > Display) and belongs to a section of the left pane.
//   qs ipc call settings open <page>      any page by id
//   qs ipc call deck open <page>          the shared deck pages, mapped onto Settings (below)
Singleton {
    id: root

    property bool isOpen: false
    property string page: "home"
    property var history: []

    // id: [title, glyph, parent, keywords]
    readonly property var pages: ({
        home: ["Home", "", "", "start overview"],
        system: ["System", "", "", "computer pc"],
        display: ["Display", "", "system", "screen monitor resolution scale refresh rotation brightness arrangement"],
        sound: ["Sound", "", "system", "audio volume speakers microphone output input mixer media playing"],
        notifications: ["Notifications", "", "system", "do not disturb dnd alerts history"],
        focus: ["Focus", "", "system", "pomodoro timer session"],
        power: ["Power & battery", "", "system", "sleep stay awake idle lock shut down restart battery"],
        storage: ["Storage", "", "system", "disks drives mount eject usb"],
        performance: ["Task Manager", "", "system", "cpu gpu memory ram vram network usage btop processes performance"],
        about: ["About", "", "system", "specifications device kernel os version"],
        bluetooth: ["Bluetooth & devices", "", "", "bluetooth pair devices batteries fans mouse keyboard headphones"],
        network: ["Network & internet", "", "", "wifi wi-fi wireless internet"],
        vpn: ["VPN", "", "network", "tailscale exit node vpn"],
        personalization: ["Personalization", "", "", "look"],
        background: ["Background", "", "personalization", "wallpaper picture desktop"],
        themes: ["Themes", "", "personalization", "colors colours theme setup dark light accent"],
        lighting: ["Dynamic Lighting", "", "personalization", "rgb openrgb lights led"],
        apps: ["Apps", "", "", "installed programs applications"],
        accounts: ["Accounts", "", "", "user your info claude usage limits"],
        time: ["Time & language", "", "", "date clock time zone weather moon calendar"],
        security: ["Privacy & security", "", "", "windows security vulnerabilities cve arch-audit"],
        update: ["Windows Update", "", "", "updates pacman checkupdates upgrade"],
    })
    // the left pane, in Windows' order
    readonly property var nav: ["home", "system", "bluetooth", "network", "personalization", "apps", "accounts", "time", "security", "update"]
    // for Search
    readonly property var index: Object.keys(pages).map(id => ({ id: id, title: pages[id][0], glyph: pages[id][1], keywords: pages[id][3] }))

    function title(id) { return pages[id]?.[0] ?? id; }
    function glyph(id) { return pages[id]?.[1] ?? ""; }
    function parentOf(id) { return pages[id]?.[2] ?? ""; }
    function section(id) { let p = id; while (parentOf(p)) p = parentOf(p); return p; }

    function open(id) {
        const target = pages[id] ? id : "home";
        if (isOpen && page !== target) history = history.concat([page]);
        page = target;
        if (!isOpen) { history = []; isOpen = true; }
        else raise.restart();
    }
    function go(id) { open(id); }
    function back() {
        if (!history.length) return;
        page = history[history.length - 1];
        history = history.slice(0, -1);
    }
    function close() { isOpen = false; }
    Timer { id: raise; interval: 50; onTriggered: Hyprland.dispatch(`hl.dsp.focus({ window = "title:^Settings$" })`) }

    // The shared deck's pages (every setup opens these by name) -> Settings pages
    readonly property var deckPages: ({
        helm: "system", radio: "sound", log: "notifications", almanac: "time", telemetry: "performance",
        hangar: "bluetooth", optics: "display", lamps: "lighting", chronometer: "focus", comms: "network", claude: "accounts",
    })

    IpcHandler {
        target: "deck"
        function open(page: string): void { root.open(root.deckPages[page] ?? page); }
        function toggle(): void { if (root.isOpen) root.close(); else root.open(root.page); }
        function close(): void { root.close(); }
    }
    IpcHandler {
        target: "settings"
        function open(page: string): void { root.open(page); }
        function close(): void { root.close(); }
    }
}
