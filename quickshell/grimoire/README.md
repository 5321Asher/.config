# Grimoire

The desktop as a wizard's spellbook on a candlelit desk: oxblood leather, aged parchment, gold leaf
and glowing runes. This is the Quickshell half of the **Grimoire setup**; the rest (colour themes,
fonts, Hyprland look, kitty, GTK/Qt, icons, cursors, wallpapers, Walker, the burn transition) lives in
`~/.config/theme/setups/grimoire/`.

Switch to it with `~/.config/theme/theme setup grimoire` (or the table of contents / Walker: Style →
Setup). Run it on its own with `qs -c grimoire`; it reloads live (`touch shell.qml` if a change doesn't
show).

## What's on screen

| piece | what it is |
|---|---|
| **the bar** (`bar/`) | the head of the book: tooled leather over a gilt edge. The clasp in the corner opens the table of contents (right-click: the codex). Chapters (workspaces) in Roman numerals, a violet silk ribbon hanging from the open one; it swings when you turn chapters. The running head (chapter and the page you're on) in the middle; on the right, whatever runs (scrying = recording, the scribe = dictation, the hourglass = focus timer), the tray, the vigil (stay awake), the letters, the moon and the hour. |
| **the spine** (`spine/`) | down the left: raised bands with the reagents between them: the heat crystal (CPU temperature: arcane when cool, gold, then flame, red past 85°), two potion vials (CPU in a flask, memory in a tube, bubbling), the mana tube (the battery; "ley" on mains). The spine's title in blackletter, and at its foot **the candle**: your uptime. Lit at boot, it burns down over `Theme.candleHours`, wax runs down its sides and pools in the dish, the flame (a shader) never stops flickering, and it relights when you reboot. Hover anything for a note; click to open its chapter of the codex. |
| **the summoning circle** (`launcher/Circle.qml`) | the app launcher. Letters you type are inscribed round the inner ring as runes; the seven likeliest programs sit on a heptagram's points (Tab turns the star); Enter ignites it, spins it and collapses it into the new window as it opens. No match: it casts what you wrote as a command. |
| **the table of contents** (`launcher/ContentsState.qml`, `menus/`) | the root menu: a parchment contents page (numerals in red ink, dotted leaders) with the shared elephant menus, the codex and the whole book. Tray menus use the same slips. |
| **the codex** (`codex/`) | the control panel: an open book. Left page, its contents; right page, the chapter, under an illuminated capital. Turning chapters turns a leaf. |
| **letters** (`letters/`) | notifications: a folded parchment packet slides in, sealed with wax stamped with the sender's initial. Hover: the seal cracks, the flap opens, the letter unfolds. Urgent ones are sealed in glowing arcane wax and stay. |
| **flourishes** (`frames/Frames.qml`) | gilt corner flourishes on the focused window (Hyprland draws the gold-leaf rule round every window). |
| **the closed book** (`lock/`) | the lock screen: the grimoire on the blurred desk, a strap and a clasp with a glowing lock rune; "Speak the Word": what you type appears as runes (never the letters). Wrong: the book shudders. Right: the cover swings open. The candle burns beside it. |
| **the whole book** (`utilities/Overview.qml`) | the overview: every chapter as a page with live pictures of its windows. |
| **the scribe**, **a seal is required** | dictation (voxtype) and the polkit prompt, on parchment. |

## Structure

```
shell.qml                what's on screen
theme/Theme.qml          every colour, font, size and timing; the rune table (Theme.futhark), roman()
widgets/                 the kit. Leather, Parchment (surfaces with assets/ textures), Flourish, GoldRule,
                         Initial (illuminated capital), Moon, Sparks (particles); for pages (ink on
                         parchment): Section, KV (dotted leader), Btn, Seal (wax-seal switch), Slider,
                         Field, Row2, Meter, Charm, Caps, Body, Glyph
bar/                     Bar, Chapters, Ribbon, Tray, TrayMenus
spine/                   Spine, Candle, Crystal, Vial, Mana
launcher/                Circle + CircleState (the summoning circle), ContentsState (the root menu)
menus/                   the slips (Menus, MenuLayer, MenuPanel)
codex/                   Codex, CodexState (the shared `deck` IPC), Contents, pages/*
letters/                 Letters (the stack), Letter, WaxSeal
frames/Frames.qml        the flourishes
lock/                    LockState (PAM), Lock, LockFace, pam/grimoire-lock (pam_unix only)
utilities/               Overview, DictationOsd (the scribe), PolkitPrompt, OverviewState, Debug
services/                the shared logic (Net, Capture, Displays, Weather, Updates, Backlight…)
shaders/                 flame.frag (the candle), aura.frag (behind the circle); build.sh compiles them
                         (and theme/transition/burn.frag) to .qsb with Qt's qsb
assets/                  leather.png, paper.png, foxing.png (setups/grimoire/textures.py), spark.png
```

## How it maps onto the other setups

| shared | Grimoire |
|---|---|
| root menu (SUPER + Space) | the table of contents: `qs ipc call contents toggle` (also the clasp) |
| app launcher (SUPER + CTRL + Space) | the summoning circle: `qs ipc call circle toggle` |
| `deck open <page>` | the codex's chapters: helm Sanctum, comms Sendings, radio Minstrelsy, log Letters, almanac Almanac, telemetry Alchemy (with the wards: vulnerabilities and updates), hangar Reliquary, optics Scrying, lamps Lanterns, chronometer Hourglass, claude Familiar |
| workspace overview | the whole book (`overview toggle`, right-click the chapters, or click the ribbon) |

## IPC

```
qs ipc call contents toggle | circle toggle | deck open <page> | overview toggle
qs ipc call circle type <words> | cast       testing the circle without the keyboard
qs ipc call notifications clear | dnd
qs ipc call tray list | menu <n>
qs ipc call updates sweep | report
qs ipc call lock lock | preview | close
qs ipc call debug grab <bar|spine|codex|circle> <file.png>
```

## Tweaking

Colours come from the theme (`~/.config/theme/setups/grimoire/themes/*.toml`: accent = gold,
purple = the arcane glow, and Grimoire's own keys: goldBright goldDeep parchment parchmentDeep ink
inkDim rubric wax flame, activeBorder/activeBorder2/inactiveBorder for Hyprland), then `theme reload`.
Sizes, timings, the candle's life (`candleHours`) and the rune table are in `theme/Theme.qml`. After
editing a shader: `sh shaders/build.sh`. New textures: `~/.local/share/theme/venv/bin/python
~/.config/theme/setups/grimoire/textures.py`. Wallpapers, Walker images and the illuminated capital:
`… setups/grimoire/wallpapers.py [theme]`.

## If the lock screen ever misbehaves

Only a correct password (pam_unix, no faillock) opens the book; a wrong one only says so. If
Quickshell crashed while locked: `Ctrl + Alt + F3`, log in, `WAYLAND_DISPLAY=wayland-1 hyprlock`, then
`Ctrl + Alt + F1`.
