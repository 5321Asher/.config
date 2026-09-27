-- ~/.config/elephant/menus/themes.lua
-- Colour theme picker (Style → Theme). Lists ~/.config/theme/themes/*.toml; picking one runs
-- `theme set <id>`, which recolours every app and swaps skwd-wall's folder to that theme's wallpapers.

Name = "themes"
NamePretty = "Theme"
Icon = "󰏘"
Description = "Colour theme"
Parent = "style"
Cache = false          -- re-read every open, so new/edited themes show up immediately
FixedOrder = true
HideFromProviderlist = true

local HOME = os.getenv("HOME")
local THEME = HOME .. "/.config/theme/theme"
Action = "'" .. THEME .. "' set %VALUE%"

local function read(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return s
end

-- wallpapers assigned to a theme = files in its folder
local function count(dir)
  local p = io.popen("find '" .. dir .. "' -type f 2>/dev/null | wc -l")
  if not p then return 0 end
  local n = tonumber(p:read("*a")) or 0
  p:close()
  return n
end

function GetEntries()
  local state = read(HOME .. "/.local/state/theme/state.json") or ""
  local current = state:match('"current"%s*:%s*"([^"]+)"') or "tokyo-night"

  local entries = {}
  local p = io.popen("ls '" .. HOME .. "/.config/theme/themes'")
  if not p then return entries end
  for file in p:lines() do
    local id = file:match("^(.+)%.toml$")
    if id then
      local text = read(HOME .. "/.config/theme/themes/" .. file) or ""
      local name = text:match('\nname%s*=%s*"([^"]+)"') or text:match('^name%s*=%s*"([^"]+)"') or id
      local accent = text:match('\naccent%s*=%s*"(#%x+)"') or ""
      local n = count(HOME .. "/Pictures/Wallpaper-Themes/" .. id)
      local sub = n .. " wallpaper" .. (n == 1 and "" or "s") .. "  " .. accent
      table.insert(entries, {
        Text = (id == current and "● " or "   ") .. name,
        Subtext = id == current and ("active · " .. sub) or sub,
        Value = id,
        Keywords = { id, "theme", "colour", "color" },
      })
    end
  end
  p:close()
  return entries
end
