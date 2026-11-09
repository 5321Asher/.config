-- ~/.config/elephant/menus/feels.lua
-- Feel picker (Style → Feel): how windows behave, the same in every setup and theme. Hyprland's own
-- tiling, or niri's scrolling columns. Picking one runs `feel set <id>` (~/.config/theme/feel), which
-- reloads Hyprland; windows re-tile where they are.

Name = "feels"
NamePretty = "Feel"
Icon = "󰕴"
Description = "Window behaviour"
Parent = "style"
Cache = false
FixedOrder = true
HideFromProviderlist = true

local FEEL = os.getenv("HOME") .. "/.config/theme/feel"
Action = "'" .. FEEL .. "' set %VALUE%"

function GetEntries()
  local entries = {}
  local p = io.popen("'" .. FEEL .. "' rows 2>/dev/null")
  if not p then return entries end
  for line in p:lines() do
    local id, name, desc, active = line:match("^([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)$")
    if id then
      table.insert(entries, {
        Text = (active == "1" and "● " or "   ") .. name,
        Subtext = active == "1" and ("active · " .. desc) or desc,
        Value = id,
        Keywords = { id, "feel", "behaviour", "behavior", "layout", "tiling", "scrolling", "columns" },
      })
    end
  end
  p:close()
  return entries
end
