# .config

Arch Linux + Hyprland rice with swappable **setups**: whole desktops (shell, launcher, look, fonts,
cursors, icons, colour themes, wallpapers) switched with one command, each with its own colour themes.

| setup | look |
|---|---|
| **Sharp** | flat, square, quick: a tabbed bar along the top, Cascadia everywhere, nine colour themes |
| **Observatory** | brass instruments and phosphor readouts: a horizon line that opens into a panel, orbital workspaces, gauges, a star-chart launcher, a control deck; six colour themes |
| **Memphis** | your dad's computer in 1998: a grey taskbar with a Start button and the clock in the corner, Control Panel and Properties sheets for everything, Run…, a 98 logon box to unlock, Windows 98 widgets for GTK and Qt, an MS-DOS Prompt; seven 98 colour schemes |
| **Netrunner** | a cyberdeck in Night City: red and cyan on black glass, cut-corner window frames, a bar with a live ticker of real system state, a DECK dashboard (SYS.DIAG, daily gigs, vulnerability watch, signal), a rig control panel, a quickhack-style hub and EXEC launcher; seven profiles |
| **Disguise** | Windows 11: a centred taskbar on Acrylic, Start, Search, Quick Settings, the notification centre with calendar and Focus, Widgets, Task View, a Settings app, toasts, UAC, the Windows lock screen; Segoe UI Variable, Fluent icons, the Win11 icon theme and generated Bloom wallpapers; six themes (Windows light/dark, Glow, Sunrise, Flow, Captured Motion) |
| **Grimoire** | a wizard's spellbook on a candlelit desk: a leather bar of chapters with a hanging silk ribbon, a spine of reagents (heat crystal, potion vials for CPU and memory, a mana tube for the battery) and a candle that burns down with your uptime; a tarot-spread root menu (the arcana) in gold foil; a launcher that draws each app's seal in ink (Witch Hat Atelier-style glyphs whose parts mean something); a commonplace book for the clipboard; an open-book codex whose pages really turn; notifications as sealed letters; the closed book as a lock screen; the burn transition; five themes (Oxblood, Nightshade, Verdigris, Ember, Vellum) |

```
~/.config/theme/theme setup observatory     switch setup (or Style → Setup in the menu)
~/.config/theme/theme set aurora            switch colour theme within the setup
~/.config/theme/theme                       manager (themes, wallpapers, images)
```

- `theme/` — the setup and theme system (`theme`, `writers.py`, `tui.py`, `iconkit.py`) and the
  setups themselves (`theme/setups/<setup>/`). How setups work, what every setup must provide and the step-by-step procedure for adding one: [theme/SETUPS.md](theme/SETUPS.md)
- `quickshell/<setup>/` — each setup's shell ([Observatory's README](quickshell/observatory/README.md), [Memphis's](quickshell/memphis/README.md), [Netrunner's](quickshell/netrunner/README.md), [Disguise's](quickshell/disguise/README.md), [Grimoire's](quickshell/grimoire/README.md))
- `hypr/` — Hyprland (Lua config); `look.lua` is linked in from the active setup
- `elephant/menus/` — the menus every setup's launcher shows
- `walker/themes/<setup>/` — each setup's Walker theme

Generated files (colours, fonts, icon and cursor themes) are written on every theme switch and are
not tracked.

Every setup has the same features in its own look: root menu and app launcher, notifications,
media, Wi-Fi / Bluetooth / Tailscale, screenshots and recording, dictation, focus timer, lighting,
a lock screen, a polkit prompt, a workspace overview (which fits portrait monitors too), and a
**vulnerability watch + pending updates** (`arch-audit`, `checkupdates`; `qs ipc call updates sweep`
in Sharp, Observatory, Memphis and Disguise, `status sweep` in Netrunner). Wallpaper changes use each setup's
transition (fade, wipe, iris, dissolve, glitch, burn).

Packages beyond Hyprland and Quickshell that the setups use: `arch-audit`, `pacman-contrib`,
`noto-fonts-cjk` (Netrunner's Japanese), `chicago95-theme` and `oldschool-pc-font-ttf`
(Memphis). Fonts that aren't packaged live in `~/.local/share/fonts` (W95FA; Chakra Petch and
Rajdhani; Segoe UI Variable and Segoe Fluent Icons, Microsoft's designer downloads, for Disguise;
Grimoire's, from Google Fonts: `theme/setups/grimoire/fonts.sh`).
Disguise's icons are the Win11 icon theme (yeyushengfan258/Win11-icon-theme, installed into
`~/.local/share/icons`).

