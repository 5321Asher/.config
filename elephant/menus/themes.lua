-- ~/.config/elephant/menus/themes.lua
-- Colour theme picker (Style → Theme): the active setup's themes. Picking one runs `theme set <id>`,
-- which recolours every app and swaps skwd-wall's folder to that theme's wallpapers.

Name = "themes"
NamePretty = "Theme"
Icon = "󰏘"
Description = "Colour theme"
Parent = "style"
Cache = false          -- re-read every open, so new/edited themes show up immediately
FixedOrder = true
HideFromProviderlist = true

local THEME = os.getenv("HOME") .. "/.config/theme/theme"
Action = "'" .. THEME .. "' set %VALUE%"

function GetEntries()
  local entries = {}
  local p = io.popen("'" .. THEME .. "' rows themes 2>/dev/null")
  if not p then return entries end
  for line in p:lines() do
    local id, name, accent, n, active = line:match("^([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)$")
    if id then
      n = tonumber(n) or 0
      local sub = (n == 0 and "setup's wallpapers" or (n .. " wallpaper" .. (n == 1 and "" or "s"))) .. "  " .. accent
      table.insert(entries, {
        Text = (active == "1" and "● " or "   ") .. name,
        Subtext = active == "1" and ("active · " .. sub) or sub,
        Value = id,
        Keywords = { id, "theme", "colour", "color" },
      })
    end
  end
  p:close()
  return entries
end
