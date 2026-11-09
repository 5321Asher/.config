-- ~/.config/elephant/menus/keybinds.lua
-- Shows ~/.config/walker/keybinds.txt — a list you maintain by hand.
-- Format, one per line:   KEYS | what it does      (# = comment)

Name = "keybinds"
NamePretty = "Keybinds"
Icon = "󰌌"
Description = "Keybind cheat sheet"
Parent = "keybindtools"
Cache = false          -- re-read the file every open, so edits show up immediately
Action = "true"        -- selecting a row does nothing
FixedOrder = true
HideFromProviderlist = true

local FILE = os.getenv("HOME") .. "/.config/walker/keybinds.txt"

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

-- the active feel's own keys come first (Style → Feel; ~/.config/hypr/feels/<feel>.keys, same format)
local function feel_keys(entries)
  local s = io.open(os.getenv("HOME") .. "/.local/state/theme/feel", "r")
  if not s then return end
  local feel = (s:read("*l") or ""):gsub("%s+", "")
  s:close()
  local f = feel ~= "" and io.open(os.getenv("HOME") .. "/.config/hypr/feels/" .. feel .. ".keys", "r")
  if not f then return end
  for line in f:lines() do
    local keys, desc = line:match("^([^#|][^|]-)%s*|%s*(.+)$")
    if keys then
      keys, desc = trim(keys), trim(desc)
      table.insert(entries, { Text = desc, Subtext = keys .. "  ·  " .. feel, Value = keys })
    end
  end
  f:close()
end

function GetEntries()
  local entries = {}
  feel_keys(entries)
  local f = io.open(FILE, "r")
  if not f then
    return { { Text = "create " .. FILE, Subtext = "missing", Value = "" } }
  end
  for line in f:lines() do
    local keys, desc = line:match("^([^#|][^|]-)%s*|%s*(.+)$")
    if keys then
      keys, desc = trim(keys), trim(desc)
      table.insert(entries, { Text = desc, Subtext = keys, Value = keys })
    end
  end
  f:close()
  return entries
end
