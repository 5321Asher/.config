-- The bench's nested Hyprland: one headless output (NRTEST, size and scale from bench.sh), the
-- active setup's look (layer rules, blur, animations), nothing else.
hl.monitor({ output = "WAYLAND-1", disabled = true })
hl.monitor({ output = "NRTEST", mode = os.getenv("NR_MODE") or "1366x768@60", position = "0x0", scale = os.getenv("NR_SCALE") or "0.67" })
hl.config({
  misc = { disable_hyprland_logo = true, disable_splash_rendering = true, allow_session_lock_restore = true },
  ecosystem = { no_update_news = true, no_donation_nag = true },
})
pcall(dofile, os.getenv("HOME") .. "/.config/hypr/look.lua")
hl.on("hyprland.start", function() hl.exec_cmd("hyprctl output create headless NRTEST") end)
