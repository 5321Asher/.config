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
    readonly property color green: palette.green ?? "#8fc79a"
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
    readonly property int bulgeWidth: 196           // the dome under the sundial
    readonly property int bulgeDepth: 31
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

    // ---------------------------------------------------------------- radio waveform (on the horizon)
    readonly property real waveAmplitude: 9         // px either side of the line at full level
    readonly property int waveStep: 7               // px between waveform points

    // ---------------------------------------------------------------- sundial (in the dome)
    readonly property int sundialCenterY: 28        // from the top of the panel
    readonly property int sundialRadius: 20
    readonly property int sundialTick: 2
    readonly property int sundialTickMajor: 6
    readonly property real sundialSweepWidth: 3

    // ---------------------------------------------------------------- orbital workspaces
    readonly property int orbitCount: 5             // planets always shown (more appear when in use)
    readonly property int orbitRx: 118              // the orbit ellipse
    readonly property int orbitRy: 7
    readonly property int orbitDrop: 4              // orbit centre below the band's middle
    readonly property real planetMin: 3.5           // at the back of the orbit
    readonly property real planetMax: 6             // at the front
    readonly property real planetActive: 7.5
    readonly property real starRadius: 2.2
    readonly property real moonRadius: 1.3
    readonly property real moonGap: 3.5             // moon orbit, beyond the planet's edge
    readonly property int moonPeriod: 14000         // ms per moon orbit
    readonly property int windowTitleWidth: 360
    readonly property int surveyButton: 24          // the eyepiece left of the orbit (opens the overview)

    // ---------------------------------------------------------------- instrument cluster
    readonly property int gaugeRadius: 13
    readonly property int gaugeCenterY: 19          // from the top of the panel
    readonly property int gaugeSpacing: 22
    readonly property real gaugeAlarm: 0.9          // past this share of full scale: signal red
    readonly property int tempMin: 20               // °C at the bottom of the temp gauge
    readonly property int tempMax: 100              // °C at full scale (so red from 92 °C)
    readonly property int sysInterval: 2000         // ms between CPU / memory / temp samples

    // ---------------------------------------------------------------- transmissions (notifications)
    readonly property int transmissionWidth: 380
    readonly property int transmissionTop: 56       // below the horizon
    readonly property int transmissionRight: 6
    readonly property int transmissionGap: 10
    readonly property int transmissionPad: 12
    readonly property int transmissionIcon: 34
    readonly property int transmissionLines: 6      // body lines before it's cut short
    readonly property int transmissionTimeout: 6000 // ms on screen (critical: until clicked)
    readonly property int typeInterval: 16          // ms per typing step
    readonly property int typeChars: 1              // characters per step
    readonly property int chamfer: 12               // the cut corner
    readonly property int scanlineSpacing: 3
    readonly property real scanlineOpacity: 0.07

    // ---------------------------------------------------------------- star-chart launcher
    readonly property int chartRadius: 400          // dial radius (smaller on small screens)
    readonly property real chartDim: 0.55           // darkening over the desktop behind it
    readonly property int constellationMax: 12      // matches joined by lines
    readonly property int launchBoost: 45           // max score added for apps you launch often

    // ---------------------------------------------------------------- console (root menu)
    readonly property int consoleHub: 150           // hub radius
    readonly property int consoleRing: 300          // instrument ring radius (grows for long menus)
    readonly property int consoleKnob: 64           // instrument diameter
    readonly property int consoleKnobPitch: 150     // px of ring per instrument
    readonly property int consoleGlyph: 24
    readonly property int consoleLabel: 150
    readonly property int consoleRingMax: 14        // more than this: a ledger list instead
    readonly property int consoleLedgerWidth: 560

    // ---------------------------------------------------------------- lock screen
    readonly property int lockRing: 150             // password ring radius
    readonly property int lockBeads: 24             // beads per lap of the ring
    readonly property int lockTimeSize: 64
    readonly property int lockSkyPeriod: 1200000    // ms per turn of the star field (20 min)

    // ---------------------------------------------------------------- utilities
    readonly property int overviewArc: 44           // how far the middle plates dip
    readonly property int dictationBottom: 56       // receiver plate above the bottom edge
    readonly property int dictationHeight: 60
    readonly property int dictationTrace: 220       // width of the live microphone trace
    readonly property int beaconInset: 28           // recording beacon from the left edge
    readonly property int polkitWidth: 440          // the clearance (admin password) plate

    // ---------------------------------------------------------------- control deck
    readonly property int deckWidth: 520
    readonly property int deckTop: 56               // below the horizon
    readonly property int deckBottom: 22
    readonly property int deckRight: 16
    readonly property int deckRail: 64             // width of the page rail
    readonly property int deckRailKnob: 38
    readonly property int deckKnob: 44
    readonly property int deckTile: 54
    readonly property int trayIcon: 16
    readonly property int traySlot: 24
    readonly property int coverSize: 104            // album art planet on the radio page
    readonly property int lampRing: 92              // hue ring radius on the lamps page

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
