-- Glyph: after Nothing OS. Rounded windows (20) with a 1 px border, white on the focused window and a
-- dark grey on the rest (palette: activeBorder / inactiveBorder), a faint white glow for a shadow,
-- quick soft motion: the reference's (Shykid002/Nothing-rice) emphasized curves.
-- The active setup's look, linked here as ~/.config/hypr/look.lua on a setup switch.
-- Border colours come after, from colors.lua.

hl.config({
  general = {
    gaps_in          = 7,
    gaps_out         = { top = 14, right = 14, bottom = 14, left = 14 },
    border_size      = 1,
    col              = {
      active_border   = "rgba(f2f2f2ff)",
      inactive_border = "rgba(2a2a2aff)",
    },
    resize_on_border = false,
    allow_tearing    = false,
    layout           = "dwindle",
  },

  decoration = {
    rounding         = 20,
    rounding_power   = 2.0,

    active_opacity   = 1.0,
    inactive_opacity = 1.0,
    dim_inactive     = false,
    dim_special      = 0.5,

    -- a whisper of white light round the focused window (light theme: theme/writers keeps this;
    -- it reads as a soft shadow on the pale grey)
    shadow           = {
      enabled        = true,
      range          = 18,
      render_power   = 3,
      color          = 0x1af2f2f2,
      color_inactive = 0x00000000,
    },

    blur             = {
      enabled           = true,
      size              = 6,
      passes            = 3,
      noise             = 0.0,
      contrast          = 1.0,
      brightness        = 0.8,
      vibrancy          = 0.0,
      popups            = true,
      special           = true,
    },
  },

  animations = {
    enabled = true,
  },
})

hl.curve("emphasizedAccel", { type = "bezier", points = { { 0.3, 0 }, { 0.8, 0.15 } } })
hl.curve("emphasizedDecel", { type = "bezier", points = { { 0.05, 0.7 }, { 0.1, 1 } } })
hl.curve("standard", { type = "bezier", points = { { 0.2, 0 }, { 0, 1 } } })
hl.curve("specialWorkSwitch", { type = "bezier", points = { { 0.05, 0.7 }, { 0.1, 1 } } })

hl.animation({ leaf = "layersIn", enabled = true, speed = 5, bezier = "emphasizedDecel", style = "slide" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 4, bezier = "emphasizedAccel", style = "slide" })
hl.animation({ leaf = "fadeLayers", enabled = true, speed = 5, bezier = "standard" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 5, bezier = "emphasizedDecel", style = "popin 92%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3, bezier = "emphasizedAccel", style = "popin 92%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 6, bezier = "standard" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "standard", style = "slidevert" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4, bezier = "specialWorkSwitch", style = "slidefadevert 15%" })
hl.animation({ leaf = "fade", enabled = true, speed = 6, bezier = "standard" })
hl.animation({ leaf = "fadeDim", enabled = true, speed = 6, bezier = "standard" })
hl.animation({ leaf = "border", enabled = true, speed = 6, bezier = "standard" })

-- Glyph's surfaces (namespace glyph-*) draw their own motion; nothing of theirs is translucent
-- enough to need blur except the dimmed scrims, which shouldn't blur (Nothing doesn't).
hl.layer_rule({
  name    = "glyph-no-anim",
  match   = { namespace = "^glyph-.*" },
  no_anim = true,
})

-- Brave's New Tab shows the dots (the wallpaper) through it
hl.window_rule({
  name    = "glyph-brave-newtab",
  match   = { class = "^brave-origin", title = "^New (Private )?Tab - Brave Origin$" },
  opacity = "0.82 override 0.82 override",
})
