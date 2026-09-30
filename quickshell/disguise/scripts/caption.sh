#!/bin/sh
# Windows' window commands for Disguise: the title bar's caption buttons (hyprbars), Aero Snap when a
# title bar is dropped at a screen edge (the patched hyprbars), and Win + arrows (setup-binds.lua).
#
#   caption.sh [--active] close        close it
#   caption.sh [--active] max          maximise it; if it's maximised, restore it ("Restore down")
#   caption.sh [--active] min          minimise it to the taskbar
#   caption.sh [--active] snap top     maximise           (dropped at the top edge, Win + Up)
#   caption.sh [--active] snap left    the left half      (dropped at the left edge, Win + Left)
#   caption.sh [--active] snap right   the right half
#   caption.sh --active down           Win + Down: restore a maximised / snapped window, else minimise
#
# The window is the one under the pointer (the bar sits above the window, so it counts as the window),
# or with --active the focused one.
#
# Maximised is Windows' kind, not Hyprland's: a floating window that fills the screen above the taskbar,
# tagged disguise-max (Hyprland keeps one maximised window per workspace and un-maximises the other;
# on Windows any number stay maximised, overlapping, and Alt + Tab picks between them). "Restore down"
# puts the window back where it was before (remembered per window), else centred at 70 %.
#
#   caption.sh adopt                   turn Hyprland-maximised windows (an app asked for it) into
#                                      Windows-maximised ones (Quickshell runs it on every fullscreen event)
BAR=32
TASKBAR=48

target=pointer
[ "$1" = "--active" ] && { target=active; shift; }

STATE="${XDG_RUNTIME_DIR:-/tmp}/disguise-caption"
mkdir -p "$STATE"

if [ "$1" = adopt ]; then
    # fullscreen 1 = Hyprland's maximised (2, real fullscreen, is left alone)
    hyprctl clients -j | jq -r '.[] | select(.mapped and .fullscreen == 1) | .address' | while read -r a; do
        "$0" --window "$a" max-from-hyprland
    done
    exit 0
fi
[ "$1" = "--window" ] && { target="$2"; shift 2; }

if [ "$target" = active ]; then
    win=$(hyprctl activewindow -j)
elif [ "$target" != pointer ]; then
    win=$(hyprctl clients -j | jq -r --arg a "$target" '.[] | select(.address == $a)')
else
    pos=$(hyprctl cursorpos 2>/dev/null)
    cx=${pos%%,*}; cy=${pos##*, }
    win=$(hyprctl clients -j | jq -r --argjson x "$cx" --argjson y "$cy" --argjson bar "$BAR" \
          --argjson ws "$(hyprctl activeworkspace -j | jq .id)" '
      map(select(.mapped and (.hidden | not) and .workspace.id == $ws))
      | map(select($x >= .at[0] and $x < .at[0] + .size[0] and $y >= .at[1] - $bar and $y < .at[1] + .size[1]))
      | sort_by(.focusHistoryID) | .[0] // empty')
fi
[ -z "$win" ] || [ "$(printf '%s' "$win" | jq -r '.address // empty')" = "" ] && exit 0

addr=$(printf '%s' "$win" | jq -r .address)
sel="address:$addr"
fs=$(printf '%s' "$win" | jq -r .fullscreen)
floating=$(printf '%s' "$win" | jq -r .floating)
mon=$(printf '%s' "$win" | jq -r .monitor)
# the monitor's usable area (logical px): x y w h, above the taskbar
read -r mx my mw mh <<EOF
$(hyprctl monitors -j | jq -r --argjson m "$mon" --argjson tb "$TASKBAR" '.[] | select(.id == $m)
  | "\(.x) \(.y) \((.width / .scale) | round) \(((.height / .scale) - $tb) | round)"')
EOF

d() { hyprctl dispatch "$1" >/dev/null 2>&1; }
at=$(printf '%s' "$win" | jq -r '"\(.at[0]) \(.at[1]) \(.size[0]) \(.size[1])"')
tags=$(printf '%s' "$win" | jq -r '.tags | join(" ")')
# windows that draw their own caption (no hyprbars bar): Quickshell's Settings
bar=$BAR
[ "$(printf '%s' "$win" | jq -r .class)" = org.quickshell ] && bar=0
focus() { d "hl.dsp.focus({ window = \"$sel\" })"; d "hl.dsp.window.alter_zorder({ mode = \"top\", window = \"$sel\" })"; }
is_hmax() { [ "$fs" = "1" ]; }
is_max() { is_hmax || case " $tags " in *" disguise-max "*) true ;; *) false ;; esac; }
tag() { d "hl.dsp.window.tag({ tag = \"$1disguise-max\", window = \"$sel\" })"; }
unhmax() { is_hmax && d "hl.dsp.window.fullscreen_state({ internal = 0, client = 0, window = \"$sel\" })"; true; }
float_on() { [ "$floating" = "true" ] || d "hl.dsp.window.float({ action = \"enable\", window = \"$sel\" })"; }
place() {  # x y w h, logical px (the window's own box; its bar goes above y)
    d "hl.dsp.window.resize({ x = $3, y = $4, window = \"$sel\" })"
    d "hl.dsp.window.move({ x = $1, y = $2, window = \"$sel\" })"
}
is_half() {
    set -- $at
    [ "$floating" = "true" ] && [ $(( $3 - mw / 2 )) -le 2 ] && [ $(( mw / 2 - $3 )) -le 2 ] && [ "$4" -ge $(( mh - bar - 2 )) ]
}
# remember where a restored window was, so Restore down puts it back
remember() { is_max || is_half || [ "$floating" != "true" ] || printf '%s\n' "$at" > "$STATE/$addr"; }
maximise() {
    remember; unhmax; float_on
    place "$mx" $((my + bar)) "$mw" $((mh - bar))
    case " $tags " in *" disguise-max "*) ;; *) tag + ;; esac
}
restore() {
    unhmax; float_on
    case " $tags " in *" disguise-max "*) tag - ;; esac
    if [ -s "$STATE/$addr" ]; then
        set -- $(cat "$STATE/$addr")
        place "$1" "$2" "$3" "$4"
    else
        w=$((mw * 7 / 10)); h=$((mh * 7 / 10))
        place $((mx + (mw - w) / 2)) $((my + (mh - h) / 2)) "$w" "$h"
    fi
}
half() {  # left | right, the bar counted in the window's height
    remember; unhmax; float_on
    case " $tags " in *" disguise-max "*) tag - ;; esac
    w=$((mw / 2)); h=$((mh - bar))
    if [ "$1" = left ]; then place "$mx" $((my + bar)) "$w" "$h"; else place $((mx + mw - w)) $((my + bar)) "$w" "$h"; fi
}

case $1 in
close) d "hl.dsp.window.close({ window = \"$sel\" })"; rm -f "$STATE/$addr" ;;
min)   qs ipc call taskbar minimizeWindow "$addr" ;;
max)   focus; if is_max; then restore; else maximise; fi ;;
max-from-hyprland) is_hmax && maximise ;;
snap)
    focus
    case $2 in
    top)   is_max && ! is_hmax || maximise ;;
    left)  half left ;;
    right) half right ;;
    esac ;;
down)
    focus
    if is_max || is_half; then restore
    else qs ipc call taskbar minimizeWindow "$addr"; fi ;;
esac
