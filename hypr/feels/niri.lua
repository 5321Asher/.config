-- Feel "niri": niri's scrollable tiling on Hyprland, after niri's default config (keys, numbers,
-- springs). Every workspace is an endless strip of columns; a new window opens as a new column to
-- the right of the focused one and nothing else resizes; the view scrolls just enough to show the
-- focused column. Workspaces are stacked vertically per monitor and are dynamic: there is always
-- an empty one below the last.
--
-- Hyprland's built-in "scrolling" layout does the columns (layoutmsg focus/swapcol/consume/expel/
-- colresize/fit/center); this file sets it up like niri and binds niri's keys. It loads after
-- binds.lua and the setup's setup-binds.lua, takes over the keys it needs (hl.unbind first: two
-- binds on one key would both fire) and leaves the rest (apps, clipboard, capture, dictation,
-- scratchpad, menus) as they are. The cheat sheet for these keys: feels/niri.keys.
--
-- Not possible on Hyprland, so not here: tabbed columns (SUPER + W makes a window group instead),
-- per-window heights in a column by preset (SUPER + SHIFT + R), "center visible columns".

local HOT_CORNER = true -- pushing the pointer into a screen's top-left corner opens the overview

------------------------------------------------------------------------------------------------
-- Layout and behaviour
hl.config({
  general = {
    layout = "scrolling",
    -- at the first / last column, focus stays put (niri's focus-column-left doesn't leave the monitor)
    no_focus_fallback = true,
  },
  scrolling = {
    column_width             = 0.5,                    -- niri: default-column-width proportion 0.5
    explicit_column_widths   = "0.33333, 0.5, 0.66667", -- niri: preset-column-widths (SUPER + R)
    focus_fit_method         = 1,                      -- scroll just enough (center-focused-column "never")
    follow_focus             = true,
    fullscreen_on_one_column = false,                  -- a lone window is still half the screen
    direction                = "right",
    wrap_focus               = false,
    wrap_swapcol             = false,
  },
  -- niri doesn't focus what the pointer hovers (click to focus), and doesn't warp the pointer
  input = { follow_mouse = 2 },
  cursor = { no_warps = true },
})

------------------------------------------------------------------------------------------------
-- Motion: niri's default springs (critically damped: damping-ratio 1.0), ease-out-expo opening,
-- ease-out-quad closing, workspaces sliding vertically. Hyprland springs run on real time, so the
-- numbers are niri's own (dampening = 2 * sqrt(stiffness) for ratio 1.0).
hl.curve("niriView", { type = "spring", mass = 1, stiffness = 800, dampening = 56.57 })  -- view, windows, resize
hl.curve("niriWorkspace", { type = "spring", mass = 1, stiffness = 1000, dampening = 63.25 })
hl.curve("niriOutExpo", { type = "bezier", points = { { 0.16, 1 }, { 0.3, 1 } } })
hl.curve("niriOutQuad", { type = "bezier", points = { { 0.25, 0.46 }, { 0.45, 0.94 } } })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 3, spring = "niriView" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 1.5, bezier = "niriOutExpo", style = "popin 80%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.5, bezier = "niriOutQuad", style = "popin 80%" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 3, spring = "niriWorkspace", style = "slidevert" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 3, spring = "niriWorkspace", style = "slidevert" })

