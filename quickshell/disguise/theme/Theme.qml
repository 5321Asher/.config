pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Every colour, font, size and timing Disguise uses. Components never hardcode these.
//
// Colours are Windows 11's Fluent tokens (Mica, card, control fills and strokes, text levels, the
// accent), from the active colour theme: ~/.config/theme/theme writes colors.json next to shell.qml
// on every theme switch and this reloads it live. The values after ?? are Windows (light).
Singleton {
    id: root

    property var palette: ({})

    // ---------------------------------------------------------------- colours
    readonly property bool dark: (palette.appearance ?? "") === "dark" || mica.hslLightness < 0.4
    readonly property color mica: palette.mica ?? "#f3f3f3"                 // window background
    readonly property color micaAlt: palette.micaAlt ?? "#eeeeee"
    readonly property color taskbar: palette.taskbar ?? "#eeeeee"
    readonly property color flyout: palette.flyout ?? "#f9f9f9"             // Acrylic flyouts, menus
    readonly property color card: palette.card ?? "#fbfbfb"
    readonly property color cardHover: palette.cardHover ?? "#f6f6f6"
    readonly property color cardStroke: palette.cardStroke ?? "#e5e5e5"
    readonly property color control: palette.control ?? "#fdfdfd"           // buttons, fields
    readonly property color controlHover: palette.controlHover ?? "#f6f6f6"
    readonly property color controlPressed: palette.controlPressed ?? "#f2f2f2"
    readonly property color controlStroke: palette.controlStroke ?? "#e3e3e3"
    readonly property color controlStrokeBottom: palette.controlStrokeBottom ?? "#c9c9c9"
    readonly property color divider: palette.divider ?? "#e5e5e5"
    readonly property color field: palette.field ?? "#ffffff"
    readonly property color text: palette.text ?? "#1b1b1b"
    readonly property color text2: palette.text2 ?? "#5d5d5d"               // secondary
    readonly property color text3: palette.text3 ?? "#8a8a8a"               // tertiary
    readonly property color textDisabled: palette.textDisabled ?? "#a0a0a0"
    readonly property color strong: palette.strong ?? "#8a8a8a"             // toggle edges, slider rails
    readonly property color accent: palette.accent ?? "#005fb8"
    readonly property color accentHover: palette.accentHover ?? "#1a6ec0"
    readonly property color accentPressed: palette.accentPressed ?? "#327dc6"
    readonly property color accentText: palette.accentText ?? "#ffffff"     // on the accent
    readonly property color accentLink: palette.accentLink ?? "#003e92"     // accent-coloured text
    readonly property color accentMuted: palette.accentMuted ?? "#cce2f6"
    readonly property color desktop: palette.desktop ?? "#dbe6f4"
    readonly property color danger: palette.danger ?? "#c42b1c"
    readonly property color warn: palette.warn ?? "#9d5d00"
    readonly property color green: palette.green ?? "#0f7b0f"
    readonly property color closeRed: "#c42b1c"
    // "subtle" fills: what Windows lays over a transparent thing you point at / press
    readonly property color subtle: Qt.alpha(text, dark ? 0.065 : 0.04)
    readonly property color subtle2: Qt.alpha(text, dark ? 0.04 : 0.025)
    readonly property color smoke: Qt.alpha("#000000", dark ? 0.45 : 0.3)
    readonly property color shadow: Qt.alpha("#000000", dark ? 0.5 : 0.18)
    readonly property color flyoutStroke: Qt.alpha("#000000", dark ? 0.4 : 0.1)
    // how opaque the Acrylic tints are (Hyprland blurs what's behind them)
    readonly property real acrylic: dark ? 0.86 : 0.82
    readonly property real taskbarAlpha: dark ? 0.84 : 0.8

    // the Windows logo's blues (they don't follow the accent, on Windows either)
    readonly property color logoTop: "#2aa6f4"
    readonly property color logoBottom: "#0067c0"

    function alpha(c, a) { return Qt.alpha(c, a) }

    // aliases the shared services use
    readonly property color select: accent
    readonly property color windowText: text

    // ---------------------------------------------------------------- type (Segoe UI Variable)
    readonly property string font: palette.fontSans ?? "Segoe UI Variable Static Text"
    readonly property string fontDisplay: palette.fontDisplay ?? "Segoe UI Variable Static Display"
    readonly property string fontSmall: "Segoe UI Variable Static Small"
    readonly property string fontMono: palette.fontMono ?? "CaskaydiaMono Nerd Font"
    readonly property string icons: "Segoe Fluent Icons"
    // Windows' type ramp (px): caption 12, body 14, subtitle 20, title 28, display 68
    readonly property int caption: 12
    readonly property int body: 14
    readonly property int bodyLarge: 18
    readonly property int subtitle: 20
    readonly property int title: 28
    readonly property int titleLarge: 40
    readonly property int display: 68

    // ---------------------------------------------------------------- metrics (Windows 11 at 100 %)
    readonly property int radius: 4             // controls
    readonly property int radiusLarge: 8        // cards, flyouts, windows
    readonly property int taskbarHeight: 48
    readonly property int taskButton: 40        // a taskbar button (square)
    readonly property int taskIcon: 24
    readonly property int trayIcon: 16
    readonly property int controlHeight: 32          // a button's / field's height
    readonly property int row: 40               // a list row
    readonly property int menuRow: 32           // a context-menu row
    readonly property int menuWidth: 240
    readonly property int pad: 16
    readonly property int gap: 8
    readonly property int flyoutGap: 12         // flyouts float this far above the taskbar
    readonly property int startWidth: 642
    readonly property int startHeight: 726
    readonly property int quickWidth: 360
    readonly property int widgetsWidth: 720
    readonly property int settingsNav: 280

    // ---------------------------------------------------------------- notifications
    readonly property int toastWidth: 364
    readonly property int toastTimeout: 6000    // ms on screen (critical: until closed)

    // ---------------------------------------------------------------- timing (Fluent motion)
    readonly property int fast: 150
    readonly property int normal: 250
    readonly property int slow: 350
    readonly property int easing: Easing.OutCubic
    readonly property var decelerate: [0, 0, 0, 1, 1, 1]          // Fluent's "fast out, slow in"
    readonly property int sysInterval: 2000     // ms between CPU / memory / temp samples

    // ---------------------------------------------------------------- lock
    readonly property int lockIntro: 450
    readonly property int lockOutro: 400

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
