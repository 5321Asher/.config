-- Keybinds, built from scratch.
-- Added by Walker: SUPER + Space → Trigger → Add keybind (removal too). Editing by hand is fine:
-- one hl.bind(...) per line, an optional "-- description" comment at the end shows in the cheat sheet.

-- Bootstrap: opens the Walker menu, where "Add keybind" lives. Remove it once you have your own.
hl.bind("SUPER + Space", hl.dsp.exec_cmd("~/.config/theme/menu root")) -- Menu (the setup's root menu: Walker, or its own)
hl.bind("SUPER + C", hl.dsp.window.close()) -- Close window
hl.bind("SUPER + F", hl.dsp.window.fullscreen()) -- Toggle fullscreen
hl.bind("SUPER + I", hl.dsp.layout("togglesplit")) -- Toggle split direction
hl.bind("SUPER + P", hl.dsp.window.pseudo()) -- Toggle pseudo-tiling
hl.bind("SUPER + G", hl.dsp.group.toggle()) -- Toggle window group (tabs)
hl.bind("SUPER + Tab", hl.dsp.group.next()) -- Next window in group
hl.bind("SUPER + SHIFT + Tab", hl.dsp.group.prev()) -- Previous window in group
hl.bind("SUPER + left", hl.dsp.focus({ direction = "left" })) -- Focus left
hl.bind("SUPER + right", hl.dsp.focus({ direction = "right" })) -- Focus right
hl.bind("SUPER + up", hl.dsp.focus({ direction = "up" })) -- Focus up
hl.bind("SUPER + down", hl.dsp.focus({ direction = "down" })) -- Focus down
-- Swap with the neighbouring window; if there is none but the monitor that way is empty, move there instead.
local function swap_or_move(dir)
  return function()
    if hl.dispatch(hl.dsp.window.swap({ direction = dir })).ok then return end
    local cur = hl.get_active_monitor()
    if not cur then return end
    local cx, cy = cur.x + cur.width / 2, cur.y + cur.height / 2
    for _, m in ipairs(hl.get_monitors()) do
      local mx, my = m.x + m.width / 2, m.y + m.height / 2
      local beside = (dir == "left" and mx < cx) or (dir == "right" and mx > cx)
        or (dir == "up" and my < cy) or (dir == "down" and my > cy)
      if m.id ~= cur.id and beside and (not m.active_workspace or m.active_workspace.is_empty) then
        hl.dispatch(hl.dsp.window.move({ direction = dir }))
        return
      end
    end
  end
end
hl.bind("SUPER + SHIFT + left", swap_or_move("left")) -- Swap window left (or move to empty monitor)
hl.bind("SUPER + SHIFT + right", swap_or_move("right")) -- Swap window right (or move to empty monitor)
hl.bind("SUPER + SHIFT + up", swap_or_move("up")) -- Swap window up (or move to empty monitor)
hl.bind("SUPER + SHIFT + down", swap_or_move("down")) -- Swap window down (or move to empty monitor)
hl.bind("SUPER + CTRL + left", hl.dsp.window.resize({ x = -40, y = 0, relative = true }), { repeating = true }) -- Shrink window width
hl.bind("SUPER + CTRL + right", hl.dsp.window.resize({ x = 40, y = 0, relative = true }), { repeating = true }) -- Grow window width
hl.bind("SUPER + CTRL + up", hl.dsp.window.resize({ x = 0, y = -40, relative = true }), { repeating = true }) -- Shrink window height
hl.bind("SUPER + CTRL + down", hl.dsp.window.resize({ x = 0, y = 40, relative = true }), { repeating = true }) -- Grow window height
for i = 1, 10 do hl.bind("SUPER + " .. (i % 10), hl.dsp.focus({ workspace = i })) end -- Go to workspace
for i = 1, 10 do hl.bind("SUPER + SHIFT + " .. (i % 10), hl.dsp.window.move({ workspace = i })) end -- Move window to workspace
for i = 1, 10 do hl.bind("SUPER + ALT + " .. (i % 10), hl.dsp.window.move({ workspace = i, follow = false })) end -- Send window to workspace (stay here)
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true }) -- Move window with mouse drag
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true }) -- Resize window with mouse drag
-- Hiding the scratchpad leaves keyboard focus on the window just hidden (when the workspace under
-- it is empty). A click on any shell menu (an exclusive layer) makes Hyprland refocus that window,
-- which brings the scratchpad back. So after hiding it, take focus off it: hop to another monitor
-- and back (no pointer warp), or with one monitor, through an empty workspace and back.
local function toggle_scratchpad()
  hl.dispatch(hl.dsp.workspace.toggle_special("magic"))
  local mon = hl.get_active_monitor()
  local win = hl.get_active_window()
  if not mon or mon.active_special_workspace or not (win and win.workspace and win.workspace.special) then return end
  for _, m in ipairs(hl.get_monitors()) do
    if m.id ~= mon.id then
      hl.dispatch(hl.dsp.focus({ monitor = m.name }))
      hl.dispatch(hl.dsp.focus({ monitor = mon.name }))
      return
    end
  end
  local ws = mon.active_workspace and mon.active_workspace.id
  if ws then
    hl.dispatch(hl.dsp.focus({ workspace = "empty" }))
    hl.dispatch(hl.dsp.focus({ workspace = ws }))
  end
