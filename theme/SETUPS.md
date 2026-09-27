# Setups

A **setup** is a whole desktop: its Quickshell, Walker theme, Hyprland look, kitty, hyprlock, cava,
fastfetch layout, fonts, cursor and icons, and its own colour themes. Keybinds, the menus' contents
(elephant) and the session services below are shared. Nothing else is: two setups never share a
colour theme or a config file.

```
theme setups                 list them          theme setup <id>     switch
theme list                   this setup's themes, theme set <id>     switch theme
```

## Where a setup lives

```
theme/setups/<id>/setup.toml            name, fonts, cursor, icons, default theme, lock, [menus]
theme/setups/<id>/themes/*.toml         its colour themes
theme/setups/<id>/style.py              optional: gtk3 / gtk4 / qss / satty / icons / cursors(p, ctx)
theme/setups/<id>/images/<theme>/       walker.*, fastfetch.* per theme (_default/ as fallback)
theme/setups/<id>/templates/            fastfetch.jsonc
theme/setups/<id>/files/…               linked into ~/.config on a switch (kitty/kitty.conf,
                                        hypr/look.lua, hypr/hyprlock.conf, cava/config)
quickshell/<id>/                        its shell (quickshell/default points at the active one)
walker/themes/<id>/                     its Walker theme (walker/themes/active points at it)
~/Pictures/Wallpaper-Themes/<id>/<theme>/   wallpapers per theme (_all/ = any theme in the setup)
```

`theme/iconkit.py` builds icon and cursor themes from a style.py (Sharp: square folders, flat
mitred cursors; Observatory: brass folders, brass cursors).

## Making a new setup

1. Copy the closest setup's folder under `theme/setups/`, rename it, edit `setup.toml`.
2. Give it at least one theme in `themes/`, and `default_theme` pointing at it.
3. Make `quickshell/<id>/` (or copy one) and `walker/themes/<id>/`.
4. Go through the checklist below, then `theme setup <id>`.

## Checklist: what every setup's shell must provide

The keybinds, hypridle and the elephant menus are shared, so they call these by name. A shell that
lacks one leaves a key that silently does nothing.

**IPC targets** (`qs ipc call …`)

| target | functions | used by |
|---|---|---|
| `capture` | `screenshot(mode)` region/screen, `ocr()`, `toggleRecording()` | SUPER+SHIFT+S / T, Trigger menu |
| `overview` | `toggle()`, `open()`, `close()` | workspace overview |
| `voxtype` | `toggle()`, `cancel()` | dictation (SUPER+Z) |
| `deck` | `open(page)`, `toggle()`, `close()` | pages: helm radio log almanac telemetry hangar optics lamps chronometer comms claude |

**Session services** (exactly one process may own each, which is why the old shell is stopped
before the new one starts)

- **Notifications** server, with history and do-not-disturb (critical ones still pop up).
- **Tray** (StatusNotifier host) with menus.
- **Polkit agent** (admin password prompts). The shell must be started inside the login session:
  `theme setup` / `theme shell` start it via `hyprctl dispatch 'hl.dsp.exec_cmd("qs")'`.
- **Lock screen**: `setup.toml`'s `lock` command, run by `theme lock` (hypridle's lock_cmd,
  SUPER+L, suspend). Must never lock you out: a wrong password only asks again.

**Features both current setups have** (keep new setups at parity): Wi-Fi / Bluetooth / Tailscale
(with exit node), do not disturb, stay awake (`systemd-inhibit --what=idle`), lights follow the
theme (OpenRGB), volume per app + outputs / inputs, monitor brightness (ddcutil), display layout,
capture + recording, dictation with a live mic meter, weather + moon, CPU / GPU / memory / storage /
network stats + "open btop", batteries / drives (mount, eject) / fans, focus timer + pomodoro,
Claude Code usage, workspace overview, notification history.

## The keyring (GNOME Keyring), for every setup

Secrets (browser passwords, git and GitHub credentials, app logins) live in GNOME Keyring's `login`
keyring. It is session-wide, so it works the same in every setup, but each setup's **lock screen**
must pass the password on so unlocking the screen also unlocks the keyring:

- **hyprlock** (Sharp): uses `/etc/pam.d/hyprlock` → `login`, which has
  `auth optional pam_gnome_keyring.so` and `session optional pam_gnome_keyring.so auto_start`.
  Any setup whose `lock` is hyprlock gets this for free.
- **A Quickshell lock** (Observatory): its own PAM file (`quickshell/<id>/lock/pam/<name>`) needs,
  after `auth required pam_unix.so`:
  ```
  -auth optional pam_gnome_keyring.so
  ```
  (`optional` so it can never make an unlock fail, `-` so it's skipped if gnome-keyring is missing.)

The session autologs in on tty1, so nothing unlocks the keyring at boot: the first app that needs
a secret after a boot shows GNOME's unlock prompt once (or unlocking the lock screen does it). Give
the `login` keyring the same password as your account, or the PAM unlock can't open it.

Apps: Brave / Chromium use it through `~/.config/{brave,chromium}-flags.conf`
(`--password-store=gnome-libsecret`); `gh` and git use it for GitHub; Seahorse (Passwords and Keys)
shows what's stored. The daemon starts from `gnome-keyring-daemon.socket` (systemd user unit).
