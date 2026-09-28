pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Every colour, font, size and timing Memphis uses. Components never hardcode these.
//
// Colours are Windows 98's system colours (3D face, highlight, shadow, active title…), taken from
// the active colour theme ("scheme", in 98 terms): ~/.config/theme/theme writes colors.json next to
// shell.qml on every theme switch and this reloads it live. The values after ?? are Windows Standard.
Singleton {
    id: root

    property var palette: ({})

    // ---------------------------------------------------------------- system colours
    readonly property color desktop: palette.desktop ?? "#008080"
    readonly property color face: palette.face ?? palette.bg ?? "#c0c0c0"          // 3D objects
    readonly property color light: palette.light ?? "#dfdfdf"                      // 3D light (inner bevel)
    readonly property color hilight: palette.hilight ?? "#ffffff"                  // 3D highlight (outer bevel)
    readonly property color shadow: palette.shadow ?? "#808080"                    // 3D shadow (inner bevel)
    readonly property color dkShadow: palette.dkShadow ?? "#000000"                // 3D dark shadow (outer bevel)
    readonly property color window: palette.window ?? "#ffffff"                    // fields, lists
    readonly property color windowText: palette.windowText ?? "#000000"
    readonly property color text: palette.btnText ?? "#000000"                     // text on the face
    readonly property color title: palette.title ?? "#000080"                      // active title bar, left
    readonly property color title2: palette.title2 ?? "#1084d0"                    // … fading to
    readonly property color titleText: palette.titleText ?? "#ffffff"
    readonly property color inactiveTitle: palette.inactiveTitle ?? "#808080"
    readonly property color inactiveTitle2: palette.inactiveTitle2 ?? "#b5b5b5"
    readonly property color inactiveTitleText: palette.inactiveTitleText ?? "#c0c0c0"
    readonly property color select: palette.select ?? "#000080"                    // selected items
    readonly property color selectText: palette.selectText ?? "#ffffff"
    readonly property color grayText: palette.grayText ?? "#808080"                // disabled
    readonly property color info: palette.info ?? "#ffffe1"                        // tooltips
    readonly property color infoText: palette.infoText ?? "#000000"
    readonly property color lcd: palette.lcd ?? "#000000"                          // meters, Sound Recorder
    readonly property color lcdText: palette.lcdText ?? "#00ff00"
    readonly property color link: "#0000ff"                                        // web-view links
    readonly property color danger: palette.danger ?? "#c00000"
    readonly property color warn: palette.warn ?? "#a06000"
    readonly property color green: palette.green ?? "#008000"
    // A dark scheme (High Contrast) needs light links and such
    readonly property bool dark: face.hslLightness < 0.35

    function alpha(c, a) { return Qt.alpha(c, a) }

    // ---------------------------------------------------------------- type
    // W95FA is drawn on a 16 px grid: keep it at 16 (or 32) and it stays crisp
    readonly property string font: palette.fontSans ?? "W95FA"
    readonly property string fontMono: palette.fontMono ?? "Mx437 IBM VGA 8x16"
    readonly property string fontSerif: palette.fontSerif ?? "Times New Roman"
    readonly property string fontBanner: palette.fontDisplay ?? "Arial Black"
    readonly property int fontSize: 16
    readonly property int fontSizeBig: 32

    // ---------------------------------------------------------------- metrics (Windows 98 x ~1.4)
    readonly property int bevel: 2              // a raised or sunken edge: two 1 px lines
    readonly property int taskbarHeight: 38
    readonly property int taskbarPad: 3         // taskbar edge to its buttons
    readonly property int taskButton: 30        // button height on the taskbar
    readonly property int taskButtonMax: 230    // widest a window's taskbar button gets
    readonly property int startWidth: 86
    readonly property int pagerButton: 26       // the workspace buttons beside Start
    readonly property int trayIcon: 20
    readonly property int traySlot: 26
    readonly property int icon: 20              // small icons (menus, title bars, lists)
    readonly property int iconBig: 40           // large icons (Start menu top level, Control Panel, dialogs)
    readonly property int titleHeight: 26       // window caption
    readonly property int titleButton: 22       // caption buttons (20 x 18 in 98, scaled)
    readonly property int frame: 4              // window frame, outside the caption
    readonly property int button: 32            // push button height
    readonly property int buttonWidth: 104      // OK / Cancel
    readonly property int field: 28             // text field / combo height
    readonly property int check: 18             // check box / radio size
    readonly property int menuItem: 28          // menu row height
    readonly property int menuItemBig: 48       // Start menu's top level
    readonly property int menuPad: 3
    readonly property int bannerWidth: 32       // the vertical "Memphis 98" band in the Start menu
    readonly property int scrollbar: 20
    readonly property int tabHeight: 28
    readonly property int pad: 12               // dialog content padding
    readonly property int gap: 8

    // ---------------------------------------------------------------- windows (shell dialogs)
    readonly property int propsWidth: 560       // a Properties sheet
    readonly property int propsHeight: 620
    readonly property int controlWidth: 820     // Control Panel
    readonly property int controlHeight: 560
    readonly property int webPane: 250          // Control Panel's left web-view pane

    // ---------------------------------------------------------------- notifications
    readonly property int toastWidth: 380
    readonly property int toastGap: 6
    readonly property int toastTimeout: 7000    // ms on screen (critical: until closed)
    readonly property int toastLines: 5

    // ---------------------------------------------------------------- timing
    // 98 was quick and linear: menus slide out, nothing bounces
    readonly property int menuDelay: 350        // hover before a submenu opens
    readonly property int menuSlide: 140        // menu slide-out
    readonly property int tooltipDelay: 600
    readonly property int fast: 120
    readonly property int normal: 200
    readonly property int easing: Easing.OutQuad
    readonly property int sysInterval: 2000     // ms between CPU / memory / temp samples

    // ---------------------------------------------------------------- lock (logon)
    readonly property int lockBlocks: 48        // dissolve block size
    readonly property int lockIntro: 500
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
