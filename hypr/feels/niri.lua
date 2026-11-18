-- Feel "niri": niri's scrollable tiling on Hyprland, after niri's default config (keys, numbers,
-- springs). Every workspace is an endless strip of columns; a new window opens as a new column to
-- the right of the focused one and nothing else resizes; the view scrolls just enough to show the
-- focused column. Workspaces are stacked vertically per monitor and are dynamic: there is always
-- an empty one below the last.
--
-- Hyprland's built-in "scrolling" layout does the columns (layoutmsg focus/swapcol/consume/expel/
-- colresize/fit/center); this file sets it up like niri and binds niri's keys. It loads after
-- binds.lua and the setup's setup-binds.lua, takes over the keys it needs (hl.unbind first: two
-- binds on one key would both fire) only where the column way needs it; every other key stays as
-- binds.lua has it. The cheat sheet for these keys: feels/niri.keys.
--
-- Not possible on Hyprland, so not here: tabbed columns (a window group, SUPER + G, is the nearest),
-- per-window heights in a column by preset, "center visible columns".

-- Pushing the pointer into a screen's top-left corner opens the overview, except in setups whose shell
-- has a click corner of its own instead (Netrunner: quickshell/netrunner/utilities/Corner.qml).
-- The setup is read when the config loads; a setup switch reloads it.
local function active_setup()
  local f = io.open(os.getenv("HOME") .. "/.local/state/theme/setup", "r")
  if not f then return "" end
  local s = f:read("l") or ""
  f:close()
  return s
end
local HOT_CORNER = ({ netrunner = true })[active_setup()] == nil

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
    explicit_column_widths   = "0.33333, 0.5, 0.66667, 1.0", -- niri presets + full width (SUPER + R)
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
-- Keys. The feel keeps binds.lua: a function both feels have stays on the same key (SUPER + C closes,
-- SUPER + F fullscreens, SUPER + G groups, SUPER + L locks, SUPER + 1…0 workspaces…). Only these two
-- sets change what they do, so they work on columns:
--   SUPER + arrows          focus: the column left / right, the window up / down in the column; at the
--                           end of the strip, the monitor that way (as Hyprland's focus does)
--   SUPER + SHIFT + arrows  move: the column left / right, the window up / down in its column; at the
--                           end, onto an empty monitor that way (as binds.lua's swap_or_move does)
-- SUPER + CTRL + arrows (resize) already work on columns: width left / right, height up / down.
-- niri-only actions (preset widths, maximize column, workspaces up / down…) are the NIRI.* functions;
-- their keys go in the block at the end of this file.

-- an empty monitor that way, for a window leaving the end of the strip
local function empty_monitor(dir)
  local cur = hl.get_active_monitor()
  if not cur then return nil end
  local cx, cy = cur.x + cur.width / 2, cur.y + cur.height / 2
  for _, m in ipairs(hl.get_monitors()) do
    local mx, my = m.x + m.width / 2, m.y + m.height / 2
    local beside = (dir == "l" and mx < cx) or (dir == "r" and mx > cx)
      or (dir == "u" and my < cy) or (dir == "d" and my > cy)
    if m.id ~= cur.id and beside and (not m.active_workspace or m.active_workspace.is_empty) then
      return m.name
    end
  end
  return nil
end

local function focus_dir(d)
  return function()
    local before = hl.get_active_window()
    hl.dispatch(hl.dsp.layout("focus " .. d))
    local after = hl.get_active_window()
    -- nothing that way on this workspace: the monitor that way, if there is one
    if not before or not after or after.address == before.address then
      hl.dispatch(hl.dsp.focus({ monitor = d }))
    end
  end
end

local function move_dir(d, long)
  return function()
    local w = hl.get_active_window()
    if not w then return end
    local l = w.layout
    local function where()
      local a = hl.get_active_window()
      local al = a and a.layout
      return al and al.column and (al.column.index .. ":" .. tostring(al.index_in_column)) or ""
    end
    local before = where()
    if d == "l" or d == "r" then
      hl.dispatch(hl.dsp.layout("swapcol " .. d))
    elseif l and l.column then
      hl.dispatch(hl.dsp.window.move({ direction = long }))
    end
    if where() == before then
      local mon = empty_monitor(d)
      if mon then hl.dispatch(hl.dsp.window.move({ monitor = mon })) end
    end
  end
end

for _, d in ipairs({ { "left", "l" }, { "right", "r" }, { "up", "u" }, { "down", "d" } }) do
  rebind("SUPER + " .. d[1], focus_dir(d[2]))
  rebind("SUPER + SHIFT + " .. d[1], move_dir(d[2], d[1]))
end

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
  focus = function(d) focus_dir(d)() end, move = function(d, long) move_dir(d, long)() end,
}

------------------------------------------------------------------------------------------------
-- niri-only keys (chosen by the user, 2026-11-09). Free in binds.lua; in Disguise, SUPER + R (Run)
-- gives way to the width presets while this feel is on.
rebind("SUPER + R", msg("colresize +conf"))             -- column width: next preset (⅓ · ½ · ⅔ · full)
rebind("SUPER + ALT + R", msg("colresize -conf"))       -- column width: previous preset
rebind("SUPER + ALT + C", msg("center"))                -- center the column
rebind("SUPER + bracketleft", msg("consume_or_expel prev"))  -- window into the column left (or out)
rebind("SUPER + bracketright", msg("consume_or_expel next")) -- window into the column right (or out)
