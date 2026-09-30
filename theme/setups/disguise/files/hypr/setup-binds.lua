-- Disguise: Windows 11's keyboard shortcuts, on top of the shared binds (hypr/binds.lua requires this
-- last, so these win). Linked as ~/.config/hypr/setup-binds.lua while Disguise is the setup; the other
-- setups have none and keep the shared binds as they are.
--
-- Where Windows and the shared binds disagree, Windows wins here: Win alone opens Start, Win + D shows
-- the desktop (not the scratchpad), Win + 1…9 open the taskbar's apps (desktops move to Win + Ctrl +
-- ←/→ as on Windows), Win + C / Win + X / Win + I / Win + N do what they do on Windows.

local function qs(args) return hl.dsp.exec_cmd("qs ipc call " .. args) end
local function rebind(keys, dispatcher, opts)
  pcall(hl.unbind, keys)
  if opts then hl.bind(keys, dispatcher, opts) else hl.bind(keys, dispatcher) end
end

-- Start, Search, the flyouts
rebind("SUPER + Super_L", qs("start toggle"), { release = true })       -- Win on its own: Start
rebind("SUPER + S", qs("search toggle"))                                 -- Search
rebind("SUPER + Q", qs("search toggle"))
rebind("SUPER + A", qs("flyout toggle quick"))                           -- Quick Settings
rebind("SUPER + N", qs("flyout toggle notif"))                           -- Notification centre + calendar
rebind("SUPER + W", qs("flyout toggle widgets"))                         -- Widgets
rebind("SUPER + X", qs("winx open"))                                     -- the Quick Link menu
rebind("SUPER + I", qs("settings open home"))                            -- Settings
rebind("SUPER + P", qs("settings open display"))                         -- Project (display settings)
rebind("SUPER + R", hl.dsp.exec_cmd("~/.config/theme/menu run"))         -- Run
rebind("SUPER + period", hl.dsp.exec_cmd("~/.config/theme/menu emoji"))  -- emoji panel
rebind("SUPER + semicolon", hl.dsp.exec_cmd("~/.config/theme/menu emoji"))
rebind("SUPER + H", hl.dsp.exec_cmd("voxtype record toggle"))            -- Voice typing
rebind("SUPER + E", hl.dsp.exec_cmd("thunar"))                           -- File Explorer
rebind("CTRL + SHIFT + Escape", qs("settings open performance"))         -- Task Manager

-- Windows and desktops
rebind("SUPER + D", qs("desktop toggle"))                                -- Show desktop
rebind("SUPER + M", qs("desktop minimizeAll"))                           -- Minimise all
rebind("SUPER + Tab", qs("overview toggle"))                             -- Task View
rebind("ALT + Tab", qs("alttab next"))                                    -- the Alt + Tab switcher
rebind("ALT + SHIFT + Tab", qs("alttab prev"))
rebind("ALT + Alt_L", qs("alttab commit"), { release = true })           -- letting go of Alt switches
rebind("ALT + F4", hl.dsp.window.close())                                -- close the window
rebind("SUPER + C", hl.dsp.exec_cmd("gtk-launch webapp-claude"))         -- Copilot (here: Claude)
local caption = "~/.config/quickshell/disguise/scripts/caption.sh --active "
rebind("SUPER + up", hl.dsp.exec_cmd(caption .. "snap top"))              -- Maximise
rebind("SUPER + down", hl.dsp.exec_cmd(caption .. "down"))                -- Restore down, then minimise
rebind("SUPER + left", hl.dsp.exec_cmd(caption .. "snap left"))           -- Snap to the left half
rebind("SUPER + right", hl.dsp.exec_cmd(caption .. "snap right"))         -- Snap to the right half
rebind("SUPER + CTRL + left", hl.dsp.focus({ workspace = "r-1" }))       -- previous desktop
rebind("SUPER + CTRL + right", hl.dsp.focus({ workspace = "r+1" }))      -- next desktop
rebind("SUPER + CTRL + D", hl.dsp.focus({ workspace = "emptynm" }))      -- new desktop
for i = 1, 9 do
  rebind("SUPER + " .. i, qs("taskbar activate " .. i))                  -- the taskbar's n-th app
end
rebind("SUPER + 0", qs("taskbar activate 10"))

