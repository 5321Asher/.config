-- The feel: how windows behave, separate from the setup's look (Style → Feel, or ~/.config/theme/feel).
-- A feel is global: it stays the same across setups and colour themes.
--   hyprland   Hyprland's own behaviour (dwindle tiling, these binds): what this config always did
--   niri       niri's: an endless strip of columns per workspace, workspaces stacked vertically
--              (feels/niri.lua)
-- The active feel's id lives in ~/.local/state/theme/feel. hyprland.lua requires this file before
-- the binds, so a setup's own binds can check FEEL, then requires feels/<FEEL>.lua after them, so
-- the feel's binds win.

local function read_feel()
  local f = io.open(os.getenv("HOME") .. "/.local/state/theme/feel", "r")
  if not f then return "hyprland" end
  local id = (f:read("*l") or ""):gsub("%s+", "")
  f:close()
  if id == "" then return "hyprland" end
  -- only feels that exist: a typo in the state file must not leave the session with no feel
  local p = io.open(os.getenv("HOME") .. "/.config/hypr/feels/" .. id .. ".lua", "r")
  if not p then return "hyprland" end
  p:close()
  return id
end

FEEL = read_feel()
