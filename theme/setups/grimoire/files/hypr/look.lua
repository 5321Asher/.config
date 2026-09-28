-- Grimoire: pages laid on a candlelit desk. A thin rule of gold leaf round every window (a gradient
-- from the gold to its highlight on the focused one, faded tooling on the rest), near-square corners
-- like cut paper, a warm soft shadow under each page, and Quickshell's flourishes on the focused
-- window's corners. Motion is magical but restrained: pages fade in with a slight rise, chapters turn
-- sideways like leaves, nothing bounces.
-- The active setup's look, linked here as ~/.config/hypr/look.lua on a setup switch.
-- Border colours come after, from colors.lua (the theme's activeBorder / activeBorder2 / inactiveBorder).

hl.config({
  general = {
    gaps_in          = 9,
    -- room round the pages for the flourishes (the bar and the spine reserve their own edges)
    gaps_out         = { top = 16, right = 20, bottom = 20, left = 16 },
    border_size      = 2,
    col              = {
      active_border   = "rgba(c9a24aff)",
      inactive_border = "rgba(4a2e22ff)",
    },
    resize_on_border = true,
    allow_tearing    = false,
    layout           = "dwindle",
  },

  decoration = {
    rounding         = 3,
    rounding_power   = 2.0,

    active_opacity   = 1.0,
    inactive_opacity = 0.96,
    dim_inactive     = false,
    dim_special      = 0.45,

    -- a warm shadow, as if the candle were low and to the left
    shadow           = {
      enabled      = true,
      range        = 24,
      render_power = 3,
      offset       = { 4, 8 },
      color        = 0xb00a0403,
      color_inactive = 0x800a0403,
    },

    blur             = {
      enabled           = true,
      size              = 7,
      passes            = 3,
      noise             = 0.04,
      contrast          = 0.95,
      brightness        = 0.8,
      vibrancy          = 0.2,
      popups            = true,
      special           = true,
    },
  },

  animations = {
    enabled = true,
  },
})

-- "arcane": a long, soft ease-out (things settle, they don't snap); "ink": a gentle in-out for fades
hl.curve("arcane", { type = "bezier", points = { { 0.22, 1 }, { 0.36, 1 } } })
hl.curve("ink", { type = "bezier", points = { { 0.45, 0 }, { 0.25, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })

hl.animation({ leaf = "global", enabled = true, speed = 4, bezier = "arcane" })
hl.animation({ leaf = "windows", enabled = true, speed = 4.5, bezier = "arcane" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.5, bezier = "arcane", style = "popin 88%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3, bezier = "ink", style = "popin 92%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4, bezier = "arcane" })
hl.animation({ leaf = "border", enabled = true, speed = 6, bezier = "ink" })
hl.animation({ leaf = "borderangle", enabled = false })
hl.animation({ leaf = "fade", enabled = true, speed = 4, bezier = "ink" })
hl.animation({ leaf = "fadeDim", enabled = true, speed = 5, bezier = "ink" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "arcane", style = "slidefade 12%" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4.5, bezier = "arcane", style = "slidefadevert 10%" })
hl.animation({ leaf = "layers", enabled = true, speed = 3, bezier = "arcane" })
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 5, bezier = "arcane" })

-- Grimoire's panels (namespace grimoire-*): the bar and the spine are tooled leather (a little
-- see-through, blurred behind), and the codex, the whole book and the polkit prompt blur the desk
-- behind them. The summoning circle doesn't: the pages stay readable under it while it's cast.
-- Quickshell does all their motion itself.
hl.layer_rule({
  name         = "grimoire-blur",
  match        = { namespace = "^grimoire-(bar|spine|codex|overview|polkit)$" },
  blur         = true,
  ignore_alpha = 0.2,
})
hl.layer_rule({
  name    = "grimoire-no-anim",
  match   = { namespace = "^grimoire-.*" },
  no_anim = true,
})

-- Brave's New Tab lets the desk show through
hl.window_rule({
  name    = "grimoire-brave-newtab-glass",
  match   = { class = "^brave-browser$", title = "^New (Private )?Tab - Brave$" },
  opacity = "0.6 override 0.6 override",
})
