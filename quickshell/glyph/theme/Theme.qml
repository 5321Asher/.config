pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Every colour, font, size and timing Glyph uses. Components never hardcode these.
//
// After Nothing OS (and Shykid002's Nothing-rice, "Glyph"): black, white dots, one red. Red marks
// the one live thing on screen (the play button, the recording dot, the selected word), never
// decoration. Colours come from the colour theme (dark / light): ~/.config/theme/theme writes
// colors.json next to shell.qml on every switch and this reloads it live. Fallbacks are Dark's.
Singleton {
    id: root

    property var palette: ({})
    readonly property bool light: bg.hslLightness > 0.5

    // ---------------------------------------------------------------- colour (the reference's names)
    readonly property color bg: palette.bg ?? "#000000"          // the wallpaper, the scrim under menus
    readonly property color s1: palette.s1 ?? "#0E0E0E"          // the rail, panels
    readonly property color s2: palette.s2 ?? "#1A1A1A"          // tiles, off switches, panel borders
    readonly property color s3: palette.s3 ?? "#2A2A2A"          // lines, unlit dots
    readonly property color mute: palette.mute ?? "#4A4A4A"      // inactive words
    readonly property color grey: palette.grey ?? "#8C8C8C"      // labels, secondary text
    readonly property color fg: palette.fg ?? "#F2F2F2"          // text, on, focus
    readonly property color ink: palette.ink ?? "#000000"        // text on a white (fg) pill
    readonly property color red: palette.red ?? "#D71921"        // the one live thing
    readonly property color glow: light ? Qt.rgba(0, 0, 0, 0.3) : Qt.rgba(1, 1, 1, 0.6)
    readonly property color scrim: light ? Qt.rgba(0.91, 0.91, 0.91, 0.82) : Qt.rgba(0, 0, 0, 0.76)

    function fade(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }
    function alpha(c, a) { return Qt.alpha(c, a); }
    function hex(c) { return c.toString().slice(1, 7).toUpperCase(); }

    // ---------------------------------------------------------------- type
    readonly property string dot: palette.fontDisplay ?? "Doto"              // numbers and short words, never under 26 px
    readonly property string ui: palette.fontSans ?? "Space Grotesk"
    readonly property string mono: "Space Mono"                              // tracked caps labels
    readonly property string nf: "JetBrainsMono Nerd Font"                   // icons (Material Design glyphs)

    // ---------------------------------------------------------------- scale
    // Everything is drawn in "design pixels" on a 1080-high canvas (widgets/Stage.qml) and scaled to
    // the screen's shorter side, so the 2560×1440 desktop, the portrait monitor and the laptop all
    // get the same proportions.
    function scaleFor(screen) {
        if (!screen) return 1;
        return Math.max(0.8, Math.min(1.4, Math.min(screen.width, screen.height) / 1080));
    }

    // ---------------------------------------------------------------- geometry
    readonly property int railWidth: 78        // the rail (left pill bar), design px incl. its 14 margin
    readonly property int radius: 36           // panels
    readonly property int tile: 220            // home bento cell

    // ---------------------------------------------------------------- motion
    // glide: ease-out-quart, no overshoot (the same curve as Hyprland's "glide" bezier in look.lua)
    readonly property var glide: [0.25, 1, 0.5, 1, 1, 1]
    readonly property int t: 350
    readonly property int fast: 160
    readonly property int normal: 250
    readonly property int slow: 350
    readonly property int easing: Easing.OutQuart
    readonly property int sysInterval: 2000
    readonly property int lockIntro: 1100
    readonly property int lockOutro: 450

    // ---------------------------------------------------------------- the shared services' old names
    // (services/ and lock/ came over from the other setups and read these)
    readonly property color bgDark: s1
    readonly property color surface: s1
    readonly property color line: s3
    readonly property color dim: grey
    readonly property color bright: fg
    readonly property color cyan: fg
    readonly property color yellow: palette.warn ?? "#D9C38A"
    readonly property color green: palette.green ?? "#9BB59A"
    readonly property string display: dot
    readonly property string sans: ui
    readonly property int label: 11
    readonly property int data: 13
    readonly property int title: 26
    readonly property int pad: 14
    readonly property int gap: 10
    readonly property real tracking: 1.6
    readonly property color panel: s1
    readonly property color textOnRed: "#FFFFFF"

    FileView {
        path: Quickshell.shellDir + "/colors.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.palette = JSON.parse(text());
            } catch (e) {
                console.warn("colors.json:", e);
            }
        }
    }
}
