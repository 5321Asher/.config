# Glyph

A desktop after Nothing OS, faithful to Shykid002's Nothing-rice: black, white dots, one red. Red
marks the one live thing on screen; nothing else is coloured. A vertical pill rail, a home screen of
Doto numbers and dot-matrix widgets, the screen's edges as the Glyph LED strips for volume,
brightness and notifications, and menus that are dials of dot-matrix words. This is the Quickshell
half of the **Glyph setup**; the rest (themes, fonts, Hyprland look, kitty, GTK/Qt, cursors, icons,
wallpapers) lives in `~/.config/theme/setups/glyph/`.

Switch to it with `~/.config/theme/theme setup glyph` (or the index / Walker: Style → Setup).
Run it on its own with `qs -c glyph`; it reloads live (`touch shell.qml` if a change doesn't show).

## Structure

```
shell.qml                what's on screen
theme/Theme.qml          every colour, font, size and timing
widgets/                 the kit: Dm (dot-matrix text/glyphs, a shader: shaders/dots.frag), Num (Doto
                         numbers), Lb/Label, Orb, Lit, Art, Icon, Blocks, Panel, Chip, KV, Btn,
                         Switch, Field, Controls, Stage
rail/Rail.qml            the vertical pill at the left: the mark (16-dot ring: index, right-click =
                         apps, red centre while recording/dictating), workspaces as dots, the title,
                         the clock in Doto, the tray as dots, the status glyphs, power
home/                    the home screen over the wallpaper: clock, date, greeting and a bento of
                         widgets (weather, month, ring gauge, now playing, system); only polls while
                         the workspace is empty. HomeState
edges/Edges.qml          the Glyph strips: right = volume/brightness, top = notification flash + the
                         island (pills that grow into cards), bottom = progress / focus timer
launcher/                Index + IndexState (root menu as a rotary dial), Launcher + ExecState (apps),
                         Clip + ClipboardState, Prompt + PromptState (theme/prompt)
quick/                   quick settings: a panel from the right edge (Wi-Fi, Bluetooth, round tiles,
                         levels, player, notifications). QuickState
prefs/                   settings: a column of Doto words on the left, the page on the right; pages/*
                         are the shared deck pages. PrefsState (owns the `deck` IPC)
deck/                    the dashboard that rises from the bottom edge. DeckState (`dash` IPC)
power/                   the power screen: a word dial and a ring of 60 dots (uptime, windows open)
menus/                   the cascade (Menus, MenuLayer, MenuPanel) and TrayMenus
lock/                    LockState (PAM), Lock, LockFace (the desktop dissolves into dots), pam/glyph-lock
utilities/               Overview, DictationOsd, PolkitPrompt, Debug (render to PNG for testing)
services/                the shared logic (Net, Capture, Displays, Backlight, Weather, Rgb…) plus
                         Status (vulnerabilities, updates), Elephant (the shared menus), Notifs
```

## How it maps onto the other setups

| shared | Glyph |
|---|---|
| root menu (SUPER + Space) | the index: `qs ipc call index toggle` (also the rail's mark) |
| app launcher (SUPER + CTRL + Space) | `qs ipc call exec toggle` (also right-click the mark) |
| clipboard (SUPER + V), `theme/prompt` | `qs ipc call clipboard toggle`; a question: `qs ipc call prompt ask <dir>` |
| `deck open <page>` | settings' sections: comms NETWORK, radio SOUND, log NOTES, almanac CALENDAR, telemetry SYSTEM (with vulnerabilities and updates), hangar DEVICES, optics DISPLAY (incl. display profiles), lamps LIGHTS, chronometer FOCUS, claude CLAUDE; `helm` opens quick settings |
| OSDs and notification pop-ups | the edges (Glyph strips) and the island |
| workspace overview | `overview toggle` |
| power menu | the power screen: `qs ipc call power toggle` (the rail's power glyph) |

The deck here is Glyph's own dashboard (`qs ipc call dash toggle`, Deck in the index, middle-click the
rail's clock): clock and the day's progress, weather, gauges, cores, network, now playing.

## IPC

```
qs ipc call index toggle | exec toggle | clipboard toggle | quick toggle | power toggle
qs ipc call deck open <page> | dash toggle | overview toggle
qs ipc call prompt ask <dir> | cancel
qs ipc call notifications clear | dnd
qs ipc call capture screenshot <mode> | toggleRecording | ocr
qs ipc call voxtype toggle | cancel
qs ipc call tray list | menu <n>
qs ipc call status sweep | report
qs ipc call lock lock | preview | close
qs ipc call debug grab <what> <file.png>
```

## Tweaking

Colours come from the themes (`~/.config/theme/setups/glyph/themes/dark.toml`, `light.toml`: the
greys and the one red), then `theme reload`. Sizes, timings and fonts are in `theme/Theme.qml`.
Fonts: Doto (dot-matrix display), Space Grotesk (text), Space Mono (labels, terminal), from the
reference repo (OFL) in `~/.local/share/fonts/glyph`; icons are JetBrainsMono Nerd Font glyphs.
After editing `widgets/shaders/dots.frag`: `qsb --qt6 -o dots.frag.qsb dots.frag`.
Wallpapers (dot grid + halftone orb, LED ring, plain grid) and Walker side pictures come from
`setups/glyph/wallpapers.py` (`~/.local/share/theme/venv/bin/python wallpapers.py`). GTK/Qt/Satty
styling, round dotted Papirus folders and the dot cursors are in `setups/glyph/style.py`.
The switch transition is `dots` (`theme/transition/dots.frag`).
