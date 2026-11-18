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
                         Switch, Slider, Field; Driver (an animation clock that plays through stalled
                         frames), Holocall (the incoming-call panel the prompts use)
shaders/                 *.frag -> .qsb (build.sh): glitch (arrive / leave), holo (the holocall's
                         projection), tape (the braindance rewind); city/ and body/ are Qt Quick 3D
                         custom materials (compiled at run time, no build step)
bar/                     Bar (tag, Workspaces, Ticker, readouts, Tray, IDLE // HOLD, clock), TrayMenus
frames/Frames.qml        the frames' red accents (Hyprland cuts the corners and draws the hairline: rounding_power 1)
dash/                    the deck (special:deck): DeckState (opens it with a terminal), Deck, SysDiag, QueuePanel, VulnWatch, SignalPanel
rig/                     RIPPERDOC, the rig (control panel): Ripperdoc (the hologram body, the implant
                         slots, the page, the pose blending), RigState (slots, the body, its skeleton and
                         poses, the shared `deck` IPC), pose.js (quaternions, forward kinematics),
                         body.json (mesh + skin weights + vessels + bones: theme/setups/netrunner/body.py),
                         poses.json (the poses, compiled: theme/setups/netrunner/poses.py), pages/*
launcher/                Breach + HubState (BREACH PROTOCOL, the root menu), FastTravel + ExecState (FAST
                         TRAVEL, the app launcher), Braindance + bd.js + ClipboardState (clipboard),
                         Prompt + PromptState (INPUT REQUIRED)
menus/                   the cascade (Menus, MenuLayer, MenuPanel): the hub and tray menus
notifications/           Message (one card), MessageStack
lock/                    LockState (PAM), Lock, LockFace, pam/netrunner-lock (pam_unix only)
utilities/               Overview (subnet map), DictationOsd (voice), PolkitPrompt (ROOT ACCESS holocall),
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
| app launcher (SUPER + CTRL + Space) | FAST TRAVEL: `qs ipc call exec toggle` |
| clipboard (SUPER + V) | BRAINDANCE: `qs ipc call clipboard toggle` |
| prompts (`theme/prompt`) | INPUT REQUIRED holocall: `qs ipc call prompt ask <dir>` |
| `deck open <page>` | RIPPERDOC, that page's implant (helm comms radio log almanac telemetry hangar optics lamps chronometer claude); `deck toggle` = the body with every slot |
| workspace overview | SUBNET MAP (`overview toggle`, right-click a workspace number) |

The deck is Netrunner's own: the special workspace `deck` (the hub, the DECK chip in the bar, or
`qs ipc call dash toggle`). It never opens empty: if nothing is on it, a terminal starts there
(`kitty --class netrunner-deck`), and closing the last window on it puts the deck away. Windows tile top-left and
SYS.DIAG, QUEUE, VULN WATCH and SIGNAL fill the rest (look.lua sets that workspace's gaps).

## The big four: what they do

- **FAST TRAVEL** (launcher/FastTravel.qml): apps are buildings in a 3D Night City (Qt Quick 3D):
  the ocean and a bay to the west, City Center's towers (Arasaka's in red) in the middle, Watson,
  Westbrook, Heywood, Santo Domingo, Pacifica, Dogtown, the Badlands desert outside
  (`water()` / `districtAt()`, drawn again in shaders/city/ground.frag: keep them in step). An app's
  district comes from `districtIndex()`: games, then its name or web-app address (YouTube -> Westbrook,
  GitHub -> Watson, Claude -> City Center), then its categories; `qs ipc call exec districts` lists
  them. Its block is a hash of its id near the district's heart (use never moves it); height = how
  often you run it (the camera frames a tall one whole). Every building glows in its district's colour,
  and so does the pillar of light over the destination. It opens on a random destination;
  typing lights the matches and the camera glides to the best one while a GPS route draws itself;
  Enter dives in and starts it. Esc: clears the search, then pulls back to the city, then closes.
- **BRAINDANCE** (launcher/Braindance.qml): clipboard history as a tape. Tracks LINK CODE PATH TEXT
  IMAGE (bd.js kindOf), gaps over 30 min become cuts. ← → scrub (held: the tape tears), the frame
  rebuilds behind a scan line; Tab = RAW / DECODED (bd.js decode: link parts, JSON, colours, JWT,
  base64, timestamps, numbers, paths, pipelines) / META. Test without touching the real history:
  `NETRUNNER_BD_FIXTURE=<elephant json lines> qs -c netrunner` (actions only logged).
- **Messages** (notifications/Message.qml): a signal line streaks in from the screen's edge, the card
  unfolds down from it and glitches into focus, the sender decodes, the text types out; a bar drains
  until it goes (hover holds it). PRIORITY (critical): red, hazard stripes, a jolt, stays.
- **Holocalls** (widgets/Holocall.qml): INPUT REQUIRED and ROOT ACCESS ring, project in line by line
  and speak their question; answering hangs up (CRT off), Esc drops the signal (static), a wrong
  passphrase bursts red static. The caller is the script that asked (`theme/prompt` sends `from`).
  `qs ipc call polkit preview` shows ROOT ACCESS without polkit (passphrase "netrunner").
- **RIPPERDOC** (rig/Ripperdoc.qml): the rig as the game's cyberware screen, after its layout: the
  game's eleven categories (RigState.pages: FRONTAL CORTEX = claude, OCULAR = optics, CIRCULATORY =
  telemetry, IMMUNE = log, NERVOUS = comms, INTEGUMENTARY = almanac down the left; OPERATING SYSTEM =
  helm, SKELETON = hangar, HANDS = lamps, ARMS = radio, LEGS = chrono down the right), each a red
  name with its state under it and a row of square slots: the implant (its rarity on a bar), its
  switches and readouts (`tilesOf()`, monotone icons), empty "+" sockets; red cables to the body, a
  real human (rig/body.json: MakeHuman's base mesh, skeleton and skin weights, all CC0; made by
  theme/setups/netrunner/body.py, which also prints the landmarks the anchors use) in translucent red,
  a ticked ring behind it and a yellow one at its feet. Its circulatory system runs through it
  (shaders/body/vessels.*): an arterial tree of tubes from the heart (the aortic arch, the aorta down
  the spine, branches round the ribs, arteries down every limb with twigs out to the skin, to every
  finger and toe, the carotids up the neck and over the skull), skinned to the bones. Every heartbeat
  (60 + 110 × CPU load a minute) sends a white-hot wave out along all of it at 1.3 m/s and the blood
  streams outwards under it; opening, the blood fills it from the heart as the body builds from the
  feet; with CIRCULATORY selected it all runs hotter. The body is skinned to MakeHuman's 163 bones
  (flat Nodes placed by `stepPose()` every frame, a `Skin` on the body and the vessels; the vertex
  shaders skin by hand) and strikes a pose for each implant (rig/poses.json, written as directions
  in theme/setups/netrunner/poses.py: bend this, put that hand there, with two-bone IK, then
  compiled to a quaternion per bone; `--preview out.png` draws them): standing on one leg for the
  whole body, two fingers to the temple (FRONTAL CORTEX), shading the eyes (OCULAR), a hand at the
  neck port (OS), a hand over the heart (CIRCULATORY), hands on hips (IMMUNE), arms open (NERVOUS),
  a hand out to the rain (INTEGUMENTARY), a fighting stance (SKELETON), a palm held up (HANDS), a
  flexed arm (ARMS), mid-stride (LEGS). It blends over in 1.15 s (the trunk leads, the fingers
  follow), breathes on top, and a pose can set where the camera films it from (`@view`, `@frame`). The top bar is the game's: LEVEL (hours up), STREET CRED (shell starts), the tabs
  (JOURNAL = the deck, BRAINDANCE, CYBERWARE, MAP = FAST TRAVEL, SUBNET; Q / E), weight (memory) and
  eddies (free MB on /). It opens on the whole body with nothing selected (a page asked for by the bar
  or a menu is only lit up). Selecting one zooms the camera onto that part of the body, moves it and
  the categories into the room left of the page, keeps only its cable, and unfolds the page with an
  item-card header; Tab glides to the next (only the page's content changes over); Esc goes back to
  the whole body, then closes. The page widgets are cyberware cards.
- **SUBNET MAP** (utilities/Overview.qml): opened by a click in a screen's very top-left corner
  (utilities/Corner.qml: resting there only lights it; niri's push corner is off for Netrunner), SUPER
  + O or right-click on the workspaces. A scan ring blasts out of where it was opened over a lit hex
  grid; nodes materialise as it reaches them (outline drawn, overshooting pop, glitch) with links and
  data packets; hover lifts a node (glitch burst, racing edge light, springing brackets, a scan bar,
  lit links); closing implodes them back into the ring; picking a workspace dives into its node.
- **The lock** (lock/LockFace.qml): the game's flatline (shaders/ekg.frag). Locking, the desktop
  drains to red and collapses into a line while a dying heartbeat traces along it, then FLATLINED;
  locked, an EKG monitor (a sleeping pulse; each key kicks a beat; wrong: red arrhythmia; cooldown: a
  flat red line); unlocking, CLEAR / REVIVING, two defibrillator jolts, and the line splits open onto
  the desktop. The previous face (black ICE: relic glitch, hex wall, ICE core, Kiroshi boot) is
  lock/LockFace.qml.old: rename it back to LockFace.qml to return to it. Security notes below.

The 3D views are built on each open and dropped on close (a Loader): Qt Quick 3D 6.12 aborts
(`QSSGGlobalRenderNodeData::reindex`) when a View3D's window is hidden and shown again. That costs
one ~40-55 ms frame per open on a laptop-class GPU; the intros run on Driver clocks so they don't skip.

## Screen shapes

The bar sheds readouts to fit its width (`tier` in bar/Bar.qml: the full HUD from 1800 px, a middle
set from 1300 px, and on a portrait monitor or a small panel just the tag, workspaces, a short
ticker, tray and clock). SUBNET MAP picks its column count for the screen's shape, so on a portrait
monitor the workspaces stack in a tall grid.

## IPC

```
qs ipc call hub toggle | exec toggle | clipboard toggle | dash toggle | deck toggle | deck open <page> | overview toggle
qs ipc call exec state | exec districts | clipboard state | deck state | lock state | polkit preview | polkit state   (tests)
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

## The lock's security (audited 2026-11-17)

- Only a PAM success unlocks, and only the lock it was typed into (`LockState.session`): closing a
  preview or finishing an unlock just before a new lock can't undo that lock (it could before).
- pam_unix only (no faillock); after 5 wrong in a row each try waits 5, 10, 20, 40, then 60 s.
- Once sealed nothing of the desktop shows (it used to stay behind as a blur).
- At login, `theme lock --boot` locks with hyprlock (no grace) at once and hands over to this lock
  when the shell answers (`qs ipc call lock takeover`): the session is locked from ~0.1 s after
  Hyprland starts, and stays locked through the handover (hyprlock is killed, Hyprland keeps the
  lock, allow_session_lock_restore lets this one take it).
- A shell that starts under a lock (it crashed or restarted while locked) takes the lock over itself.
- hypridle waits for the lock before letting the machine sleep (`inhibit_sleep = 3`).
- No keybind runs while locked. Any process of yours could still kill the shell and claim the lock
  (allow_session_lock_restore): that needs code running as you already, so it's not a way in.

## If the lock screen ever misbehaves

Only a correct passphrase (pam_unix, no faillock) unlocks; a wrong one just says ACCESS DENIED. If
Quickshell crashed while locked: `Ctrl + Alt + F3`, log in, `WAYLAND_DISPLAY=wayland-1 hyprlock`, then
`Ctrl + Alt + F1`.
