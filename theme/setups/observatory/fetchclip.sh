#!/usr/bin/env bash
# Observatory's fastfetch logos: each theme's wallpaper video, cropped to a portrait window whose right
# edge is the star chart dial's centre line (the left half of the dial, open sky beyond it), as a looping GIF.
#
#   fetchclip.sh [theme-id ...]   ->  images/<theme>/fastfetch.gif   (every theme when none are given)
#
# The wallpaper is the theme's `wallpaper =` (a 2-minute seamless loop from skyvideo.py). It plays 8x
# faster here so the whole loop fits in 15 s and still joins up; 10 fps and 400 px wide keep the GIF
# ~6 MB, which kitty takes ~0.5 s to load when a terminal opens (bigger or longer = slower). writers.py
# shows an animated fastfetch.gif through kitty-icat, which plays it.
set -euo pipefail

here=$(dirname "$(readlink -f "$0")")
pool="$HOME/Pictures/Wallpaper-Themes/_pool"
speed=8 fps=10 width=400
focus=0.68        # the dial's centre, as a share of the video's width (skyvideo.py puts the pole there):
                  # the crop ends there
aspect=0.9        # the logo box: 65 x 30 cells at 2.4 (settings.toml [fastfetch])

themes=("$@")
[ ${#themes[@]} -eq 0 ] && themes=($(ls "$here/themes" | sed -n 's/\.toml$//p'))

for tid in "${themes[@]}"; do
    wall=$(sed -n 's/^wallpaper[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' "$here/themes/$tid.toml")
    video="$pool/$wall"
    if [ -z "$wall" ] || [ ! -f "$video" ]; then
        echo "$tid: no wallpaper video ($wall), skipped" >&2
        continue
    fi
    IFS=, read -r vw vh < <(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$video")
    cw=$(awk -v h="$vh" -v a="$aspect" 'BEGIN { printf "%d", h * a / 2 * 2 }')
    cx=$(awk -v w="$vw" -v c="$cw" -v f="$focus" 'BEGIN { x = w * f - c; if (x < 0) x = 0; if (x > w - c) x = w - c; printf "%d", x }')
    out="$here/images/$tid/fastfetch.gif"
    mkdir -p "$(dirname "$out")"
    ffmpeg -v error -y -i "$video" -vf "setpts=PTS/$speed,fps=$fps,crop=$cw:$vh:$cx:0,scale=$width:-2:flags=lanczos,split[a][b];[a]palettegen=max_colors=160:stats_mode=full[p];[b][p]paletteuse=dither=bayer:bayer_scale=4" \
        -loop 0 "$out.tmp.gif"
    mv "$out.tmp.gif" "$out"
    echo "$out"
done
