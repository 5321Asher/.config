pragma Singleton

import QtQuick
import Quickshell
import "../theme"
import Quickshell.Io
import Quickshell.Hyprland

// Monitor layout: read from Hyprland, edit a draft, apply live with a revert countdown,
// and save to ~/.config/hypr/monitors.lua (required from hyprland.lua). Named display profiles
// (every monitor's mode, position, scale, rotation) go through ~/.config/theme/display.
Singleton {
    id: root

    readonly property string configPath: Quickshell.env("HOME") + "/.config/hypr/monitors.lua"
    readonly property int confirmSeconds: 15

    // Current state from Hyprland: [{ name, description, model, modes, enabled, width, height, refresh, x, y, scale, transform, mirror }]
    property var monitors: []
    // Editable copy
    property var draft: []
    // Layout to go back to if a change isn't confirmed
    property var previous: []
    property int countdown: 0
    property string error: ""

    // Display profiles (~/.config/theme/display, shared by every setup):
    // [{ id, name, summary, active, fits }]
    readonly property string profileTool: Quickshell.env("HOME") + "/.config/theme/display"
    property var profiles: []
    readonly property string activeProfile: (profiles.find(p => p.active) ?? { id: "" }).id

    readonly property bool dirty: JSON.stringify(strip(draft)) !== JSON.stringify(strip(monitors))
    readonly property bool confirming: countdown > 0
    readonly property bool mirrored: draft.some(m => m.mirror)

    function strip(list) {
        return list.map(m => ({ n: m.name, e: m.enabled, w: m.width, h: m.height, r: m.refresh, x: m.x, y: m.y, s: m.scale, t: m.transform, m: m.mirror }));
    }

    function clone(list) {
        return JSON.parse(JSON.stringify(list));
    }

    function refresh() {
        if (!reader.running)
            reader.running = true;
    }

    function update(name, changes) {
        draft = draft.map(m => m.name === name ? Object.assign({}, m, changes) : m);
    }

    function resetDraft() {
        draft = clone(monitors);
        error = "";
    }

    // Logical size on screen (after scale and rotation)
    function logical(m) {
        const rotated = m.transform % 2 === 1;
        return { w: (rotated ? m.height : m.width) / m.scale, h: (rotated ? m.width : m.height) / m.scale };
    }

    // Mirror every other monitor onto `source`, or undo it
    function setMirror(on, source) {
        draft = draft.map(m => Object.assign({}, m, { mirror: on && m.name !== source && m.enabled ? source : "" }));
    }

    function luaFor(list) {
        return list.map(m => {
            if (!m.enabled)
                return `hl.monitor({ output = "${m.name}", disabled = true })`;
            const parts = [
                `output = "${m.name}"`,
                `mode = "${m.width}x${m.height}@${m.refresh}"`,
                `position = "${Math.round(m.x)}x${Math.round(m.y)}"`,
                `scale = "${m.scale}"`,
                `transform = ${m.transform}`,
                // explicit: a rule without it doesn't turn a disabled screen back on (so "Use this
                // screen" -> off -> revert left the screen dark)
                `disabled = false`
            ];
            // always stated: without it a rule doesn't end mirroring (a reverted mirror stayed on)
            parts.push(`mirror = "${m.mirror ?? ""}"`);
            return `hl.monitor({ ${parts.join(", ")} })`;
        }).join("\n");
    }

    function run(list) {
        error = "";
        applier.command = ["hyprctl", "eval", luaFor(list)];
        applier.running = true;
    }

    // Apply the draft, then wait for confirmation
    function apply() {
        previous = clone(monitors);
        run(draft);
        countdown = confirmSeconds;
    }

    function keep() {
        countdown = 0;
        save(draft);
    }

    function revert() {
        countdown = 0;
        run(previous);
        draft = clone(previous);
    }

    function save(list) {
        saver.setText("-- Monitor layout. Written by the Quickshell display panel; edit freely.\n\n"
            + luaFor(list).split("\n").map(l => l.replace(/^hl\.monitor\(\{ /, "hl.monitor({\n  ").replace(/, /g, ",\n  ").replace(/ \}\)$/, "\n})")).join("\n\n") + "\n");
    }

    function refreshProfiles() {
        if (!profileReader.running)
            profileReader.running = true;
    }

    // Switch to a saved profile (every monitor at once; no revert countdown: it's a known layout)
    function applyProfile(id) {
        profileRunner.command = [profileTool, "apply", id];
        profileRunner.running = true;
    }

    // Save the live layout (not the draft) under a name; an existing name is overwritten
    function saveProfile(name) {
        if (!name.trim())
            return;
        profileRunner.command = [profileTool, "save", name.trim()];
        profileRunner.running = true;
    }

    function deleteProfile(id) {
        profileRunner.command = [profileTool, "delete", id];
        profileRunner.running = true;
    }

    // Parse "1920x1080@239.76Hz" into { width, height, refresh }
    function parseMode(s) {
        const m = /^(\d+)x(\d+)@([\d.]+)/.exec(s);
        return m ? { width: +m[1], height: +m[2], refresh: +m[3] } : null;
    }

    Process {
        id: reader
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let list;
                try {
                    list = JSON.parse(text);
                } catch (e) {
                    return;
                }
                root.monitors = list.map(m => {
                    const modes = (m.availableModes ?? []).map(root.parseMode).filter(x => x);
                    // Use the listed mode closest to the live refresh rate, so values round-trip cleanly
                    const same = modes.filter(x => x.width === m.width && x.height === m.height);
                    const best = same.sort((a, b) => Math.abs(a.refresh - m.refreshRate) - Math.abs(b.refresh - m.refreshRate))[0];
                    return {
                        name: m.name,
                        description: m.description ?? "",
                        model: m.model || m.make || "",
                        modes: modes,
                        enabled: !m.disabled,
                        width: m.width,
                        height: m.height,
                        refresh: best ? best.refresh : Math.round(m.refreshRate * 100) / 100,
                        x: m.x,
                        y: m.y,
                        scale: m.scale,
                        transform: m.transform,
                        mirror: m.mirrorOf && m.mirrorOf !== "none" ? m.mirrorOf : ""
                    };
                }).sort((a, b) => a.x - b.x);
                if (!root.confirming)
                    root.draft = root.clone(root.monitors);
            }
        }
    }

    Process {
        id: applier
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                if (t && t !== "ok")
                    root.error = t;
            }
        }
        onExited: refreshSoon.restart()
    }

    Process {
        id: profileReader
        command: [root.profileTool, "rows"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.profiles = text.split("\n").filter(l => l).map(l => {
                    const f = l.split("\t");
                    return { id: f[0], name: f[1], summary: f[2], active: f[3] === "1", fits: f[4] === "1" };
                });
            }
        }
    }

    Process {
        id: profileRunner
        stderr: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                if (t)
                    root.error = t.replace(/^display: /, "");
            }
        }
        onStarted: root.error = ""
        onExited: {
            root.refreshProfiles();
            refreshSoon.restart();
        }
    }

    Timer {
        id: refreshSoon
        interval: 600
        onTriggered: {
            root.refresh();
            root.refreshProfiles();
        }
    }

    FileView {
        id: saver
        path: root.configPath
        blockLoading: false
        atomicWrites: true
    }

    Timer {
        running: root.confirming
        repeat: true
        interval: 1000
        onTriggered: {
            root.countdown--;
            if (root.countdown === 0)
                root.revert();
        }
    }

    // Keep up with hotplugs and changes made elsewhere
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name.startsWith("monitor") || event.name === "configreloaded")
                refreshSoon.restart();
        }
    }

    Component.onCompleted: {
        refresh();
        refreshProfiles();
    }
}
