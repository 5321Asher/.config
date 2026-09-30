pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Every colour, font, size and timing Grimoire uses. Components never hardcode these.
//
// Colours come from the active colour theme: ~/.config/theme/theme writes colors.json next to
// shell.qml on every switch and this reloads it live. The values after ?? are Oxblood's.
Singleton {
    id: root

    property var palette: ({})
    readonly property bool light: (palette.appearance ?? "") === "light" || Qt.color(leather).hslLightness > 0.6

    // ---------------------------------------------------------------- colour
    // leather: the bar, the spine, book covers
    readonly property color leather: palette.bg ?? "#2a1414"
    readonly property color leatherDark: palette.bgDark ?? "#190b0b"
    readonly property color leatherLight: palette.surface ?? "#3a1c1a"
    readonly property color hover: palette.hover ?? "#4a2622"
    readonly property color tooling: palette.border ?? "#5e3e28"        // blind tooling, hairlines on leather
    readonly property color dim: palette.dim ?? "#a8957a"              // faded ink on leather
    readonly property color fg: palette.fg ?? "#e8dcc0"                // text on leather
    // gold leaf
    readonly property color gold: palette.accent ?? "#c9a24a"
    readonly property color goldBright: palette.goldBright ?? "#f2d98c"
    readonly property color goldDeep: palette.goldDeep ?? "#8a6a2a"
    readonly property color goldMuted: palette.accentMuted ?? "#5e4520"
    readonly property color onGold: palette.accentText ?? "#2a1414"
    // the arcane glow: active and magical states
    readonly property color arcane: palette.purple ?? "#9b7fe0"
    // parchment pages and their ink
    readonly property color page: palette.parchment ?? "#e8dcc0"
    readonly property color pageDeep: palette.parchmentDeep ?? "#c9b48a"
    readonly property color ink: palette.ink ?? "#2f1d14"
    readonly property color inkDim: palette.inkDim ?? "#6e5642"
    readonly property color rubric: palette.rubric ?? "#9c2a22"        // red-ink headings on a page
    readonly property color wax: palette.wax ?? "#8c1f2a"
    readonly property color flame: palette.flame ?? "#ffb04a"
    readonly property color warn: palette.warn ?? "#e3a948"
    readonly property color danger: palette.danger ?? "#c4453a"
    readonly property color green: palette.green ?? "#8fb573"
    // the veil behind the circle, the codex, the overview: always a dark, warm night
    readonly property color veil: light ? Qt.darker(ink, 1.3) : leatherDark

    // services use these names
    readonly property color red: danger
    readonly property color yellow: warn
    readonly property color cyan: arcane

    function alpha(c, a) { return Qt.alpha(c, a) }
    function mix(a, b, t) {
        const x = Qt.color(a), y = Qt.color(b);
        return Qt.rgba(x.r + (y.r - x.r) * t, x.g + (y.g - x.g) * t, x.b + (y.b - x.b) * t, x.a + (y.a - x.a) * t);
    }

    // ---------------------------------------------------------------- type
    readonly property string body: palette.fontSans ?? "Cardo"                      // everything you read
    readonly property string blackletter: palette.fontDisplay ?? "UnifrakturMaguntia" // titles, illuminated capitals
    readonly property string mono: palette.fontMono ?? "IBM Plex Mono"
    readonly property string display: "Cormorant Garamond"  // headings, chapter names, the clock
    readonly property string caps: "Cinzel"                 // engraved small caps: labels
    readonly property string decorative: "Cinzel Decorative"
    readonly property string runic: "Noto Sans Runic"
    readonly property string symbols: "Noto Sans Symbols 2"
    readonly property string glyphs: "JetBrainsMono Nerd Font"   // the odd icon

    readonly property int small: 12
    readonly property int text: 15
    readonly property int large: 18
    readonly property int heading: 22
    readonly property int title: 38
    readonly property real capsTracking: 1.4

    // ---------------------------------------------------------------- geometry
    readonly property int barHeight: 46
    readonly property int ribbonDrop: 30        // how far the chapter ribbon hangs below the bar
    readonly property int spineWidth: 66        // the left margin: reagents and the candle
    readonly property int gap: 12
    readonly property int pad: 16
    readonly property int radius: 3

    // the codex (control panel): an open book, two pages
    readonly property int codexPageWidth: 520
    readonly property int codexHeight: 760

    // letters (notifications)
    readonly property int letterWidth: 380
    readonly property int letterTimeout: 7000

    // the candle: how many hours from a fresh taper to a stub
    readonly property real candleHours: 10

    // ---------------------------------------------------------------- motion
    // magical but restrained: soft ease-outs, glows that breathe, nothing bounces
    readonly property int fast: 160
    readonly property int normal: 280
    readonly property int slow: 480
    readonly property int stately: 800
    readonly property int easing: Easing.OutCubic
    readonly property int sysInterval: 2000

    readonly property int lockIntro: 900
    readonly property int lockOutro: 2000

    // ---------------------------------------------------------------- shaders
    readonly property string shaders: Quickshell.shellDir + "/shaders/"

    // ---------------------------------------------------------------- runes
    // Latin letters -> Elder Futhark (what the circle inscribes as you type, and the lock's word)
    readonly property var futhark: ({
        a: "ᚨ", b: "ᛒ", c: "ᚲ", d: "ᛞ", e: "ᛖ", f: "ᚠ", g: "ᚷ", h: "ᚺ", i: "ᛁ", j: "ᛃ", k: "ᚲ", l: "ᛚ", m: "ᛗ",
        n: "ᚾ", o: "ᛟ", p: "ᛈ", q: "ᚴ", r: "ᚱ", s: "ᛊ", t: "ᛏ", u: "ᚢ", v: "ᚡ", w: "ᚹ", x: "ᛪ", y: "ᛃ", z: "ᛉ",
        "0": "ᛜ", "1": "ᛁ", "2": "ᚢ", "3": "ᚦ", "4": "ᚨ", "5": "ᚱ", "6": "ᚲ", "7": "ᚷ", "8": "ᚹ", "9": "ᚺ",
        " ": "᛫", "-": "᛬", ".": "᛭", "_": "᛬",
    })
    readonly property string allRunes: "ᚠᚢᚦᚨᚱᚲᚷᚹᚺᚾᛁᛃᛇᛈᛉᛊᛏᛒᛖᛗᛚᛜᛞᛟ"
    function rune(ch) {
        const c = (ch ?? "").toLowerCase();
        return futhark[c] ?? allRunes[Math.abs(c.charCodeAt(0) || 0) % allRunes.length];
    }
    function runes(s) { return Array.from(s ?? "").map(rune).join(""); }

    function roman(n) {
        if (n <= 0 || n >= 4000) return String(n);
        const t = [[1000, "M"], [900, "CM"], [500, "D"], [400, "CD"], [100, "C"], [90, "XC"], [50, "L"], [40, "XL"],
                   [10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]];
        let out = "";
        for (const [v, s] of t) while (n >= v) { out += s; n -= v; }
        return out;
    }
    function ordinal(n) {
        const s = ["th", "st", "nd", "rd"], v = n % 100;
        return n + (s[(v - 20) % 10] ?? s[v] ?? s[0]);
    }

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
