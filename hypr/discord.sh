#!/bin/sh
# Discord under XWayland, at the scale of the monitor it opens on.
# Native-Wayland Electron applies a monitor scale < 1 twice (page shrunk into the top-left corner).
# ~/.config/electron-flags.conf fixes that for the system Electron apps, but Discord ships its own
# Electron and overwrites --disable-features at startup, so it can't be fixed on Wayland.
# XWayland windows are drawn 1:1 (xwayland.force_zero_scaling), so Chromium is told the scale itself.
# Launched by ~/.local/share/applications/discord.desktop.

scale=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .scale' 2>/dev/null)
case "$scale" in
  "" | 1 | 1.0) ;;
  *) set -- --force-device-scale-factor="$scale" "$@" ;;
esac
exec /usr/bin/discord --ozone-platform=x11 "$@"
