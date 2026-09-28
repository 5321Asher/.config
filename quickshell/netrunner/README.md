# Netrunner

A cyberdeck's desktop, after Night City: red and cyan on near-black glass, cut corners, tracked caps
with `//` between them, Japanese in the margins, and the machine's real state (vulnerabilities,
updates, the firewall, failed units) read out like a netrunner's HUD. This is the Quickshell half of
the **Netrunner setup**; the rest (profiles, fonts, Hyprland look, kitty's header, GTK/Qt, cursors,
wallpapers) lives in `~/.config/theme/setups/netrunner/`.

Switch to it with `~/.config/theme/theme setup netrunner` (or the hub / Walker: Style → Setup).
Run it on its own with `qs -c netrunner`; it reloads live (`touch shell.qml` if a change doesn't show).

## Structure

```
shell.qml                what's on screen
theme/Theme.qml          every colour, font, size and timing
widgets/                 the kit: Chamfer (cut-corner box), Tag (the red slanted tag), Label (tracked
                         caps), Jp, Blocks (segmented meter), Spark (sparkline), Hazard (stripes),
                         Scramble (text that decodes itself), Panel, Section, KV, Chip, Row2, Btn,
                         Switch, Slider, Field
bar/                     Bar (tag, Workspaces, Ticker, readouts, Tray, IDLE // HOLD, clock), TrayMenus
frames/Frames.qml        the frames' red accents (Hyprland cuts the corners and draws the hairline: rounding_power 1)
dash/                    the deck (special:deck): DeckState (opens it with a terminal), Deck, SysDiag, QueuePanel, VulnWatch, SignalPanel
rig/                     the rig (control panel): Rig, RigState (the shared `deck` IPC), pages/*
launcher/                HubState (the root menu, as a quickhack list), Exec + ExecState (app launcher)
menus/                   the cascade (Menus, MenuLayer, MenuPanel): the hub and tray menus
notifications/           Message (one card), MessageStack
lock/                    LockState (PAM), Lock, LockFace, pam/netrunner-lock (pam_unix only)
utilities/               Overview (subnet map), DictationOsd (voice), PolkitPrompt (root access),
                         OverviewState, Debug (render to PNG for testing)
services/                the shared logic (Net, Capture, Displays, Weather…) plus Status (the HUD's
                         facts), Queue (daily gigs), Elephant (the shared menus), Notifs, StayAwake
```

## The HUD's facts (services/Status.qml)

| shown as | where it comes from |
|---|---|
| `VULN n` / VULN WATCH | `arch-audit` (packages with CVEs; `-u` for the ones an update fixes), every 30 min, SWEEP re-runs |
| `PKG n PENDING` | `checkupdates` (pacman-contrib), every 30 min |
| `SHIELD` | the firewall service that's active (ufw, nftables, firewalld), else NONE |
| `ICE` | NOMINAL (shield up, no failed units), EXPOSED (no firewall), BREACHED (failed units) |
| `FAILED UNITS`, `PING`, `SSH`, `TRACE` | systemctl --failed (system + user), ping 1.1.1.1, sshd, the Tailscale exit node |
| `SESSION n` | how many times this shell has started |
| `QUEUE a/b` | services/Queue.qml: ~/.local/share/netrunner/queue.json; ticks clear every morning |

They're also written to `~/.cache/netrunner/status.json` for the terminal greeting
(`setups/netrunner/templates/greeting.sh`, used by fastfetch).

## How it maps onto the other setups

| shared | Netrunner |
|---|---|
| root menu (SUPER + Space) | the hub: `qs ipc call hub toggle` (also the red tag) |
| app launcher (SUPER + CTRL + Space) | EXEC: `qs ipc call exec toggle` |
| `deck open <page>` | the rig's page (helm comms radio log almanac telemetry hangar optics lamps chronometer claude) |
| workspace overview | SUBNET MAP (`overview toggle`, right-click a workspace number) |

The deck is Netrunner's own: the special workspace `deck` (the hub, the DECK chip in the bar, or
`qs ipc call dash toggle`). It never opens empty: if nothing is on it, a terminal starts there
(`kitty --class netrunner-deck`), and closing the last window on it puts the deck away. Windows tile top-left and
SYS.DIAG, QUEUE, VULN WATCH and SIGNAL fill the rest (look.lua sets that workspace's gaps).

## IPC

```
qs ipc call hub toggle | exec toggle | deck open <page> | overview toggle
qs ipc call queue add "Gym|health" | toggle <n> | remove <n> | list
qs ipc call status sweep | report
qs ipc call notifications clear | dnd
qs ipc call tray list | menu <n>
qs ipc call lock lock | preview | close
qs ipc call debug grab bar /tmp/bar.png      render a piece to a PNG (testing; not while locked)
```

## Tweaking

Colours come from the profile (`~/.config/theme/setups/netrunner/themes/*.toml`: accent = red,
purple = the second colour (cyan), warn = yellow, `bright`), then `theme reload`. Sizes, timings and
the deck's panel sizes are in `theme/Theme.qml` (keep `deckRight` / `deckBottom` in step with the
special:deck gaps in `setups/netrunner/files/hypr/look.lua`).

## If the lock screen ever misbehaves

Only a correct passphrase (pam_unix, no faillock) unlocks; a wrong one just says ACCESS DENIED. If
Quickshell crashed while locked: `Ctrl + Alt + F3`, log in, `WAYLAND_DISPLAY=wayland-1 hyprlock`, then
`Ctrl + Alt + F1`.
