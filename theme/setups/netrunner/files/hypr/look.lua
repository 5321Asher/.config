-- Netrunner: a cyberdeck. No Hyprland borders (Quickshell's frames layer draws the cut-corner frames,
-- red for the focused window), square corners, translucent glass with blur, hard fast motion.
-- The active setup's look, linked here as ~/.config/hypr/look.lua on a setup switch.
-- Border colours come after, from colors.lua (unused: border_size is 0).

hl.config({
  general = {
    gaps_in          = 8,
    gaps_out         = { top = 12, right = 14, bottom = 14, left = 14 },
    border_size      = 0,
    col              = {
      active_border   = "rgba(ff3a4cee)",
      inactive_border = "rgba(26323caa)",
    },
    resize_on_border = false,
    allow_tearing    = false,
    layout           = "dwindle",
  },

  decoration = {
    rounding         = 0,
    rounding_power   = 2,

    active_opacity   = 1.0,
    inactive_opacity = 0.92,
    dim_inactive     = false,
    -- the deck (special:deck) darkens the desktop behind it
    dim_special      = 0.55,

    shadow           = {
      enabled      = true,
      range        = 14,
      render_power = 3,
      color        = 0xcc000000,
    },

    blur             = {
      enabled           = true,
      size              = 8,
      passes            = 3,
      noise             = 0.03,
      contrast          = 0.9,
      brightness        = 0.7,
      vibrancy          = 0.25,
      popups            = true,
      special           = true,
    },
  },

  animations = {
    enabled = true,
  },
})

-- Hard and fast: windows snap (the frames follow them on each event, so long moves would drift),
-- workspaces cut across, the deck drops in.
hl.curve("snap", { type = "bezier", points = { { 0.2, 0.9 }, { 0.1, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })

hl.animation({ leaf = "global", enabled = true, speed = 1.6, bezier = "snap" })
hl.animation({ leaf = "windows", enabled = true, speed = 1.2, bezier = "snap" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 1.5, bezier = "snap", style = "popin 95%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.0, bezier = "linear", style = "popin 95%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 1.0, bezier = "snap" })
hl.animation({ leaf = "border", enabled = false })
hl.animation({ leaf = "fade", enabled = true, speed = 1.5, bezier = "snap" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1.6, bezier = "snap", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 1.8, bezier = "snap", style = "slidevert" })
hl.animation({ leaf = "layers", enabled = true, speed = 1.5, bezier = "snap" })
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 2, bezier = "snap" })

-- Netrunner's panels (namespace netrunner-*) are translucent: blur what's behind them, and let
-- Quickshell do their motion. The frames layer is all lines: no blur there.
hl.layer_rule({
  name         = "netrunner-blur",
  match        = { namespace = "^netrunner-(bar|deck|rig|exec|messages|menu|polkit|voice|overview)$" },
  blur         = true,
  ignore_alpha = 0.3,
})
hl.layer_rule({
  name    = "netrunner-no-anim",
  match   = { namespace = "^netrunner-.*" },
  no_anim = true,
})

-- The deck: windows opened there tile top-left; its panels fill the right and the bottom
-- (sizes match Theme.deckRight / deckBottom in quickshell/netrunner/theme/Theme.qml).
hl.workspace_rule({ workspace = "special:deck", gaps_out = { top = 12, right = 454, bottom = 314, left = 14 } })

-- Brave's New Tab goes glassy (the skyline shows through, blurred)
hl.window_rule({
  name    = "netrunner-brave-newtab-glass",
  match   = { class = "^brave-browser$", title = "^New (Private )?Tab - Brave$" },
  opacity = "0.55 override 0.55 override",
})
