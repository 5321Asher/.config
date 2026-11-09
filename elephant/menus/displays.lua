-- ~/.config/elephant/menus/displays.lua
-- Display profiles (Style → Display profile): every monitor's resolution, refresh, position, scale,
-- rotation and mirroring under one name. Picking one runs `display menu apply:<id>`
-- (~/.config/theme/display); Hyprland also switches by itself at login and on hotplug.

Name = "displays"
NamePretty = "Display profile"
Icon = "󰍹"
Description = "Monitor layout profiles"
Parent = "style"
Cache = false
FixedOrder = true
HideFromProviderlist = true

local DISPLAY = os.getenv("HOME") .. "/.config/theme/display"
Action = "'" .. DISPLAY .. "' menu %VALUE%"

function GetEntries()
  local entries = {}
  local p = io.popen("'" .. DISPLAY .. "' rows 2>/dev/null")
  if p then
    for line in p:lines() do
      local id, name, summary, active, fits =
        line:match("^([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)$")
      if id then
        local sub = summary .. (fits == "1" and " · fits these screens" or "")
        table.insert(entries, {
          Text = (active == "1" and "● " or "   ") .. name,
          Subtext = active == "1" and ("active · " .. sub) or sub,
          Value = "apply:" .. id,
          Keywords = { id, "display", "monitor", "profile", "layout" },
        })
      end
    end
    p:close()
  end
  table.insert(entries, {
    Text = "   Save current layout…",
    Subtext = "every monitor, resolution, refresh, scale, rotation, position · as a new profile or over one",
    Value = "save",
    Keywords = { "save", "display", "monitor", "profile", "new" },
  })
  table.insert(entries, {
    Text = "   Delete a profile…",
    Subtext = "remove a saved display profile",
    Value = "delete",
    Keywords = { "delete", "remove", "display", "profile" },
  })
  return entries
end
