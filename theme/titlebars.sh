#!/bin/sh
# Title bars for setups that want them (setup.toml [hyprland] titlebars = true: Disguise): loads
# hyprbars (~/.local/lib/hyprland/hyprbars.so, Disguise's patched build) into Hyprland if it isn't
# loaded yet, then reloads the config so setup-binds.lua styles it. Run at Hyprland's start
# (hypr/hyprland.lua) and on every theme/setup switch (writers.py).
#
# Never load the plugin from inside the Lua config: its init reloads the config, which loaded it
# again, and so on until Hyprland crashed (2026-09-29). Never unload it either (same recursion);
# binds.lua just turns it off while another setup is active.
so="$HOME/.local/lib/hyprland/hyprbars.so"
setup=$(cat "$HOME/.local/state/theme/setup" 2>/dev/null)
grep -q '^titlebars *= *true' "$HOME/.config/theme/setups/$setup/setup.toml" 2>/dev/null || exit 0
[ -f "$so" ] || exit 0
hyprctl plugin list 2>/dev/null | grep -qi hyprbars && exit 0
hyprctl plugin load "$so" >/dev/null && hyprctl reload config-only >/dev/null