------------------------------------------------------------------------------------------------
-- Touchpad: three fingers sideways scroll the strip, up/down change workspace; four fingers up or
-- down open the overview (niri's gestures). hyprland.lua's 3-finger workspace swipe goes first.
pcall(hl.gesture, { fingers = 3, direction = "horizontal", action = "unset" })
hl.gesture({ fingers = 3, direction = "horizontal", action = "scroll_move" })
hl.gesture({ fingers = 3, direction = "vertical", action = "workspace" })
hl.gesture({ fingers = 4, direction = "vertical", action = { finish = function()
  hl.exec_cmd("qs ipc call overview toggle")
end } })

------------------------------------------------------------------------------------------------
-- Helpers

local function rebind(keys, action, opts)
  pcall(hl.unbind, keys)
  hl.bind(keys, action, opts)
end

local function msg(m)
  return function() hl.dispatch(hl.dsp.layout(m)) end
end

-- the open workspaces on the focused monitor, top to bottom (= by id), and where we are in them
local function stack()
  local mon = hl.get_active_monitor()
  if not mon or not mon.active_workspace then return {}, nil, nil end
  local list = {}
  for _, ws in ipairs(hl.get_workspaces()) do
    if not ws.special and ws.id > 0 and ws.monitor and ws.monitor.id == mon.id then
      table.insert(list, ws)
    end
  end
  table.sort(list, function(a, b) return a.id < b.id end)
  local cur = mon.active_workspace
  for i, ws in ipairs(list) do
    if ws.id == cur.id then return list, i, cur end
  end
  return list, nil, cur
end

-- the workspace below: the next one on this monitor, else a new empty one (unless this one is
-- already the empty one at the bottom). Above: the previous one, never wrapping.
local function below()
  local list, i, cur = stack()
  if not cur then return nil end
  if i and list[i + 1] then return list[i + 1].id end
  if cur.is_empty then return nil end
  return "emptynm"
end
local function above()
  local list, i = stack()
  if i and i > 1 then return list[i - 1].id end
  return nil
end

local function focus_ws(pick)
  return function()
    local id = pick()
    if id then hl.dispatch(hl.dsp.focus({ workspace = id })) end
  end
end
local function move_to_ws(pick)
  return function()
    local id = pick()
    if id then hl.dispatch(hl.dsp.window.move({ workspace = id })) end
  end
end

-- niri's move-workspace-down/up: the two workspaces trade places (Hyprland can't reorder
-- workspaces, so their windows trade instead, left to right so the columns keep their order)
local function swap_ws(pick)
  return function()
    local _, _, cur = stack()
    local other = pick()
    if not cur or not other or other == "emptynm" then return end
    local a, b = {}, {}
    for _, w in ipairs(hl.get_windows()) do
      if w.workspace and w.workspace.id == cur.id then table.insert(a, w) end
      if w.workspace and w.workspace.id == other then table.insert(b, w) end
    end
    local byx = function(p, q) return p.at.x < q.at.x end
    table.sort(a, byx); table.sort(b, byx)
    for _, w in ipairs(a) do hl.dispatch(hl.dsp.window.move({ workspace = other, follow = false, window = "address:" .. w.address })) end
    for _, w in ipairs(b) do hl.dispatch(hl.dsp.window.move({ workspace = cur.id, follow = false, window = "address:" .. w.address })) end
    hl.dispatch(hl.dsp.focus({ workspace = other }))
  end
end

-- the tiled windows on this workspace with their column index
local function columns()
  local mon = hl.get_active_monitor()
  local cols = {}
  if not mon or not mon.active_workspace then return cols end
  for _, w in ipairs(hl.get_windows()) do
    local l = w.workspace and w.workspace.id == mon.active_workspace.id and not w.floating and w.layout
    if l and l.column and l.column.index then table.insert(cols, { win = w, idx = l.column.index }) end
  end
  return cols
end

local function focus_end(last)
  return function()
    local best
    for _, c in ipairs(columns()) do
      if not best or (last and c.idx > best.idx) or (not last and c.idx < best.idx) then best = c end
    end
    if best then hl.dispatch(hl.dsp.focus({ window = "address:" .. best.win.address })) end
  end
end

local function move_col_to_end(last)
  return function()
    local w = hl.get_active_window()
    local l = w and w.layout
    if not (l and l.column and l.column.index) then return end
    local n = 0
    for _, c in ipairs(columns()) do n = math.max(n, c.idx) end
    local steps = last and (n - l.column.index) or l.column.index
    for _ = 1, steps do hl.dispatch(hl.dsp.layout(last and "swapcol r" or "swapcol l")) end
  end
end

