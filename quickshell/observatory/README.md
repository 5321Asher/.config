# Observatory

The control panel of a deep-space observatory: brass instruments, phosphor readouts, arcs and
orbits. This is the Quickshell half of the **Observatory setup**; the rest of the setup (colour
theme, fonts, Hyprland look, kitty, wallpapers) lives in `~/.config/theme/setups/observatory/`.

Switch to it with `~/.config/theme/theme setup observatory` (or Walker / console: Style → Setup).
`~/.config/quickshell/default` then points here, so plain `qs` and `qs ipc …` talk to this shell.
Run it on its own with `qs -c observatory`; it reloads live when a file changes.

## Structure

```
shell.qml                     what's on screen: the horizon bars, transmissions, star chart, console, lock
theme/Theme.qml               every colour, font, size and timing (the only place to tweak them)
bar/HorizonBar.qml            1 · the horizon line / panel, one per monitor (holds 2-4, draws 5)
bar/HorizonState.qml          pinned or not: qs ipc call horizon toggle | pin | unpin
bar/Sundial.qml               2 · the clock in the dome
bar/Orbits.qml                3 · orbital workspaces + the focused window
bar/Instruments.qml           4 · the three gauges (bar/Gauge.qml is one gauge)
services/SysInfo.qml          CPU / memory / CPU temperature, one sh loop every 2 s
services/Radio.qml            5 · cava while media plays, for the waveform on the horizon line
services/Transmissions.qml    6 · the notification server
notifications/                6 · the cards (Transmission.qml) and their stack
launcher/StarChart.qml        7 · the app launcher (SUPER + CTRL + Space)
launcher/Console.qml          the root menu (SUPER + Space): Walker's menus, Observatory's look
lock/                         8 · lock screen: Lock.qml, LockFace.qml, LockState.qml (PAM),
                              pam/observatory-lock (password only, no faillock)
cava.conf                     cava settings for the waveform
colors.json                   written by the theme tool on every theme switch (don't edit)
```

## Tweaking

**Colours** come from the colour theme, not from here: edit
`~/.config/theme/setups/observatory/themes/deep-field.toml` (or copy it to make a new theme in this
setup) and run `theme reload`. Besides the usual keys (bg, fg, accent = brass, purple = second
accent, danger …) Observatory reads its own: `brassBright`, `brassDeep`, `phosphor`, `phosphorDim`,
`signal`, `starlight`. The values after `??` in `Theme.qml` are only fallbacks.

**Fonts** come from the setup (`setup.toml` → `[fonts]`): `mono` is the data font, `display` the
label font (used in small caps). They're applied system-wide, not just here.

**Sizes and timings** are all in `theme/Theme.qml`, grouped by component: bar height, dome size,
glow, sundial radius, orbit size, gauge alarm threshold and temperature range, waveform amplitude,
notification timeout and typing speed, star-chart and console radii, lock ring size, and the motion
(`fast` / `normal` / `slow` ms with an OutCubic curve).

## IPC

```
qs ipc call horizon toggle      pin the horizon panel open
qs ipc call starchart toggle    app launcher        (SUPER + CTRL + Space, via ~/.config/theme/menu apps)
qs ipc call console toggle      root menu           (SUPER + Space, via ~/.config/theme/menu root)
qs ipc call lock lock           lock the session    (SUPER + L, idle, suspend: loginctl → theme lock)
qs ipc call lock preview        look at the lock screen without locking (Esc closes)
qs ipc call updates sweep       re-check vulnerabilities (arch-audit) and pending updates (checkupdates);
                                shown in the deck's Telemetry page (watch); `report` prints them
```

## Hyprland

Nothing to add by hand; the setup system already does it:

- **Starting the shell:** `hl.exec_cmd("qs")` in `hyprland.lua` starts `quickshell/default`, which
  `theme setup` points at this folder (and restarts on a switch).
- **Keybinds** stay the same in every setup: `SUPER + Space` → `~/.config/theme/menu root` and
  `SUPER + CTRL + Space` → `~/.config/theme/menu apps` run what `setup.toml`'s `[menus]` says
  (here: the console and the star chart; Walker in setups that don't say). `SUPER + L` runs
  `loginctl lock-session` → hypridle's `lock_cmd` → `theme lock` → `setup.toml`'s `lock`.
- **Blur** behind the panels: `setups/observatory/files/hypr/look.lua` (linked in as
  `~/.config/hypr/look.lua` while this setup is active):
  ```lua
  hl.layer_rule({ name = "observatory-blur", match = { namespace = "^observatory-.*" }, blur = true, ignore_alpha = 0.25 })
  hl.layer_rule({ name = "observatory-no-anim", match = { namespace = "^observatory-.*" }, no_anim = true })
  ```

## If the lock screen ever misbehaves

It can't lock you out by design: only a correct password (checked by `pam_unix`, with no faillock)
unlocks, a wrong one just clears the ring. If Quickshell itself crashed while locked, Hyprland shows
a "lockscreen died" screen; `misc.allow_session_lock_restore` is on, so from a TTY
(`Ctrl + Alt + F3`, log in) run `WAYLAND_DISPLAY=wayland-1 hyprlock` and unlock there, then
`Ctrl + Alt + F1` (Hyprland runs on VT 1) to go back.
