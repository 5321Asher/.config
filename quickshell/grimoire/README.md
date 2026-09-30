# Grimoire

The desktop as a wizard's spellbook on a candlelit desk: oxblood leather, aged parchment, gold leaf
and glowing runes. This is the Quickshell half of the **Grimoire setup**; the rest (colour themes,
fonts, Hyprland look, kitty, GTK/Qt, icons, cursors, wallpapers, Walker, the burn transition) lives in
`~/.config/theme/setups/grimoire/`.

Switch to it with `~/.config/theme/theme setup grimoire` (or the arcana / Walker: Style →
Setup). Run it on its own with `qs -c grimoire`; it reloads live (`touch shell.qml` if a change doesn't
show).

## What's on screen

| piece | what it is |
|---|---|
| **the bar** (`bar/`) | the head of the book: tooled leather over a gilt edge. The clasp in the corner opens the arcana (right-click: the codex). Chapters (workspaces) in Roman numerals, a violet silk ribbon hanging from the open one; it swings when you turn chapters. The running head (chapter and the page you're on) in the middle; on the right, whatever runs (scrying = recording, the scribe = dictation, the hourglass = focus timer), the tray, the vigil (stay awake), the letters, the moon and the hour. |
| **the spine** (`spine/`) | down the left: raised bands with the reagents between them: the heat crystal (CPU temperature: arcane when cool, gold, then flame, red past 85°), two potion vials (CPU in a flask, memory in a tube, bubbling), the mana tube (the battery; hidden on mains). Each shows its reading, no labels. The spine's title in blackletter, and at its foot **the candle**: your uptime. Lit at boot, it burns down over `Theme.candleHours`, the wax (a shader, lit through by the flame) runs down its sides and pools in the brass dish, the flame (a shader) never stops flickering, `qs ipc call debug candle <hours>` shows it at any age, and it relights when you reboot. Hover anything for a note; click to open its chapter of the codex. |
| **the seal-book** (`launcher/Circle.qml`, `SealView.qml`, `seal.js`) | the app launcher, and nothing else on screen: what you have written in small italics at the top middle (the keys go to a hidden input), and in the middle the seal of the program it finds, drawn out in gold by an unseen pen (↑ ↓ step through other matches). After Witch Hat Atelier's glyphs, every part means something: the **sigil** in the middle is its element from its categories (fire: making; water: reaching others; wind: sound and sight; earth: the system; light: reading and learning), the **signs** round it are what it does, from its name and description (column: sends out; dispersion: spreads; convergence: gathers; levitation: holds lightly, i.e. tools; cycle: plays and repeats; ward: guards; weave: none of these), the **symmetry** grows with its name, the **tick band** has four ticks per letter, dots mark where signs meet, and the **rings** grow with use (a second inner ring after 5 summonings, a second outer ring after 20). The outer ring stays open by a hair; Enter closes it, the seal glows and the program comes. Its IPC is still `circle`. |
| **the commonplace book** (`launcher/Clipboard.qml`) | clipboard history (SUPER + V): an open book, the entries on the left page (newest first, the kept ones first of all with a dab of wax), the chosen one written out on the right (code in the mono face, pictures tipped in with photo corners). Enter copies, Ctrl+P keeps, Ctrl+D strikes out, Ctrl+Shift+D twice clears. Same history as Walker (elephant). |
| **a question** (`launcher/Prompt.qml`) | what `theme/prompt` asks (web apps, keybinds): a parchment leaf in a gilt-tooled leather frame, the question at its head, a line to write on, the choices numbered in red. |
| **the arcana** (`arcana/`, `launcher/ContentsState.qml`) | the root menu: the screen sinks into candlelit dark with smoke drifting through it (`shaders/veil.frag`) and the cards are dealt in a fan, one per shared elephant menu (Apps XVII the star, Trigger XVI the tower, Style XVIII the moon, Power XIII dusk) plus the codex and the whole book. The theme's leather over a board (`widgets/Cover.qml`), everything pressed into it in gilt (the gold mirrors a soft room light, so it reads as metal everywhere); the pointer is a lamp held close: a warm pool of light follows it across the lifted card and the gilt flashes where it passes. ← → choose, Enter or a click draws: Apps, the codex and the book just open; the others turn over (edge-on in the middle, then the back opens out) into a reading: the menu set on the card's leather in cream and gilt, one level at a time, a wax dot on the one in use. Esc goes back: the card closes up, flips face up and slides home into the fan. |
| **the codex** (`codex/`) | the control panel: an open book. It arrives closed (a gilt-tooled cover, `widgets/Cover.qml`), the cover swings over on its spine and two leaves riffle after it (`codex/Flip.qml`); closing plays that backwards. Left page, its contents; right page, the chapter, under an illuminated capital. Turning chapters turns real leaves (`shaders/curl.frag`), one for every chapter you pass: next door, one leaf; Sanctum to Familiar, ten riffle over, each showing its chapter's heading as it goes by. A leaf curls up from its corner and over onto the left page showing its plain back; they pile up there in order (each leaf in the air above those lying down), and the last to land becomes the contents page, so nothing jumps (back: the leaves lift from the left, the new chapter's page last). Both animations are stepped per frame (at most 1/30 s a frame), so the stall while a chapter loads can't skip them. |
| **letters** (`letters/`) | notifications: a folded parchment packet slides in, sealed with wax stamped with the sender's initial. Hover: the seal cracks, the flap opens, the letter unfolds. Urgent ones are sealed in glowing arcane wax and stay. |
| **flourishes** (`frames/Frames.qml`) | gilt corner flourishes on the focused window (Hyprland draws the gold-leaf rule round every window). They keep up with the window: Hyprland says nothing during a drag, so the layer asks for the windows every frame while one is moving (ten times a second when still); a drag or resize is followed exactly, a jump glides on Hyprland's own window curve (400 ms, "arcane"). |
| **the closed book** (`lock/`) | the lock screen: the grimoire on the blurred desk, lit by the candle beside it (the cover's rounded, rubbed boards and pressed gilt catch its flickering light; the page block shows at the fore-edge and foot), a stitched strap and a brass clasp with a glowing lock rune; "Speak the Word": what you type appears as quiet gold runes (never the letters; no pops, no glow per key). Wrong: a small shudder. Right: the cover swings all the way open to "Welcome back" and only then does the book fade (`Theme.lockOutro`). The candle burns beside it. |
| **the whole book** (`utilities/Overview.qml`) | the overview: every chapter as a page with live pictures of its windows. |
| **the scribe**, **a seal is required** | dictation (voxtype) and the polkit prompt, on parchment. |

## Structure

```
shell.qml                what's on screen
theme/Theme.qml          every colour, font, size and timing; the rune table (Theme.futhark), roman()
widgets/                 the kit. Leather, Parchment, Cover (lit boards with gilt/blind tooling), PageBlock
                         (shader-drawn surfaces), Hinge (a gentle-perspective turn), Flourish, GoldRule,
                         Initial (illuminated capital), Moon; for pages (ink on parchment): Section, KV (dotted leader), Btn, Seal (wax-seal switch), Slider,
                         Field, Row2, Meter, Charm, Caps, Body, Glyph
bar/                     Bar, Chapters, Ribbon, Tray, TrayMenus
spine/                   Spine, Candle, Crystal, Vial, Mana
launcher/                Circle + CircleState + SealView + seal.js (the seal-book: app launcher and the seal
                         generator), ContentsState (the arcana's state), Clipboard (the commonplace book),
                         Prompt (questions from theme/prompt), ClipboardState, PromptState
arcana/                  Arcana (the spread), Card, Emblem (line-art emblems), Reading (a card's menu)
menus/                   the slips for tray menus (Menus, MenuLayer, MenuPanel)
codex/                   Codex, CodexState (the shared `deck` IPC), Contents, pages/*
letters/                 Letters (the stack), Letter, WaxSeal
frames/Frames.qml        the flourishes
lock/                    LockState (PAM), Lock, LockFace, pam/grimoire-lock (pam_unix only)
utilities/               Overview, DictationOsd (the scribe), PolkitPrompt, OverviewState, Debug
services/                the shared logic (Net, Capture, Displays, Weather, Updates, Backlight…)
shaders/                 paper.frag + leather.frag (every page and cover), cover.frag (lit book boards, brass),
                         pages.frag (page-block edges), flame.frag + wax.frag (the candle), veil.frag
                         (the arcana), curl.frag (the codex's turning leaves); build.sh compiles them (and
                         theme/transition/burn.frag) to .qsb with Qt's qsb
assets/                  none: every texture is drawn by a shader
```

## How it maps onto the other setups

| shared | Grimoire |
|---|---|
| root menu (SUPER + Space) | the arcana: `qs ipc call contents toggle` (also the clasp); testing: `contents draw <card>`, `choose <row>`, `back` |
| app launcher (SUPER + CTRL + Space) | the seal-book: `qs ipc call circle toggle` |
| clipboard (SUPER + V), `theme/prompt` | the commonplace book: `qs ipc call clipboard toggle`; a question: `qs ipc call prompt ask <dir>` |
| `deck open <page>` | the codex's chapters: helm Sanctum, comms Sendings, radio Minstrelsy, log Letters, almanac Almanac, telemetry Alchemy (with the wards: vulnerabilities and updates), hangar Reliquary, optics Scrying, lamps Lanterns, chronometer Hourglass, claude Familiar |
| workspace overview | the whole book (`overview toggle`, right-click the chapters, or click the ribbon) |

## IPC

```
qs ipc call contents toggle | circle toggle | deck open <page> | overview toggle
qs ipc call circle type <words> | cast       testing the launcher without the keyboard
qs ipc call contents draw <n> | choose <n> | back   testing the arcana
qs ipc call notifications clear | dnd
qs ipc call tray list | menu <n>
qs ipc call updates sweep | report
qs ipc call lock lock | preview | close
qs ipc call debug grab <bar|spine|codex|circle|arcana> <file.png>
```

## Tweaking

Colours come from the theme (`~/.config/theme/setups/grimoire/themes/*.toml`: accent = gold,
purple = the arcane glow, and Grimoire's own keys: goldBright goldDeep parchment parchmentDeep ink
inkDim rubric wax flame, activeBorder/activeBorder2/inactiveBorder for Hyprland), then `theme reload`.
Sizes, timings, the candle's life (`candleHours`) and the rune table are in `theme/Theme.qml`. After
editing a shader: `sh shaders/build.sh` (a brand-new shader file needs `theme shell` once: Qt
remembers a shader it failed to find). Paper and leather are shaders now (no texture files). Wallpapers, Walker images and the illuminated capital:
`… setups/grimoire/wallpapers.py [theme]`.

## If the lock screen ever misbehaves

Only a correct password (pam_unix, no faillock) opens the book; a wrong one only says so. If
Quickshell crashed while locked: `Ctrl + Alt + F3`, log in, `WAYLAND_DISPLAY=wayland-1 hyprlock`, then
`Ctrl + Alt + F1`.