-- niri's maximize-column: the column takes the whole width, and goes back to its width again
local widths = {}
local function maximize_column()
  local w = hl.get_active_window()
  local l = w and w.layout
  if not (l and l.column and l.column.width) then return end
  if l.column.width >= 0.999 then
    hl.dispatch(hl.dsp.layout("colresize " .. (widths[w.address] or 0.5)))
    widths[w.address] = nil
  else
    widths[w.address] = l.column.width
    hl.dispatch(hl.dsp.layout("colresize 1.0"))
  end
end

-- niri's set-window-height ±10%: the focused window's share of its column
local function window_height(sign)
  return function()
    local mon = hl.get_active_monitor()
    if not mon then return end
    hl.dispatch(hl.dsp.window.resize({ x = 0, y = sign * math.floor(mon.height * 0.1), relative = true }))
  end
end

-- niri's switch-focus-between-floating-and-tiling
local function floating_or_tiling()
  local mon = hl.get_active_monitor()
  local act = hl.get_active_window()
  if not mon or not mon.active_workspace then return end
  local want_floating = not (act and act.floating)
  local best
  for _, w in ipairs(hl.get_windows()) do
    if w.workspace and w.workspace.id == mon.active_workspace.id and w.floating == want_floating then
      if not best or (w.focus_history_id or 99) < (best.focus_history_id or 99) then best = w end
    end
  end
  if best then hl.dispatch(hl.dsp.focus({ window = "address:" .. best.address })) end
end

-- the mouse wheel changes workspace at most every 150 ms (niri: cooldown-ms 150), so a free-spinning
-- or high-resolution wheel doesn't fly through all of them
local wheel_ready = true
local function wheel(fn)
  return function()
    if not wheel_ready then return end
    wheel_ready = false
    hl.timer(function() wheel_ready = true end, { timeout = 150, type = "oneshot" })
    fn()
  end
end

------------------------------------------------------------------------------------------------
-- Keys: niri's defaults (Mod = SUPER). Arrows and H J K L do the same.

local dirs = {
  { "left", "H", "l", "left" }, { "right", "L", "r", "right" },
  { "up", "K", "u", "up" }, { "down", "J", "d", "down" },
}
for _, d in ipairs(dirs) do
  local arrow, vim, short, long = d[1], d[2], d[3], d[4]
  for _, key in ipairs({ arrow, vim }) do
    -- focus: columns left/right, windows in the column up/down
    rebind("SUPER + " .. key, msg("focus " .. short))
    -- move: the column left/right, the window up/down in its column
    if short == "l" or short == "r" then
      rebind("SUPER + CTRL + " .. key, msg("swapcol " .. short))
    else
      rebind("SUPER + CTRL + " .. key, hl.dsp.window.move({ direction = long }))
    end
    -- monitors
    rebind("SUPER + SHIFT + " .. key, hl.dsp.focus({ monitor = short }))
    rebind("SUPER + SHIFT + CTRL + " .. key, hl.dsp.window.move({ monitor = short }))
  end
end

-- first / last column
rebind("SUPER + Home", focus_end(false))
rebind("SUPER + End", focus_end(true))
rebind("SUPER + CTRL + Home", move_col_to_end(false))
rebind("SUPER + CTRL + End", move_col_to_end(true))

-- workspaces, stacked vertically
for _, k in ipairs({ "Page_Down", "U" }) do
  rebind("SUPER + " .. k, focus_ws(below))
  rebind("SUPER + CTRL + " .. k, move_to_ws(below))
  rebind("SUPER + SHIFT + " .. k, swap_ws(below))
end
for _, k in ipairs({ "Page_Up", "I" }) do
  rebind("SUPER + " .. k, focus_ws(above))
  rebind("SUPER + CTRL + " .. k, move_to_ws(above))
  rebind("SUPER + SHIFT + " .. k, swap_ws(above))
end
for i = 1, 9 do
  rebind("SUPER + CTRL + " .. i, hl.dsp.window.move({ workspace = i })) -- move column to workspace N
end
rebind("SUPER + Tab", hl.dsp.focus({ workspace = "previous" }))