-- Screenshots: Print Screen opens the snip, Win + Print saves the whole screen
rebind("Print", qs("capture screenshot region"))
rebind("SUPER + Print", qs("capture screenshot screen"))

-- ------------------------------------------------------------------------------------------------
-- Title bars: Windows 11's caption (title on the left, minimise / maximise / close on the right) from
-- hyprbars, built with Disguise's patch (setups/disguise/hyprbars-windows.patch: square full-height
-- buttons that light on hover, close in red, Segoe Fluent Icons) into ~/.local/lib/hyprland/. The
-- plugin is loaded by ~/.config/theme/titlebars.sh (at Hyprland's start and on a setup switch), never
-- from here: its init reloads the config, so loading it here recursed until Hyprland crashed. This only
-- styles it, and does nothing when it isn't loaded. Colours come from the theme (THEME_PALETTE in
-- colors.lua; setup.toml [hyprland] titlebars = true makes a theme switch reload so they follow).
local loaded = false
for _, p in ipairs(hl.get_loaded_plugins and hl.get_loaded_plugins() or {}) do
  if tostring(p.name or ""):lower():find("hyprbars") then loaded = true end
end
local P = THEME_PALETTE or {}
local dark = P.appearance == "dark"
local function rgba(hex, a) return "rgba(" .. (hex or "#f3f3f3"):gsub("#", "") .. (a or "ff") .. ")" end
if loaded then pcall(hl.config, { plugin = { hyprbars = {
  enabled                    = true,
  bar_height                 = 32,
  bar_color                  = rgba(P.mica),
  ["col.text"]               = rgba(P.text),
  bar_text_font              = "Segoe UI Variable Static Text",
  bar_text_size              = 11,
  bar_text_align             = "left",
  bar_padding                = 0,
  bar_button_padding         = 0,
  bar_part_of_window         = true,
  bar_precedence_over_border = true,
  on_double_click            = "~/.config/quickshell/disguise/scripts/caption.sh max",
} } }) end
-- Settings (Quickshell's window) draws its own caption: no hyprbars bar on it
if loaded then pcall(hl.window_rule, {
  name  = "disguise-settings-nobar",
  match = { class = "^org.quickshell$", title = "^Settings$" },
  ["hyprbars:no_bar"] = true,
}) end
if loaded and hl.plugin.hyprbars and hl.plugin.hyprbars.add_button then
  local hover = dark and "rgba(ffffff14)" or "rgba(0000000f)"
  local fg = rgba(P.text)
  -- right to left: close, maximise, minimise (46 px each, as on Windows), on the window whose bar was
  -- clicked (scripts/caption.sh; maximise toggles with a floating "restored down" window)
  local caption = "~/.config/quickshell/disguise/scripts/caption.sh "
  hl.plugin.hyprbars.add_button({ bg_color = "rgba(c42b1cff)", fg_color = fg, size = 46, icon = "\u{E8BB}",
                                  action = caption .. "close" })
  hl.plugin.hyprbars.add_button({ bg_color = hover, fg_color = fg, size = 46, icon = "\u{E922}",
                                  action = caption .. "max" })
  hl.plugin.hyprbars.add_button({ bg_color = hover, fg_color = fg, size = 46, icon = "\u{E921}",
                                  action = caption .. "min" })
end


-- ------------------------------------------------------------------------------------------------
-- Windows' window behaviour: every window floats (no tiling), opening centred at a normal window size;
-- the title bar moves it, its edges resize it, dropping it on a screen edge snaps it (hyprbars patch),
-- the caption buttons and Win + arrows maximise / restore / snap / minimise (scripts/caption.sh).
-- Focus follows clicks, not the pointer (scrolling an inactive window still works, as on Windows).
hl.config({ input = { follow_mouse = 2 } })
-- Windows has no window groups: a new window never joins the focused window's tab group (Settings
-- opened over a grouped Brave came up inside its group, under a tab bar)
hl.config({ group = { auto_group = false } })
-- a maximised window (caption.sh tags it disguise-max) has square corners, as on Windows
hl.window_rule({
  name     = "disguise-maximised",
  match    = { tag = "disguise-max" },
  rounding = 0,
})
hl.window_rule({
  name   = "disguise-windows-float",
  match  = { class = ".*" },
  float  = true,
  size   = "monitor_w*0.62 monitor_h*0.7",
  center = true,
})
