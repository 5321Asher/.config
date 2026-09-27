-- ~/.config/elephant/menus/setups.lua
-- Setup picker (Style → Setup). A setup is a whole desktop (shell, launcher, look, fonts, its own
-- themes); picking one runs `theme setup <id>`, which comes back on that setup's last theme.

Name = "setups"
NamePretty = "Setup"
Icon = "󰕮"
Description = "Desktop setup"
Parent = "style"
Cache = false
FixedOrder = true
HideFromProviderlist = true

local THEME = os.getenv("HOME") .. "/.config/theme/theme"
Action = "'" .. THEME .. "' setup %VALUE%"

function GetEntries()
  local entries = {}
  local p = io.popen("'" .. THEME .. "' rows setups 2>/dev/null")
  if not p then return entries end
  for line in p:lines() do
    local id, name, desc, n, theme, active =
      line:match("^([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)$")
    if id then
      local sub = desc .. "  ·  " .. n .. " theme" .. (n == "1" and "" or "s") .. " · " .. theme
      table.insert(entries, {
        Text = (active == "1" and "● " or "   ") .. name,
        Subtext = active == "1" and ("active · " .. sub) or sub,
        Value = id,
        Keywords = { id, "setup", "desktop", "rice", "shell" },
      })
    end
  end
  p:close()
  return entries
end
