pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The rig: Netrunner's control panel, sliding in from the right. Its pages are the shared deck
// pages (what `qs ipc call deck open <page>` names in every setup):
//   helm radio log almanac telemetry hangar optics lamps chronometer comms claude
Singleton {
    id: root

    property bool open: false
    property string page: "helm"

    readonly property var pages: [
        { id: "helm", code: "01", title: "helm", jp: "操縦", sub: "switches // levels // capture // power" },
        { id: "comms", code: "02", title: "comms", jp: "通信", sub: "wi-fi // bluetooth // tailscale" },
        { id: "radio", code: "03", title: "radio", jp: "音響", sub: "now playing // mixer // devices" },
        { id: "log", code: "04", title: "log", jp: "記録", sub: "messages // do not disturb" },
        { id: "almanac", code: "05", title: "almanac", jp: "暦", sub: "calendar // weather // moon" },
        { id: "telemetry", code: "06", title: "telemetry", jp: "遠隔測定", sub: "cpu // gpu // memory // net" },
        { id: "hangar", code: "07", title: "hangar", jp: "格納庫", sub: "drives // batteries // fans" },
        { id: "optics", code: "08", title: "optics", jp: "光学", sub: "screens // layout // brightness" },
        { id: "lamps", code: "09", title: "lamps", jp: "照明", sub: "rgb // follow profile" },
        { id: "chronometer", code: "10", title: "chrono", jp: "時計", sub: "focus // pomodoro // timer" },
        { id: "claude", code: "11", title: "claude", jp: "助手", sub: "account // usage // limits" },
    ]
    readonly property var current: pages.find(p => p.id === page) ?? pages[0]

    function show(p) {
        if (pages.some(x => x.id === p)) page = p;
        open = true;
    }
    function toggleTo(p) {
        if (open && page === p) open = false;
        else show(p);
    }

    IpcHandler {
        target: "deck"
        function toggle(): void { root.open = !root.open; }
        function open(page: string): void { root.show(page); }
        function close(): void { root.open = false; }
    }
}
