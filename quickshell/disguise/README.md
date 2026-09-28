# Disguise

Windows 11, as close as a Hyprland desktop can get: a centred taskbar on Acrylic, the Start menu,
Search, Quick Settings, the notification centre with the calendar and Focus, Widgets, Task View, a
Settings app, toasts, the volume flyout, User Account Control, voice typing and the lock screen, in
Segoe UI Variable with Segoe Fluent Icons, the Win11 icon theme and Windows' cursors, over a Bloom.
This is the Quickshell half of the **Disguise setup**; the rest (colour themes, fonts, Hyprland look,
kitty as Windows Terminal, GTK/Qt styles, cursors, the Bloom wallpapers) lives in
`~/.config/theme/setups/disguise/`.

Switch to it with `~/.config/theme/theme setup disguise` (or Settings → Personalization → Themes in
any setup's own menus). Run it on its own with `qs -c disguise`; it reloads live when a file changes
(`touch shell.qml` if a change doesn't show).

## Structure

```
shell.qml                 what's on screen: taskbars, flyouts, toasts, OSD, Task View, voice typing, UAC, Settings, lock
theme/Theme.qml           every colour (Windows' Fluent tokens, from the theme), font, size and timing
widgets/                  the WinUI kit: Btn (standard / accent / subtle), Toggle, Slider, Check (and radio),
                          Field, Combo, Card, SettingRow (Settings' rows), Acrylic (a flyout's surface),
                          Progress, Ring, Scroll, Tip (tooltips), Txt, Glyph (Segoe Fluent Icons), AppIcon,
                          Avatar, Logo (the four panes), WeatherIcon, Divider, Header
taskbar/                  Taskbar (Widgets weather · Start, Search, Task View, apps · tray, status, clock,
                          show desktop), TaskButtons (grouped apps, pills, jump lists, hover thumbnails),
                          WinX (Start's right-click menu), ShowDesktop
flyouts/                  Flyouts (which one is open; context menus), FlyoutLayer (draws them per screen),
                          StartMenu, SearchPane, QuickSettings, NotificationCenter, WidgetsBoard,
                          TrayOverflow, TrayMenus (tray apps' DBus menus), MenuPanel, Apps (apps, pins,
                          recent files, windows)
settings/                 SettingsApp (pages, the deck IPC), SettingsWindow (a real floating window), Look
                          (wallpapers, themes, setups), pages/ (one file per page)
notifications/Toasts.qml  notification pop-ups, bottom right
osd/Osd.qml               the volume / brightness flyout
lock/                     LockState (PAM), Lock, LockFace (curtain + sign-in), pam/disguise-lock
utilities/                TaskView + TaskViewLayer (overview), VoiceTyping (dictation), Uac (polkit)
services/                 the logic, shared with the other setups (Net, Capture, Displays, Weather…), plus
                          Backlight (the laptop panel through logind), Elephant (the shared menus),
                          Notifs (notification server), StayAwake, Updates
colors.json               written by the theme tool on every theme switch (don't edit)
```

## How it maps onto the other setups

| other setups | Disguise |
|---|---|
| root menu (SUPER + Space) | the Start menu (`qs ipc call start toggle`); the shared menus (Trigger, Style…) are its Recommended items and cascades in Start's right-click menu (`winx open`) |
| app launcher (SUPER + CTRL + Space) | Search (`qs ipc call search toggle`): apps, Settings pages, recent files, sums, the web |
| side panel / control deck | Quick Settings (the network · volume · battery button) and the Settings app |
| `deck open helm / radio / log / almanac` | Settings → System / Sound / Notifications / Time & language |
| `deck open telemetry / hangar / optics` | Settings → System → Task Manager / Bluetooth & devices / System → Display |
| `deck open lamps / chronometer / comms / claude` | Personalization → Dynamic Lighting / System → Focus / Network & internet / Accounts |
| notifications | toasts above the clock; history in the notification centre (the clock) |
| vulnerability watch / pending updates | Windows Update and Privacy & security in Settings; a tray shield while there's something to do |
| workspace overview | Task View (`overview toggle`): this desktop's windows, the desktops along the bottom |

## Tweaking

**Colours** come from the theme: `~/.config/theme/setups/disguise/themes/*.toml` (Windows' Fluent
tokens by name: `mica flyout card control… text text2 text3 accent accentHover accentLink…`), then
`theme reload`. `[terminal]` is Windows Terminal's Campbell scheme (every theme keeps kitty dark).

**Sizes** are in `theme/Theme.qml` (Windows at 100 %: a 48 px taskbar, 32 px controls, 4 / 8 px
corners). **Pins** (Start and taskbar) and app usage live in `~/.local/state/disguise/pins.json`.

**Wallpapers**: `~/.local/share/theme/venv/bin/python ~/.config/theme/setups/disguise/wallpapers.py`
redraws each theme's Bloom (Pillow), Walker's side picture and fastfetch's logo.

**Fonts**: Segoe UI Variable and Segoe Fluent Icons are Microsoft's designer downloads
(aka.ms/SegoeUIVariable, aka.ms/SegoeFluentIcons) in `~/.local/share/fonts/disguise`; their licence
is for designing Windows apps. For a freely licensed look-alike, set `[fonts] sans` to Selawik.

## IPC

```
qs ipc call start toggle            Start                 (SUPER + Space, via ~/.config/theme/menu root)
qs ipc call search toggle | open q  Search                (SUPER + CTRL + Space, via ~/.config/theme/menu apps)
qs ipc call flyout open <k>         quick | notif | widgets | tray  (and toggle, close)
qs ipc call winx open               Start's right-click menu
qs ipc call settings open <page>    any Settings page (home system display sound notifications focus power
                                    storage performance about bluetooth network vpn personalization
                                    background themes lighting apps accounts time security update)
qs ipc call deck open <page>        the shared deck pages, mapped onto Settings (above)
qs ipc call overview toggle         Task View
qs ipc call updates sweep | report  re-check vulnerabilities and updates; print what's known
qs ipc call notifications clear     delete every notification (| dnd toggles Do not disturb)
qs ipc call tray list | menu <n>    tray apps; open one's menu (for testing)
qs ipc call lock lock               lock the session      (SUPER + L, idle, suspend: loginctl → theme lock)
qs ipc call lock preview            look at the lock screen without locking (Esc closes)
qs ipc call capture …, voxtype …    screenshots / recording, dictation (shared)
```

## If the lock screen ever misbehaves

It can't lock you out by design: only a correct password (checked by `pam_unix`, with no faillock)
unlocks; a wrong one says "The password is incorrect. Try again." and clears the field. If
Quickshell itself crashed while locked, Hyprland shows a "lockscreen died" screen;
`misc.allow_session_lock_restore` is on, so from a TTY (`Ctrl + Alt + F3`, log in) run
`WAYLAND_DISPLAY=wayland-1 hyprlock` and unlock there (Disguise's hyprlock is the sign-in screen
too), then `Ctrl + Alt + F1`.