end
hl.bind("SUPER + D", toggle_scratchpad) -- Toggle scratchpad
hl.bind("SUPER + SHIFT + D", hl.dsp.window.move({ workspace = "special:magic" })) -- Move window to scratchpad
hl.bind("SUPER + CTRL + Space", hl.dsp.exec_cmd("~/.config/theme/menu apps")) -- App launcher (the setup's: Walker, or its own)
hl.bind("SUPER + Return", hl.dsp.exec_cmd("gtk-launch kitty")) -- kitty
hl.bind("SUPER + B", hl.dsp.exec_cmd("gtk-launch brave-origin-nightly")) -- Brave Origin Nightly
hl.bind("SUPER + N", hl.dsp.exec_cmd("gtk-launch obsidian")) -- Obsidian
hl.bind("SUPER + E", hl.dsp.exec_cmd("thunar")) -- File manager (Thunar)
hl.bind("SUPER + X", hl.dsp.window.float({ action = "toggle" })) -- Toggle floating
hl.bind("SUPER + SHIFT + X", hl.dsp.window.pin()) -- Pin floating window (show on every workspace)
hl.bind("SUPER + K", hl.dsp.exec_cmd("gtk-launch skwd-wall-v2")) -- Wallpaper picker (skwd-wall)
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd("qs ipc call capture screenshot region")) -- Screenshot region
hl.bind("SUPER + SHIFT + T", hl.dsp.exec_cmd("qs ipc call capture ocr")) -- Copy text from region (OCR)
hl.bind("SUPER + SHIFT + P", hl.dsp.exec_cmd("hyprpicker -a")) -- Colour picker (copies hex)
hl.bind("SUPER + V", hl.dsp.exec_cmd("~/.config/theme/menu clipboard")) -- Clipboard history (the setup's, else Walker)
hl.bind("SUPER + Z", hl.dsp.exec_cmd("voxtype record toggle")) -- Dictation start / stop (voxtype)
hl.bind("SUPER + SHIFT + Z", hl.dsp.exec_cmd("voxtype record cancel")) -- Cancel dictation
hl.bind("SUPER + L", hl.dsp.exec_cmd("loginctl lock-session")) -- Lock screen
hl.bind("SUPER + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload")) -- Reload Hyprland
hl.bind("SUPER + SHIFT + Escape", hl.dsp.exec_cmd("kitty --class btop -e btop")) -- System monitor (btop)

-- hyprbars (Disguise's Windows title bars) stays loaded across setup switches: off here, and the setup
-- that wants it (Disguise's setup-binds.lua, below) turns it back on. Only touched while it's loaded.
for _, p in ipairs(hl.get_loaded_plugins and hl.get_loaded_plugins() or {}) do
  if tostring(p.name or ""):lower():find("hyprbars") then
    pcall(hl.config, { plugin = { hyprbars = { enabled = false } } })
  end
end

-- The active setup's own shortcuts, if it has any (setups/<setup>/files/hypr/setup-binds.lua, linked in
-- by `theme setup`), last so they win. Only Disguise has one: Windows 11's keys.
pcall(require, "setup-binds")
