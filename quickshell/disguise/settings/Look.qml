pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Personalization's data: the wallpapers (~/Pictures/Wallpapers, the theme's own), the one showing
// (skwd-wall), this setup's colour themes and the setups, through ~/.config/theme/theme.
Singleton {
    id: root

    readonly property string themeTool: Quickshell.env("HOME") + "/.config/theme/theme"
    property var walls: []
    property string wallNow: ""
    property var themes: []             // [{ id, name, accent, current }]
    property var setups: []             // [{ id, name, about, current }]

    function refresh() { wallsProc.running = true; themesProc.running = true; setupsProc.running = true; }
    function setWall(p) { Quickshell.execDetached(["skwd-helm", "apply", p]); wallNow = p; }
    function randomWall() { Quickshell.execDetached([themeTool, "wall"]); }
    function setTheme(id) { Quickshell.execDetached([themeTool, "set", id]); }
    function setSetup(id) { Quickshell.execDetached([themeTool, "setup", id]); }
    function isVideo(p) { return /\.(mp4|webm|mkv)$/i.test(p); }
    function base(p) { return p.split("/").pop().replace(/\.[^.]+$/, ""); }

    Process {
        id: wallsProc
        command: ["sh", "-c", "find -L \"$HOME/Pictures/Wallpapers\" -maxdepth 3 -type f \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.mp4' -o -iname '*.gif' \\) | sort; echo '--'; cat \"$HOME/.cache/skwd-wall-v2/last-wallpaper.json\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [list, last] = text.split("\n--\n");
                root.walls = (list ?? "").split("\n").filter(l => l.trim());
                try { root.wallNow = JSON.parse(last).path ?? ""; } catch (e) {}
            }
        }
    }
    Process {
        id: themesProc
        command: [root.themeTool, "rows", "themes"]
        stdout: StdioCollector {
            onStreamFinished: root.themes = text.split("\n").filter(l => l).map(l => l.split("\t"))
                .map(r => ({ id: r[0], name: r[1], accent: r[2], current: r[4] === "1" }))
        }
    }
    Process {
        id: setupsProc
        command: [root.themeTool, "rows", "setups"]
        stdout: StdioCollector {
            onStreamFinished: root.setups = text.split("\n").filter(l => l).map(l => l.split("\t"))
                .map(r => ({ id: r[0], name: r[1], about: r[2], current: r[5] === "1" }))
        }
    }
    Component.onCompleted: refresh()
}
