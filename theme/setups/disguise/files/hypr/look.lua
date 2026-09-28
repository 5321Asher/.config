-- Disguise: Windows 11. Rounded corners (8 px, like Windows' own), a hairline grey frame (colors.lua,
-- from the theme's activeBorder / inactiveBorder), the big soft shadow Windows puts under every
-- window, snap-layout gaps, and Fluent motion: windows pop up from 90 % and fade, desktops slide.
-- Quickshell's panels (namespace disguise-*) are Acrylic: translucent, with the desktop blurred behind.
-- The active setup's look, linked here as ~/.config/hypr/look.lua on a setup switch.

hl.config({
  general = {
    gaps_in          = 4,
    gaps_out         = { top = 8, right = 8, bottom = 8, left = 8 },
    border_size      = 1,
    col              = {
      active_border   = "rgba(c7c7c7ff)",
      inactive_border = "rgba(d9d9d9ff)",
    },
    resize_on_border = true,
    allow_tearing    = false,
    layout           = "dwindle",
  },

  decoration = {
    rounding         = 8,
    rounding_power   = 2,

    active_opacity   = 1.0,
    inactive_opacity = 1.0,
    dim_inactive     = false,
    dim_special      = 0.3,

    -- Windows 11's window shadow: wide, soft, a little lower than the window
    shadow           = {
      enabled        = true,
      range          = 28,
      render_power   = 3,
      offset         = { 0, 8 },
      color          = 0x47000000,
      color_inactive = 0x24000000,
    },

    -- Acrylic: a strong blur with a little noise, a touch of saturation
    blur             = {
      enabled    = true,
      size       = 12,
      passes     = 4,
      noise      = 0.03,
      contrast   = 1.0,
      brightness = 1.0,
      vibrancy   = 0.3,
      popups     = true,
      special    = true,
    },
  },

  animations = {
    enabled = true,
  },
})

-- Fluent's curves: "decelerate" (fast out, slow in) for things arriving, "accelerate" for leaving
hl.curve("fluentIn", { type = "bezier", points = { { 0.1, 0.9 }, { 0.2, 1 } } })
hl.curve("fluentOut", { type = "bezier", points = { { 0.7, 0 }, { 1, 0.5 } } })
hl.curve("fluentMove", { type = "bezier", points = { { 0, 0 }, { 0, 1 } } })

-- speed is in 100 ms steps
hl.animation({ leaf = "global", enabled = true, speed = 2.5, bezier = "fluentIn" })
hl.animation({ leaf = "windows", enabled = true, speed = 2.5, bezier = "fluentIn" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 2.5, bezier = "fluentIn", style = "popin 90%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.5, bezier = "fluentOut", style = "popin 95%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 3, bezier = "fluentMove" })
hl.animation({ leaf = "border", enabled = false })
hl.animation({ leaf = "fade", enabled = true, speed = 2, bezier = "fluentIn" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.5, bezier = "fluentOut" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 3.5, bezier = "fluentMove", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 2.5, bezier = "fluentIn", style = "slidevert" })
hl.animation({ leaf = "layers", enabled = true, speed = 2, bezier = "fluentIn" })
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 2, bezier = "fluentIn" })

-- Disguise's panels are Acrylic (blur what's behind them; fully clear pixels stay clear), and
-- Quickshell animates them itself (they slide up from the taskbar the way Windows' flyouts do)
hl.layer_rule({
  name         = "disguise-blur",
  match        = { namespace = "^disguise-(taskbar|flyout|toast|osd|uac|taskview|voice|snip|menu)$" },
  blur         = true,
  ignore_alpha = 0.2,
})
hl.layer_rule({
  name    = "disguise-no-anim",
  match   = { namespace = "^disguise-.*" },
  no_anim = true,
})

-- Settings (Quickshell's own window) floats at its own size, with Mica: the desktop blurred through it
hl.window_rule({
  name  = "disguise-settings",
  match = { class = "^org.quickshell$", title = "^Settings$" },
  float = true,
  size  = "monitor_w*0.8 monitor_h*0.86",
  center = true,
})

-- Brave's New Tab lets the Bloom show through a little, blurred, like a Mica page
hl.window_rule({
  name    = "disguise-brave-newtab",
  match   = { class = "^brave-browser$", title = "^New (Private )?Tab - Brave$" },
  opacity = "0.9 override 0.9 override",
})
