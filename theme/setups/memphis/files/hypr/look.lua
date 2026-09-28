-- Memphis: 1998. Square corners, no shadows, no blur, no transparency; a thick frame round every
-- window in its title-bar gradient (navy to blue while active, greys while not: colors.lua sets
-- them from the scheme). A little of the desktop colour shows between windows. Motion is short and
-- linear, like 98's "zooming rectangles" when a window opened.
-- The active setup's look, linked here as ~/.config/hypr/look.lua on a setup switch.
-- Border colours come after, from colors.lua.

hl.config({
  general = {
    gaps_in          = 3,
    gaps_out         = { top = 6, right = 6, bottom = 6, left = 6 },

    border_size      = 3,

    col              = {
      active_border   = { colors = { "rgba(000080ff)", "rgba(1084d0ff)" }, angle = 0 },
      inactive_border = "rgba(808080ff)",
    },

    resize_on_border = true,
    allow_tearing    = false,
    layout           = "dwindle",
  },

  decoration = {
    rounding         = 0,
    rounding_power   = 2,

    active_opacity   = 1.0,
    inactive_opacity = 1.0,
    dim_inactive     = false,

    shadow           = {
      enabled = false,
    },

    blur             = {
      enabled = false,
    },
  },

  animations = {
    enabled = true,
  },
})

hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("outQuad", { type = "bezier", points = { { 0.25, 0.46 }, { 0.45, 0.94 } } })

-- speed is in 100 ms steps: everything well under a quarter of a second
hl.animation({ leaf = "global", enabled = true, speed = 1.5, bezier = "linear" })
hl.animation({ leaf = "border", enabled = false })
hl.animation({ leaf = "windows", enabled = true, speed = 1.5, bezier = "outQuad" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 1.8, bezier = "outQuad", style = "popin 20%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.2, bezier = "linear", style = "popin 20%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 1.5, bezier = "outQuad" })
hl.animation({ leaf = "fade", enabled = false })
hl.animation({ leaf = "layers", enabled = false })
hl.animation({ leaf = "workspaces", enabled = false })
hl.animation({ leaf = "specialWorkspace", enabled = false })
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 2, bezier = "linear" })

-- Quickshell draws Memphis's menus and windows itself (menus slide out as 98's did); no fades here
hl.layer_rule({
  name    = "memphis-no-anim",
  match   = { namespace = "^memphis-.*" },
  no_anim = true,
})
