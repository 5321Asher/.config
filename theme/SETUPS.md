# Setups: the playbook

This is the manual for this rice's **setups**: what one is, what every one must do, and the exact
procedure for making a new one. It is written for a future AI session (or a human) that is asked
"make another setup" and has none of the history. Read it all before touching anything.

Repo: `~/.config` (git, allowlist `.gitignore`), pushed to `github.com/5321Asher/.config` (private,
branch `main`). Arch Linux, Hyprland (**Lua config**), Quickshell 0.3.x, Qt 6.

---

## 1. What a setup is

A **setup** is a whole desktop you switch to with one command: its Quickshell shell (bars, panels,
notifications…), its Walker theme, its Hyprland look (gaps, borders, blur, animations), kitty,
hyprlock, cava, fastfetch layout, fonts, cursor, icons, switch transition, and **its own colour
themes** (a setup has 1…N themes; themes are never shared between setups — two setups never share a
colour theme or a config file). A theme recolours everything inside its setup and picks its
wallpapers.

Shared by every setup (don't fork these per setup): keybinds (`hypr/binds.lua`), the menu *contents*
(elephant menus, `elephant/menus/`), hypridle, the GNOME keyring, the theme tool itself.

```
~/.config/theme/theme setups                list setups (* = active)
~/.config/theme/theme setup <id>            switch setup (its last theme + wallpaper come back)
~/.config/theme/theme list | set <id>       this setup's themes | switch theme
~/.config/theme/theme                       TUI manager (S = pick setup, a = assign wallpapers)
~/.config/theme/theme reload                re-apply the active theme after editing files
~/.config/theme/theme shell                 restart the active setup's Quickshell
```
Also in menus: Style → Setup / Theme (Walker, or a setup's own console).

Existing setups, as references:

| setup | level | look | shell | menus | lock | style.py |
|---|---|---|---|---|---|---|
| **sharp** | 2 (styled) | flat, square, quick; tabbed top bar; Cascadia | `quickshell/sharp/` (bar + side ControlPanel with tabs) | Walker | hyprlock | icons + cursors |
| **observatory** | 3 (fully custom) | brass instruments, orbits, phosphor; JetBrains + Cormorant | `quickshell/observatory/` (horizon line, dome sundial, orbital workspaces, gauges, control deck) | own console + star-chart launcher | own Quickshell lock | gtk3/gtk4/qss/satty + icons + cursors |
| **memphis** | 3 (fully custom) | Windows 98: grey bevels, Start button, Control Panel; W95FA + IBM VGA | `quickshell/memphis/` (taskbar, Start menu, shell windows: Control Panel + Properties sheets, Run…, Inbox, Media Player) | own Start menu + Run… launcher | own Quickshell lock (98 logon box) | gtk3/gtk4/qss/satty (98 widgets) + Chicago95 icons + pixel cursors |
| **netrunner** | 3 (fully custom) | Cyberpunk: red/cyan on black glass, cut corners, HUD of real system state; Chakra Petch + JetBrains Mono + Noto CJK | `quickshell/netrunner/` (bar with ticker, window frames overlay, deck dashboard on special:deck, rig control panel) | own hub (quickhack list) + EXEC launcher | own Quickshell lock (pic-4 style) | gtk3/gtk4/qss/satty + folder icons + cursors |
| **disguise** | 3 (fully custom) | Windows 11: Mica/Acrylic, centred taskbar, Fluent controls; Segoe UI Variable + Segoe Fluent Icons + Cascadia | `quickshell/disguise/` (taskbar, flyout layer: Start, Search, Quick Settings, notification centre, Widgets, tray; Settings as a real FloatingWindow; Task View; toasts; OSD) | own Start menu + Search | own Quickshell lock (curtain + sign-in) | gtk3/gtk4/qss/satty (WinUI) + Win11 icons + cursors |

---

## 2. How much custom: the three levels

Pick the level from what the user asks for. "A new look / different colours and layout" → level 1
or 2. "A completely different desktop / its own launcher / its own lock screen" → level 3. When
unsure, build level 2 and offer level-3 extras at the end.

### Level 1 — Quickshell + Walker (a reskin)
- **Shell:** its own `quickshell/<id>/`, started as a **copy of Sharp's** (it already meets every
  requirement in §3) and restyled: its own `Theme.qml`, layout, bar position, shapes, spacing.
- **Menus / launcher:** Walker (no `[menus]` table in `setup.toml`), with its own Walker theme in
  `walker/themes/<id>/` (copy Sharp's, restyle `style.css` and the `.xml` layouts).
- **Lock:** hyprlock with its own `files/hypr/hyprlock.conf`.
- **GTK / Qt:** the built-in flat style from `writers.py` (no `style.py`); icons from
  `[icons] theme = "…"` (e.g. Papirus-Dark); cursor from `[cursor]`.
- **Transition:** `fade` (or wipe / iris / dissolve / glitch, see §5).
- **Wallpapers:** assigned stills from the pool.

### Level 2 — styled (like Sharp)
Level 1, plus:
- `theme/setups/<id>/style.py` with any of `gtk3`, `gtk4`, `qss`, `satty` (stylesheets) and
  **`icons` + `cursors`** built with `theme/iconkit.py`, all drawn from the theme palette, so they
  follow every colour theme.
- Its own `files/` (kitty.conf, hypr/look.lua, hyprlock.conf, cava/config), fastfetch template,
  transition style, Walker side images per theme.

### Level 3 — completely custom (like Observatory)
Level 2, plus any or all of:
- A shell designed from scratch (its own architecture, not a copy), with a spec'd visual language.
- **Its own menus UI** in Quickshell via `setup.toml [menus]` (root menu + app launcher). It must
  read the same elephant menus as Walker (`elephant query --json 'menus:<name>;;500;false'`,
  run entries with `elephant activate 'provider;identifier;action;;'`), so every setup offers
  the same functions. New functions go into `elephant/menus/`, never into one setup's UI.
- **Its own lock screen** (Quickshell `WlSessionLock` + PAM, see §3.4 for the safety rules).
- Its own notification, polkit, OSD designs; generated wallpapers (stills and/or video, §6).

---

## 3. The non-negotiables (every setup, every level)

The keybinds, hypridle and menus are shared and call things **by name**. A setup that lacks one
leaves a key that silently does nothing. Verify every item (§7).

### 3.1 IPC targets the shell must answer (`qs ipc call …`)

| target | functions | used by |
|---|---|---|---|
| `capture` | `screenshot(mode: string)` region/screen, `ocr()`, `toggleRecording()` | SUPER+SHIFT+S / T, Trigger menu |
| `overview` | `toggle()`, `open()`, `close()` | workspace overview |
| `voxtype` | `toggle()`, `cancel()` | dictation (SUPER+Z / SUPER+SHIFT+Z) |
| `deck` | `open(page: string)`, `toggle()`, `close()` | pages: `helm radio log almanac telemetry hangar optics lamps chronometer comms claude` (map them onto your panel's tabs, as Sharp does in `BarState.qml`) |
| `lock` | `lock()` (+ `preview()`, `close()` for testing) | only if the setup has its own lock |
| `console`, `starchart` | `toggle()` | only if `[menus]` points at them |

### 3.2 Session services (exactly one process may own each)
- **Notification server** (`Quickshell.Services.Notifications`) with history, clear-all, and
  **do-not-disturb** (still pop up critical ones).
- **System tray** (StatusNotifier host) with working right-click menus (`QsMenuOpener`).
- **Polkit agent** (admin password prompts). The shell must live in the login session's cgroup, so
  it is always started by `hyprctl dispatch 'hl.dsp.exec_cmd("qs")'` (the theme tool does this).
- Because each is exclusive, the theme tool stops the old shell (`qs kill -c default`) before
  starting the new. **Never `pkill qs`**: the switch transition is a Quickshell too.

### 3.3 Feature parity (both current setups have all of these — so must a new one)
With where they live, so you can port them (`S` = `quickshell/sharp/modules/`,
`O` = `quickshell/observatory/`):

| feature | Sharp | Observatory | Memphis (`M` = `quickshell/memphis/`) | Netrunner (`N` = `quickshell/netrunner/`) |
|---|---|---|---|---|
| workspaces + focused window | `S/Workspaces.qml` | `O/bar/Orbits.qml` | `M/taskbar/Pager.qml`, `TaskButtons.qml` |`N/bar/Workspaces.qml`, frames `N/frames/Frames.qml` |
| clock / calendar | `S/Clock.qml`, `S/Calendar.qml` | `O/bar/Sundial.qml`, deck `Almanac.qml` | `M/taskbar/NotifyArea.qml`, applet `DateTime.qml` |`N/bar/Bar.qml`, rig `Almanac.qml` |
| Wi-Fi (scan, connect with password), Bluetooth (pair, forget), Tailscale (exit node) | `S/Net.qml`, `WifiPage`, `BluetoothPage`, `TailscalePage` | `O/services/Net.qml`, deck `Comms.qml` | applet `Network.qml` |rig `Comms.qml` |
| quick toggles: Wi-Fi, Bluetooth, Tailscale, **DND**, **stay awake** (`systemd-inhibit --what=idle`), **lights follow theme** (OpenRGB) | `S/QuickTab.qml` | deck `Helm.qml` | `M/desk/windows/ControlPanel.qml` (web-view pane) |rig `Helm.qml`, IDLE // HOLD in the bar |
| volume per app, outputs / inputs, mic test | `S/MediaTab.qml` | deck `Media.qml` | `M/desk/windows/VolumeControl.qml`, applet `Multimedia.qml` |rig `Airwaves.qml` |
| media player (MPRIS) + visualiser (cava) | `S/MediaPanel.qml`, `S/Cava.qml` | deck `Media.qml`, `O/services/Radio.qml` (waveform on the horizon) | `M/desk/windows/MediaPlayer.qml`, applet `Multimedia.qml` |rig `Airwaves.qml`, deck `SignalPanel.qml` |
| monitor brightness (ddcutil) | `S/Brightness.qml` | `O/services/Brightness.qml` | applet `Display.qml` (Brightness) |rig `Helm.qml`, `Optics.qml` |
| display layout (resolution, refresh, scale, rotation, arrangement, revert timer) | `S/DisplayTab.qml` | deck `Optics.qml` | applet `Display.qml` (Settings) |rig `Optics.qml` |
| capture: region / screen screenshots, OCR, screen recording + REC indicator | `S/Capture.qml` | `O/services/Capture.qml`, `O/bar/Beacons.qml` | `M/services/Capture.qml`, REC in `NotifyArea.qml` |`N/services/Capture.qml`, REC in the bar |
| dictation (voxtype) overlay **with a live mic meter** | `S/VoxtypeOsd.qml`, `S/MicLevel.qml` | `O/utilities/DictationOsd.qml`, `O/services/MicLevel.qml` | `M/utilities/DictationOsd.qml` |`N/utilities/DictationOsd.qml` |
| weather + 7-day + **moon phase** | `S/WeatherTab.qml` | deck `Almanac.qml` | applet `DateTime.qml` (Weather) |rig `Almanac.qml` |
| CPU / GPU / RAM / VRAM / storage / network stats + **"open btop"** | `S/StatsTab.qml`, `scripts/stats.py` | deck `Telemetry.qml`, bar gauges | applet `SystemProps.qml` (Performance) |rig `Telemetry.qml`, deck `SysDiag.qml` |
| device batteries, drives (mount / eject), fans | `S/DevicesTab.qml` | deck `Hangar.qml` | applet `SystemProps.qml` (Device Manager) |rig `Hangar.qml` |
| RGB lighting (OpenRGB colour, profiles, follow theme) | `S/RgbTab.qml` | deck `Lamps.qml` | applet `Lighting.qml` |rig `Lamps.qml` |
| focus timer + pomodoro (+ indicator in the bar) | `S/FocusTab.qml` | deck `Chronometer.qml` | applet `Timer98.qml`, hourglass in `NotifyArea.qml` |rig `Chrono.qml`, the bar |
| Claude Code usage / limits | `S/ClaudeInfo.qml` | deck `Claude.qml` | applet `ClaudeProps.qml` |rig `Claude.qml` |
| notification history + DND + clear | `S/NotificationList.qml`, `S/Notifs.qml` | deck `Log.qml`, `O/services/Transmissions.qml` | `M/desk/windows/Messages.qml`, `M/services/Notifs.qml` |rig `Log.qml`, `N/notifications/` |
| workspace overview | `S/Overview.qml` | `O/utilities/Overview.qml` | `M/utilities/Overview.qml` |`N/utilities/Overview.qml` |
| tray with menus | `S/SysTray.qml`, `S/TrayMenu.qml` | `O/bar/Tray.qml`, `O/utilities/TrayMenu.qml` | `M/taskbar/NotifyArea.qml`, `TrayMenus.qml` |`N/bar/Tray.qml`, `TrayMenus.qml` |
| power: lock, sleep, log out, restart, shut down | `S/QuickTab.qml` | deck `Helm.qml` | `M/desk/windows/ShutDownDialog.qml`, Control Panel pane |rig `Helm.qml` |
| polkit prompt | `S/PolkitPrompt.qml` | `O/utilities/PolkitPrompt.qml` | `M/utilities/PolkitPrompt.qml` |`N/utilities/PolkitPrompt.qml` |
| vulnerability watch (arch-audit, by severity, fix ready) + pending updates (checkupdates) + update now | `S/Updates.qml`, `S/StatsTab.qml` (Security card) | `O/services/Updates.qml`, deck `Telemetry.qml` (watch) | `M/services/Updates.qml`, applet `SystemProps.qml` (Security), tray icon | `N/services/Status.qml`, deck `VulnWatch.qml`, the ticker |

Disguise (`D` = `quickshell/disguise/`) has every row too: its README's mapping table says where (Quick Settings
`D/flyouts/QuickSettings.qml`, Settings pages `D/settings/pages/`, Task View `D/utilities/TaskViewLayer.qml`…).

The *logic* singletons (Net, Capture, Devices, Displays, Brightness, FocusTimer, Rgb, SysStats,
Voxtype, Weather, MicLevel, ClaudeStatus, Config, Updates, Elephant, StayAwake) are the same in every setup: copy them into the
new shell (a setup never imports another setup's files) and write only the UI.

### 3.4 Lock screen rules
- `setup.toml` → `lock = "…"` is what `theme lock` runs (hypridle's `lock_cmd`, SUPER+L, suspend).
- **hyprlock** (levels 1–2): nothing else to do; `/etc/pam.d/hyprlock` → `login` already unlocks
  the keyring.
- **Own Quickshell lock** (level 3):
  - `lock = "qs ipc call lock lock || pidof hyprlock || hyprlock"` (hyprlock is the fallback).
  - Its own PAM file inside the shell folder (`quickshell/<id>/lock/pam/<name>`), used through
    `PamContext { configDirectory: Quickshell.shellDir + "/lock/pam"; config: "<name>" }`:
    ```
    #%PAM-1.0
    auth required pam_unix.so
    -auth optional pam_gnome_keyring.so
    ```
    **Never** include `system-auth`: it has pam_faillock (3 wrong tries = 10-minute lockout).
  - A wrong password only clears the field and says so; only PAM success unlocks.
  - Test only with the preview (`qs ipc call lock preview` / `close`). **Never trigger a real
    lock while testing** — only the user's password opens it.
  - Observatory's lock animates in from a snapshot of the desktop and back out on unlock
    (`O/lock/LockState.qml`); copy that pattern. Snapshots must have a timeout (screens may be
    off: see §8).

### 3.5 GNOME keyring (all setups)
Session-wide, nothing per setup except the lock (above). Brave/Chromium use it via
`~/.config/{brave,chromium}-flags.conf` (`--password-store=gnome-libsecret`); `gh` and git use it.
The session autologs in on tty1, so the first app needing a secret after boot prompts once, or
unlocking the lock screen unlocks it. Setting it up again on a new machine needs sudo (the user
runs it): `pacman -S gnome-keyring seahorse`, two `pam_gnome_keyring` lines in `/etc/pam.d/login`
(auth optional; session optional auto_start), `systemctl --user enable --now gnome-keyring-daemon.socket`.

### 3.6 Fonts, cursor, icons (system-wide, per setup)
`setup.toml [fonts]` (mono, sans, serif, display, size) is written everywhere: fontconfig generic
families, GTK settings.ini + gsettings, qt6ct, kitty, Walker (`* { font-family }` in colors.css —
so don't hardcode fonts in `style.css`), Quickshell (`colors.json` → `fontMono`, `fontSans`,
`fontSerif`, `fontDisplay`, `fontSize` — read them in `Theme.qml`), hyprlock (`$font`,
`$fontDisplay`), Zed, Obsidian. A theme may override with its own `[fonts]`. Install missing fonts
first (§7 step 0); check with `fc-list : family | grep -i <name>`.

---

## 4. File map of a setup

```
theme/setups/<id>/setup.toml             see §4.1
theme/setups/<id>/themes/<theme>.toml    colour themes (§4.2), ≥ 1
theme/setups/<id>/style.py               optional (levels 2–3): gtk3 gtk4 qss satty icons cursors (p, ctx)
theme/setups/<id>/images/<theme>/        walker.* (Walker side image), fastfetch.* (logo); images/_default/ as fallback
theme/setups/<id>/templates/fastfetch.jsonc   fastfetch layout ({{accent}}-style placeholders, see Sharp's)
theme/setups/<id>/files/kitty/kitty.conf       ┐ symlinked into ~/.config on a switch
theme/setups/<id>/files/hypr/look.lua          │ (gaps, borders, rounding, blur, shadows, animations,
theme/setups/<id>/files/hypr/hyprlock.conf     │  layer rules for its panels, per-setup window rules
theme/setups/<id>/files/cava/config            ┘  like Brave's see-through New Tab)
quickshell/<id>/shell.qml + …             its shell; must read colors.json from Quickshell.shellDir
walker/themes/<id>/style.css + *.xml      its Walker theme (colors.css and side.jpg are generated)
~/Pictures/Wallpaper-Themes/<id>/<theme>/  hardlinks of pool wallpapers per theme; <id>/_all/ = any theme
```
Pointers the theme tool maintains: `quickshell/default -> <id>`, `walker/themes/active -> <id>`.
There must be **no** `~/.config/quickshell/shell.qml` (it disables named configs).

### 4.1 setup.toml (every key)
```toml
name = "Name"
description = "three · word · summary"
default_theme = "<theme id>"
icon = "<nerd font glyph>"
lock = "pidof hyprlock || hyprlock"       # or "qs ipc call lock lock || pidof hyprlock || hyprlock"

[fonts]            # mono sans serif display size
[cursor]           # theme size   (fallback if style.py has no cursors())
[icons]            # theme        (fallback if style.py has no icons())
[hyprland]
border = "gradient"                        # accent -> second accent, "accent" (solid), or "palette" (the theme's activeBorder / inactiveBorder)
[menus]            # optional (level 3): root = "…", apps = "…"  (shell commands; default: Walker)
[transition]
style = "fade"                             # fade | wipe | iris | dissolve | glitch
duration = 700                             # ms
```

### 4.2 A colour theme
Copy an existing one. `[palette]` needs `bg bgDark surface hover border dim fg accent accentText
accentMuted purple (second accent) warn danger green`; anything else (e.g. Observatory's
`brassBright phosphor signal starlight`) passes through to the shell's `colors.json`. Optional
`[ansi]` (16 colours) and `[syntax]` (editor colours), `appearance = "light"` for light themes,
`wallpaper = "<file in its folder>"` for the default wallpaper, `[fonts]` override, and
`[terminal]` (+ `[terminal.syntax]`): palette keys that only terminal apps (kitty, btop, Neovim,
fastfetch) get, so a light theme can keep a dark terminal (Memphis: the MS-DOS Prompt). Every hex
palette key also reaches hyprlock-colors.conf as `$key`.
Every theme must look right in **every** part of its setup: check light themes especially.

### 4.3 style.py hooks (levels 2–3)
Called by `writers.py` on every theme switch with `p` (the full palette) and `ctx` = `{mix, rgba,
fonts, dir, cache, appearance}`. Each returns text (CSS/QSS) or a theme name:
- `gtk3(p, ctx)`, `gtk4(p, ctx)`, `qss(p, ctx)`, `satty(p, ctx)` — replace the built-in flat styles.
- `icons(p, ctx)` → `iconkit.folder_theme(name, comment, draw, key, inherits)`: redraws Papirus's
  folder icons (`draw(anatomy)` gets Papirus's front/paper rects, tab top and glyph, plus the
  original SVG). Sharp draws square folders; Observatory recolours them brass.
- `cursors(p, ctx)` → `iconkit.cursor_theme(name, comment, shapes, key)`: Xcursor themes from SVG
  drawings on a 64 grid (shapes: arrow pointer text crosshair wait progress move ns ew nwse nesw
  forbidden help copy link). Names are versioned per palette automatically (Hyprland/GTK cache by
  name). Key = `iconkit.palette_key(<colours used>, "<setup>-cursors-vN")`; bump vN when the
  drawing changes.

### 4.4 Generated files (never edit, never commit)
`quickshell/*/colors.json`, `walker/themes/*/colors.css` + `side.jpg`, `kitty/skwd-colors.conf`,
`hypr/colors.lua`, `hypr/hyprlock-colors.conf`, `fastfetch/config.jsonc`, `fontconfig/fonts.conf`,
`gtk-{3,4}.0/gtk.css`, `qt6ct/colors/`, `qt6ct/qss/`, `satty/overrides.css`, the setup symlinks.
All are in `.gitignore`. New themeable app? Add a writer to `theme/writers.py` (paths via
`writers.configure(setup)`), not a hand-made config.

---

## 5. Switch transitions
`theme set` / `theme setup` freeze the screens on a snapshot (`theme/transition/shell.qml`, its
own `qs -p` process), switch underneath, then reveal in the target setup's `[transition]` style:
`fade` (crossfade), `wipe` (hard edge from the left + accent line — Sharp), `iris` (circle from
the centre with an accent ring — Observatory), `dissolve` (square blocks in random order — Memphis), `glitch` (torn, jittering bands with red/cyan edges — Netrunner). A new style = a new branch in that QML file
(keep it generic: it only gets `style`, `accent`, `duration`). Skipped automatically when the
screens are off. `settings.toml [transition] enabled = false` turns it off.

---

## 6. Wallpapers
- Pool: `~/Pictures/Wallpaper-Themes/_pool/` (everything). Assign per theme / per setup in the TUI
  (`theme pool`: number keys = themes, `s` = the whole setup). A theme with nothing assigned shows
  everything in its setup. skwd-wall shows `~/Pictures/Wallpapers` (the theme tool rebuilds it).
- The user chooses assignments by hand: never auto-sort by colour.
- Generated wallpapers are welcome for custom setups: Observatory has `starchart.py` (stills from a
  theme) and `skyvideo.py` (2-minute seamless looping 2560x1440 video per theme: Pillow in
  `~/.local/share/theme/venv`, NVENC HEVC; skwd-wall plays .mp4 via `skwd-wall-vk`). Copy that
  pattern: output into `_pool/`, hardlink into `<setup>/<theme>/`, set the theme's `wallpaper =`.
- Never run `skwd-wall-scan` with `SKWD_WALL_V2_CONFIG` overrides (it writes the real index).

---

## 7. Procedure: "make another setup"

**0. Decide, don't interrogate.** From the request, fix: id (lowercase, one word), name, concept
and visual language, level (§2), fonts, number of colour themes (1 if not said; the user may want
5–10 later), transition style. Ask only what can't be inferred (usually just the concept, if none
was given). If fonts are missing, give the exact `pacman`/`yay` command and wait. Check the
Quickshell version and read its `.qmltypes` (`/usr/lib/qt6/qml/Quickshell/**`) before using an
API; don't guess type names.

**1. Scaffold** (copy the closest setup; for level 1–2 that's Sharp, for level 3 either):
```sh
cd ~/.config
cp -r theme/setups/sharp theme/setups/<id>            # then prune: themes/, images/<theme>/ dirs
cp -r quickshell/sharp quickshell/<id>                 # level 3: write a new shell instead
cp -r walker/themes/sharp walker/themes/<id>; rm -f walker/themes/<id>/{colors.css,side.jpg}
mkdir -p ~/Pictures/Wallpaper-Themes/<id>
```
Edit `setup.toml` (every key, §4.1), write the theme(s) (§4.2), restyle `files/` (kitty,
look.lua incl. layer rules for the shell's namespaces and the Brave New Tab rule, hyprlock,
cava), the fastfetch template, `style.css`. Give every Quickshell layer a namespace prefix
`<id>-` so look.lua can blur/animate them.

**2. Build the shell.** Keep every colour, font, size and timing in one `Theme.qml` singleton that
reads `colors.json` (with fallbacks). One QML file per component. Implement §3.1–3.3 fully before
polishing. Level 3: build component by component, screenshot each.
Test next to the running shell without switching: `qs -c <id> -d` (it can't own notifications /
tray while the other shell runs — that's expected), then stop it by PID (`qs kill -c <id>`).

**3. Style** (levels 2–3): `style.py` with icons + cursors via iconkit; test the builders
directly before switching (see how in git history: import writers, `configure(setup)`, call
`style.icons(p, ctx)`), render previews with `magick`, look at them.

**4. Wallpapers:** assign some (or generate) so the view isn't empty.

**5. Switch and verify:** `~/.config/theme/theme setup <id>`, then check:
- `qs ipc show` lists capture, overview, voxtype, deck (+ lock/console/starchart if used);
  `qs log` has no errors; `hyprctl configerrors` is empty.
- `fc-match sans-serif`, `gsettings get org.gnome.desktop.interface font-name|cursor-theme|icon-theme`.
- Screenshots (`grim`, after checking the screens are on) of: the bar, every panel page, a tray
  menu (`qs ipc call tray menu 0` in Observatory; add a similar IPC for testing), the lock preview,
  the launcher/menus, one notification (`notify-send`), each colour theme (`theme set`).
- Every screen shape: the bar and overview on a portrait monitor (1080 wide) and a small laptop
  panel (1366 × 768) must not overlap or overflow.
- Every keybind in §3.1 does something. The polkit prompt appears (`pkexec true`, cancel it).
- Switch back to the user's setup and theme afterwards (`theme setup <prev>`, `theme set <prev>`),
  and say that you did.

**6. Document + commit:** a `quickshell/<id>/README.md` (structure, IPC, how to tweak — see
Observatory's), update the table in §1 of this file and the repo `README.md`, then
`git add -A && git commit` (author av <ashervirgona@gmail.com>, co-author line) and `git push`.
Check `git status` for generated files before committing (§4.4).

---

## 8. Gotchas (all learned the hard way)
- **Hyprland is Lua.** `hyprctl dispatch <old syntax>` fails; use `hyprctl eval '<lua>'`.
  `hyprctl eval` rejects unknown rule keys, so it's a good validator. When two window rules set
  the same property, the **first** one wins — keep such rules in one place (per setup look.lua).
- **Never `pkill -f <pattern>`** where the pattern is in your own command line (kills your shell).
  Kill by PID, or `qs kill -c <config>`.
- **grim hangs forever when monitors are off** (hypridle: dim 2.5 min, lock 5 min, DPMS off 5.5
  min). Check `hyprctl monitors -j` → `dpmsStatus` first, and always use a timeout.
- **If screenshots suddenly show the lock screen**, the user went idle; it isn't a bug. Don't try
  to unlock it.
- **Quickshell live reload** misses files loaded by path; reference components as types, and
  `touch shell.qml` to force a reload. A missing `Theme.<prop>` silently evaluates to undefined
  (a tray menu once had width 0 because `trayMenuWidth` didn't exist) — check `qs log`.
- **zsh:** `echo ===` is special syntax; unmatched globs abort the command (`setopt nullglob`).
- **The root disk is USB 2.0**: heavy I/O freezes things; pip installs are slow. If the shell
  "freezes", check `/proc/pressure/io` and D-state processes first.
- **sudo needs the user's password**: hand them exact commands to run with `!`.
- **Secrets:** `skwd-wall-v2/config.json` holds a Wallhaven API key — never track it; scan
  `git ls-files` for keys/tokens before pushing anything new.
- Walker only re-reads CSS on restart (the theme tool restarts its service). Elephant menus are
  cached per provider; restart `elephant` after adding a menu file, and register new menus in
  `walker/config.toml`.
- Don't send `wtype` keystrokes unless your own window has focus.
- **QML names that clash:** don't call a signal or function `left`, `right`, `focus` or `set` (they
  shadow Item properties or are reserved); a `Repeater` whose model is a plain count rebuilds every
  delegate when the count changes (use a `ScriptModel` of indices); a singleton that only holds an
  `IpcHandler` isn't created (so its target doesn't exist) until something touches it: touch it in
  `shell.qml`'s `Component.onCompleted`.
- **An `Image` that fails to load never retries:** publish a file path only once the file exists
  (the lock screens' snapshots: `LockState.engage()` sets `shot` after grim finishes).
- **Test a new shell beside the live one** with `qs -c <id> -d` and `qs ipc -c <id> call …`; nothing
  renders while the session is locked (not even `grabToImage`), so wait for the user to come back.
- **Cut (chamfered) window corners:** Hyprland's `rounding` with `rounding_power = 1.0` draws the
  corners as straight diagonals, and the border follows them. An overlay can't cut a window: it can
  only paint over its corner (Netrunner's first frames did that, and it showed as black triangles).
- **Portrait screens:** bars and overviews must adapt to the screen they're on (Netrunner's bar has
  width tiers; both overviews pick the column count that makes the tiles biggest).
- **Vulnerabilities / updates:** every setup has an `Updates.qml` service (arch-audit, checkupdates;
  `qs ipc call updates report`); Netrunner's lives inside its Status.qml.
- **GTK 4 styles vs Walker:** user CSS in `gtk-4.0/gtk.css` outranks Walker's own theme, so a setup's
  GTK 4 widget rules are scoped to `window:not(.walker)` and its Walker `layout.xml` gives the window
  the class `walker` (Memphis, Netrunner).
- **Special workspaces as dashboards** (Netrunner's deck): give the workspace gaps with
  `hl.workspace_rule`, open it together with a window (a special workspace with nothing on it has
  nothing to close), and let Hyprland hide it when its last window closes.
- **QML reserved-ish names, again:** a property called `signal` doesn't parse; property names can't start
  with a capital (`W`, `H`); a Theme colour and a size can't share a name (`control`). `Column` and
  `Row` have a read-only `implicitHeight`. `ListView` sections need model roles: with a JS array
  model, put header rows into the array instead.
- **A PopupWindow isn't an Item:** inside one, `parent.hovered` is undefined; give the target an id.
- **Laptop brightness without root:** logind's `SetBrightness` on the session
  (`busctl call org.freedesktop.login1 /org/freedesktop/login1/session/auto org.freedesktop.login1.Session SetBrightness ssu backlight <dev> <raw>`)
  — Disguise's `services/Backlight.qml`.
- **Don't edit a shell's QML while the session is locked by it:** live reload would rebuild the lock.
  Wait for the user to unlock.
