pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Every colour, font, size and timing Observatory uses. Components never hardcode these.
//
// Colours come from the active colour theme: ~/.config/theme/theme writes colors.json next to
// shell.qml on every theme switch (palette + the setup's fonts) and this reloads it live.
// The values after ?? are the Deep Field defaults, used until colors.json exists.
Singleton {
    id: root

    property var palette: ({})

    // ---------------------------------------------------------------- colour
    readonly property color bg: palette.bg ?? "#0b0e17"
    readonly property color bgDark: palette.bgDark ?? "#07090f"
    readonly property color surface: palette.surface ?? "#141a28"
    readonly property color hover: palette.hover ?? "#1d2536"
    readonly property color border: palette.border ?? "#2a3246"
    readonly property color fg: palette.fg ?? "#d8d2c2"
    readonly property color dim: palette.dim ?? "#5d6679"

    readonly property color brass: palette.accent ?? "#c9a45c"
    readonly property color brassBright: palette.brassBright ?? Qt.lighter(brass, 1.35)
    readonly property color brassDeep: palette.brassDeep ?? Qt.darker(brass, 1.65)
    readonly property color brassMuted: palette.accentMuted ?? "#5e4d2c"
    readonly property color phosphor: palette.phosphor ?? palette.purple ?? "#6fd6d0"
    readonly property color phosphorDim: palette.phosphorDim ?? Qt.darker(phosphor, 2.4)
    readonly property color signal: palette.signal ?? palette.danger ?? "#d9534f"
    readonly property color warn: palette.warn ?? "#e0a84f"
    readonly property color starlight: palette.starlight ?? "#f3efe4"

    // Panels are ~85% opaque; Hyprland blurs what's behind them (look.lua: observatory-* layers)
    readonly property real panelOpacity: 0.85
    readonly property color panel: Qt.alpha(bg, panelOpacity)
    readonly property color panelTop: Qt.alpha(bgDark, 0.92)

    function alpha(c, a) { return Qt.alpha(c, a) }

    // ---------------------------------------------------------------- type
    // JetBrains Mono for data, Cormorant Garamond in small caps for labels (setup.toml [fonts])
    readonly property string fontData: palette.fontMono ?? "JetBrainsMono Nerd Font"
    readonly property string fontLabel: palette.fontDisplay ?? "Cormorant Garamond"
    readonly property int dataSize: 11
    readonly property int dataSizeSmall: 9
    readonly property int labelSize: 14
    readonly property int labelSizeLarge: 18
    readonly property real labelSpacing: 1.2

    // ---------------------------------------------------------------- horizon bar
    readonly property int lineWidth: 2              // the brass horizon, collapsed
    readonly property int barHeight: 36             // expanded panel
    readonly property int triggerHeight: 3          // hover strip along the top edge while collapsed
    readonly property int bulgeWidth: 172           // the dome under the sundial
    readonly property int bulgeDepth: 26
    readonly property int windowDepth: 96           // layer surface height (panel + dome + glow room)
    readonly property int hideDelay: 450            // ms the bar stays after the cursor leaves
    readonly property int lineTop: 1                // collapsed line's distance from the screen edge
    readonly property real glowBlur: 0.85           // MultiEffect shadowBlur, 0-1
    readonly property int glowRadius: 36            // MultiEffect blurMax
    readonly property real glowStrength: 1.0
    readonly property int ruleInset: 5              // engraved second rule above the lower edge
    readonly property real ruleOpacity: 0.28
    readonly property int tickSpacing: 18           // graduations along the horizon
    readonly property int tickMajorEvery: 5
    readonly property int tickLength: 3
    readonly property int tickMajorLength: 6
    readonly property real tickOpacity: 0.32
    readonly property int edgeFade: 160             // px over which the line fades out at screen edges

    // ---------------------------------------------------------------- motion
    // Smooth and mechanical: OutCubic, 250-400 ms
    readonly property int fast: 250
    readonly property int normal: 320
    readonly property int slow: 400
    readonly property int easing: Easing.OutCubic

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
