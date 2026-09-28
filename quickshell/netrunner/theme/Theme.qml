pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Every colour, font, size and timing Netrunner uses. Components never hardcode these.
//
// Colours come from the active profile (the colour theme): ~/.config/theme/theme writes colors.json
// next to shell.qml on every switch and this reloads it live. The values after ?? are Circuit's.
Singleton {
    id: root

    property var palette: ({})

    // ---------------------------------------------------------------- colour
    readonly property color bg: palette.bg ?? "#0a0d10"
    readonly property color bgDark: palette.bgDark ?? "#060809"
    readonly property color surface: palette.surface ?? "#10161b"      // panel fill
    readonly property color hover: palette.hover ?? "#17212a"
    readonly property color line: palette.border ?? "#26323c"          // hairlines, idle frames
    readonly property color dim: palette.dim ?? "#5e6c76"              // labels
    readonly property color fg: palette.fg ?? "#dce4e8"
    readonly property color bright: palette.bright ?? "#f2f6f8"        // values that matter, the clock
    readonly property color red: palette.accent ?? "#ff3a4c"           // the primary signal colour
    readonly property color redDim: palette.accentMuted ?? "#4a1820"
    readonly property color cyan: palette.purple ?? "#4fd6e0"          // the second: data, Japanese
    readonly property color cyanDim: palette.cyanDim ?? Qt.darker(cyan, 3)
    readonly property color yellow: palette.warn ?? "#f2d24b"
    readonly property color green: palette.green ?? "#4fe0a0"
    readonly property color onRed: palette.accentText ?? "#0a0d10"     // text on a red tag

    // Panels are translucent; Hyprland blurs what's behind them (look.lua: netrunner-* layers)
    readonly property real panelOpacity: 0.84
    readonly property color panel: Qt.alpha(bg, panelOpacity)

    function alpha(c, a) { return Qt.alpha(c, a) }

    // ---------------------------------------------------------------- type
    // Mono for labels and data (small, uppercase, tracked); Chakra Petch for display (the clock,
    // panel titles); Rajdhani for condensed headings; Noto CJK for the Japanese accents
    readonly property string mono: palette.fontMono ?? "JetBrainsMono Nerd Font"
    readonly property string display: palette.fontDisplay ?? "Chakra Petch"
    readonly property string sans: palette.fontSans ?? "Chakra Petch"
    readonly property string condensed: palette.fontSerif ?? "Rajdhani"
    readonly property string jp: "Noto Sans CJK JP"
    readonly property int label: 11            // the small tracked labels
    readonly property int data: 13
    readonly property int title: 26            // SYS.DIAG
    readonly property real tracking: 1.6       // letter spacing on labels

    // ---------------------------------------------------------------- geometry
    readonly property int chamfer: 12          // the cut corner on frames and panels
    readonly property int chamferSmall: 6
    readonly property int barHeight: 44
    readonly property int tagWidth: 104        // the red "GB//13" tag at the left of the bar
    readonly property int gap: 10
    readonly property int pad: 14

    // Window frames (frames/): drawn over the windows' edges
    readonly property int frameWidth: 1
    readonly property int frameInset: 0

    // The deck (special:deck): panels round the terminal
    readonly property int deckRight: 430       // SYS.DIAG column width
    readonly property int deckBottom: 290      // QUEUE / VULN / SIGNAL row height

    // The rig (control panel, deck pages): slides in from the right
    readonly property int rigWidth: 560

    // Notifications
    readonly property int toastWidth: 400
    readonly property int toastTimeout: 6500

    // ---------------------------------------------------------------- motion
    // Hard and fast: short cuts, a glitch now and then, no bounce
    readonly property int fast: 120
    readonly property int normal: 200
    readonly property int slow: 320
    readonly property int easing: Easing.OutCubic
    readonly property int glitch: 180          // text scramble on arrival
    readonly property int sysInterval: 2000

    readonly property int lockIntro: 600
    readonly property int lockOutro: 450

    // ---------------------------------------------------------------- palette file
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
