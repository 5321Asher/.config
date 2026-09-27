pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Flat, sharp corners, outlined accents. Colours come from the chosen colour theme: ~/.config/theme/theme
// writes colors.json (and every other app's colours) on a theme switch, and this reloads live.
// Tokyo Night is the fallback until colors.json exists.
Singleton {
    id: root

    property var palette: ({})

    readonly property color bg: palette.bg ?? "#1a1b26"
    readonly property color bgDark: palette.bgDark ?? "#16161e"
    readonly property color surface: palette.surface ?? "#292e42"
    readonly property color hover: palette.hover ?? "#3b4261"
    readonly property color accent: palette.accent ?? "#7aa2f7"
    readonly property color accentMuted: palette.accentMuted ?? "#3d59a1"
    readonly property color fg: palette.fg ?? "#c0caf5"
    readonly property color dim: palette.dim ?? "#565f89"
    readonly property color border: palette.border ?? "#414868"
    readonly property color purple: palette.purple ?? "#bb9af7"
    readonly property color warn: palette.warn ?? "#e0af68"
    readonly property color danger: palette.danger ?? "#f7768e"
    readonly property color green: palette.green ?? "#9ece6a"

    readonly property string font: "CaskaydiaMono Nerd Font Mono"
    readonly property int barHeight: 36

    // Palette written by ~/.config/theme/theme
    FileView {
        path: Quickshell.shellDir + "/colors.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.palette = JSON.parse(text());
            } catch (e) {}
        }
    }
}
