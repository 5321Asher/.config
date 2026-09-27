-- Observatory: brass instruments in a dark dome. Wide gaps (windows float in the sky), fine brass
-- borders, slightly rounded like machined plates, smooth mechanical motion (OutCubic, 250-400 ms).
-- The active setup's look, linked here as ~/.config/hypr/look.lua on a setup switch.
-- Border colours come after, from colors.lua.

hl.config({
  general = {
    gaps_in          = 7,
    gaps_out         = { top = 22, right = 22, bottom = 22, left = 22 },

    border_size      = 1,

    col              = {
      active_border   = "rgba(c9a45cee)",
      inactive_border = "rgba(2a3246aa)",
    },

    resize_on_border = false,
    allow_tearing    = false,
    layout           = "dwindle",
  },

  decoration = {
    rounding         = 6,
    rounding_power   = 2,

    active_opacity   = 1.0,
    inactive_opacity = 0.86,
    dim_inactive     = true,
    dim_strength     = 0.08,

    shadow           = {
      enabled      = true,
      range        = 18,
      render_power = 3,
      offset       = "0 6",
      color        = 0xaa000000,
    },

    blur             = {
      enabled           = true,
      size              = 6,
      passes            = 3,
      noise             = 0.02,
      contrast          = 0.9,
      brightness        = 0.8,
      vibrancy          = 0.2,
      popups            = true,
    },
  },

  animations = {
    enabled = true,
  },
})

-- Mechanical: fast out, no bounce
hl.curve("outCubic", { type = "bezier", points = { { 0.33, 1 }, { 0.68, 1 } } })
hl.curve("inCubic", { type = "bezier", points = { { 0.32, 0 }, { 0.67, 0 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })

-- speed is in 100 ms steps
hl.animation({ leaf = "global", enabled = true, speed = 3.2, bezier = "outCubic" })
hl.animation({ leaf = "border", enabled = true, speed = 4, bezier = "outCubic" })
hl.animation({ leaf = "windows", enabled = true, speed = 3.2, bezier = "outCubic" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 3.5, bezier = "outCubic", style = "popin 92%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2.5, bezier = "inCubic", style = "popin 92%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 3.2, bezier = "outCubic" })
hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "outCubic" })
hl.animation({ leaf = "layers", enabled = true, speed = 3, bezier = "outCubic" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 3, bezier = "outCubic", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 2.5, bezier = "inCubic", style = "fade" })
-- Workspaces slide like a telescope dome rotating
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "outCubic", style = "slidefade 12%" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 3.5, bezier = "outCubic", style = "slidefadevert 20%" })
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 4, bezier = "outCubic" })

-- Quickshell's panels (namespace observatory-*) are drawn ~85% opaque; blur what's behind them.
-- ignore_alpha keeps the fully transparent parts of each surface unblurred.
hl.layer_rule({
  name         = "observatory-blur",
  match        = { namespace = "^observatory-.*" },
  blur         = true,
  ignore_alpha = 0.25,
})
-- Quickshell animates its own panels; Hyprland's layer fade would double it
hl.layer_rule({
  name    = "observatory-no-anim",
  match   = { namespace = "^observatory-.*" },
  no_anim = true,
})

-- Brave goes nearly clear (20%) while a New Tab is showing, with no blur (Observatory's heavy blur
-- would smear the star chart into haze behind it). The rule follows title changes.
hl.window_rule({
  name    = "observatory-brave-newtab-clear",
  match   = { class = "^brave-browser$", title = "^New (Private )?Tab - Brave$" },
  no_blur = true,
  opacity = "0.2 override 0.2 override",
})
