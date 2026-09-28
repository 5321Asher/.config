# Memphis

Your dad's computer, around 1998 (Memphis was Windows 98's code name): grey bevelled windows, a
Start button, a taskbar with the clock in the corner, Control Panel for everything. This is the
Quickshell half of the **Memphis setup**; the rest (colour schemes, fonts, Hyprland look, kitty as an
MS-DOS Prompt, GTK/Qt styles, cursors, wallpapers) lives in `~/.config/theme/setups/memphis/`.

Switch to it with `~/.config/theme/theme setup memphis` (or Start → Settings → Setup in any setup).
Run it on its own with `qs -c memphis`; it reloads live when a file changes (`touch shell.qml` if a
change doesn't show).

## Structure

```
shell.qml                 what's on screen: taskbars, the desk (shell windows), messages, menus, lock…
theme/Theme.qml           every colour (98's system colours, from the scheme), font, size and timing
widgets/                  98's widget kit: Bevel (the two-line edges), Btn, Check (also option
                          buttons), Field, Combo, Spin, TrackBar, Progress, Tabs, Group, ListBox,
                          Scroll, Sep, Win (a window: caption, menu bar, status bar), Tip (tooltips),
                          Glyph (pixel drawings: caption buttons, arrows, checks), Dither, Chart, Icon
taskbar/                  Taskbar (Start, Pager = workspace buttons, TaskButtons, NotifyArea + clock),
                          Flag (the Start button's flag), VolumePopup, TrayMenus (tray apps' menus)
menus/                    Menus (the open cascade), MenuLayer (drawn per screen), MenuPanel (one level)
start/StartMenu.qml       what's in the Start menu (Programs, Documents, Settings, the shared menus…)
desk/Desk.qml             the shell's windows: which are open, where; `deck open <page>` -> applets
desk/DeskLayer.qml        draws them, per screen (input only where a window is)
desk/windows/             Control Panel, Run…, Shut Down, Log Off, Help, Messages (inbox),
                          Media Player, Volume Control
desk/applets/             Properties sheets: Date/Time, Display, Multimedia, Network, System,
                          Lighting, Focus Timer (Timer98), Power Management, Claude; Props = the frame
notifications/            Message (one notification as a little window), MessageStack
lock/                     LockState (PAM), Lock, LogonFace ("Welcome to Memphis"), pam/memphis-lock
utilities/                Overview (workspaces), DictationOsd (Sound Recorder), PolkitPrompt
services/                 the logic, shared with the other setups (Net, Capture, Displays, Weather…),
                          plus Elephant (the shared menus), Notifs (notification server), StayAwake
colors.json               written by the theme tool on every scheme switch (don't edit)
```

## How it maps onto the other setups

| other setups | Memphis |
|---|---|
| root menu (SUPER + Space) | the Start menu (`qs ipc call start toggle`) |
| app launcher (SUPER + CTRL + Space) | Run… (`qs ipc call run toggle`): type, matches drop down, Enter |
| side panel / control deck | Control Panel: quick switches, levels, capture, dictation and power in its left pane; double-click an icon for its Properties |
| `deck open helm` | Control Panel |
| `deck open radio / log / almanac` | Multimedia (Now Playing) / the Inbox / Date/Time |
| `deck open telemetry / hangar` | System → Performance / Device Manager |
| `deck open optics / lamps / chronometer` | Display → Settings / Lighting / Focus Timer |
| `deck open comms / claude` | Network → Wi-Fi / Claude |
| notifications | little windows above the clock; history in the Inbox (tray envelope) |

The Start menu reads the same shared menus as Walker (`~/.config/elephant/menus`): their Apps entry
is Programs, Style is under Settings, Power is Shut Down / Log Off, and any other root entry
(Trigger…) gets its own cascade. New functions go into those menus, never into this UI.

## Tweaking

**Colours** come from the scheme, not from here: `~/.config/theme/setups/memphis/themes/*.toml`
(98's names: `desktop face light hilight shadow dkShadow window windowText btnText title title2
titleText inactiveTitle… select selectText grayText info infoText lcd lcdText`), then `theme reload`.
Each theme's `[terminal]` table is the MS-DOS Prompt (kitty, btop, Neovim): black, the VGA colours.

**Sizes** are in `theme/Theme.qml`: the taskbar, buttons, caption, menu rows, icons. W95FA is drawn
on a 16 px grid, so the text stays at 16 px (12 pt).

**Wallpapers**: `~/.local/share/theme/venv/bin/python ~/.config/theme/setups/memphis/wallpapers.py`
redraws each scheme's plain colour and 3.1-style pattern, the 95 clouds, Walker's side picture and
fastfetch's logo.

## IPC

```
qs ipc call start toggle            Start menu            (SUPER + Space, via ~/.config/theme/menu root)
qs ipc call run toggle              Run…                  (SUPER + CTRL + Space, via ~/.config/theme/menu apps)
qs ipc call deck open <page>        a Control Panel applet (the shared page names, above)
qs ipc call desk open <id>          any window: control run shutdown logoff help messages media volume applet:<name>
qs ipc call overview toggle         Workspaces
qs ipc call notifications clear     delete every notification (| dnd toggles Do Not Disturb)
qs ipc call tray list | menu <n>    tray apps; open one's menu (for testing)
qs ipc call lock lock               lock the session      (SUPER + L, idle, suspend: loginctl → theme lock)
qs ipc call lock preview            look at the lock screen without locking (Esc closes)
qs ipc call capture …, voxtype …    screenshots / recording, dictation (shared)
```

## If the lock screen ever misbehaves

It can't lock you out by design: only a correct password (checked by `pam_unix`, with no faillock)
unlocks; a wrong one shows 98's message box and clears the field. If Quickshell itself crashed while
locked, Hyprland shows a "lockscreen died" screen; `misc.allow_session_lock_restore` is on, so from
a TTY (`Ctrl + Alt + F3`, log in) run `WAYLAND_DISPLAY=wayland-1 hyprlock` and unlock there (Memphis's
hyprlock is a 98 logon box too), then `Ctrl + Alt + F1`.