-- the mouse wheel: workspaces up/down, columns sideways (and with SHIFT)
rebind("SUPER + mouse_down", wheel(focus_ws(below)))
rebind("SUPER + mouse_up", wheel(focus_ws(above)))
rebind("SUPER + CTRL + mouse_down", wheel(move_to_ws(below)))
rebind("SUPER + CTRL + mouse_up", wheel(move_to_ws(above)))
rebind("SUPER + mouse_right", msg("focus r"))
rebind("SUPER + mouse_left", msg("focus l"))
rebind("SUPER + SHIFT + mouse_down", msg("focus r"))
rebind("SUPER + SHIFT + mouse_up", msg("focus l"))
rebind("SUPER + CTRL + SHIFT + mouse_down", msg("swapcol r"))
rebind("SUPER + CTRL + SHIFT + mouse_up", msg("swapcol l"))

-- columns: take windows in, push them out
rebind("SUPER + bracketleft", msg("consume_or_expel prev"))
rebind("SUPER + bracketright", msg("consume_or_expel next"))
rebind("SUPER + comma", msg("consume"))
rebind("SUPER + period", msg("expel"))

-- sizes
rebind("SUPER + R", msg("colresize +conf"))
rebind("SUPER + SHIFT + R", msg("colresize -conf"))
rebind("SUPER + F", maximize_column)
rebind("SUPER + SHIFT + F", hl.dsp.window.fullscreen())
rebind("SUPER + CTRL + F", msg("fit expand"))
rebind("SUPER + C", msg("center"))
rebind("SUPER + minus", msg("colresize -0.1"), { repeating = true })
rebind("SUPER + equal", msg("colresize +0.1"), { repeating = true })
rebind("SUPER + SHIFT + minus", window_height(-1), { repeating = true })
rebind("SUPER + SHIFT + equal", window_height(1), { repeating = true })

-- windows
rebind("SUPER + Q", hl.dsp.window.close())
rebind("SUPER + SHIFT + V", floating_or_tiling)
rebind("SUPER + W", hl.dsp.group.toggle()) -- niri's tabbed column, as a Hyprland group
rebind("SUPER + T", hl.dsp.exec_cmd("gtk-launch kitty"))
rebind("SUPER + O", hl.dsp.exec_cmd("qs ipc call overview toggle"))
rebind("SUPER + SHIFT + slash", hl.dsp.exec_cmd("walker -m menus:keybinds"))

-- what niri's keys pushed aside (SUPER + L locked, SUPER + K picked a wallpaper): niri's own lock key
rebind("SUPER + ALT + L", hl.dsp.exec_cmd("loginctl lock-session"))
rebind("SUPER + ALT + W", hl.dsp.exec_cmd("gtk-launch skwd-wall-v2"))
-- SUPER + I toggled the dwindle split, SUPER + P pseudo-tiled: both meaningless in columns
pcall(hl.unbind, "SUPER + P")

------------------------------------------------------------------------------------------------
-- Hot corner: niri opens the overview when the pointer is pushed into the top-left corner.
if HOT_CORNER then
  local inside = false
  hl.timer(function()
    local pos = hl.get_cursor_pos()
    if not pos then return end
    local hit = false
    for _, m in ipairs(hl.get_monitors()) do
      if pos.x <= m.x + 0.5 and pos.y <= m.y + 0.5 and pos.x >= m.x and pos.y >= m.y then hit = true end
    end
    if hit and not inside then hl.exec_cmd("qs ipc call overview toggle") end
    inside = hit
  end, { timeout = 50, type = "repeat" })
end

-- The same actions for scripts and testing: hyprctl eval 'NIRI.focus_last()'
NIRI = {
  focus_first = focus_end(false), focus_last = focus_end(true),
  move_first = move_col_to_end(false), move_last = move_col_to_end(true),
  workspace_down = focus_ws(below), workspace_up = focus_ws(above),
  move_down = move_to_ws(below), move_up = move_to_ws(above),
  swap_down = swap_ws(below), swap_up = swap_ws(above),
  maximize_column = maximize_column, floating_or_tiling = floating_or_tiling,
}
