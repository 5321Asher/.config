#!/bin/sh
# Compile Grimoire's shaders (*.frag) to Qt's .qsb, pasting noise.glsl in for `#include "noise.glsl"`.
# Run after editing a shader: sh ~/.config/quickshell/grimoire/shaders/build.sh
# (also builds ~/.config/theme/transition/burn.frag, the switch transition's "burn" style)
cd "$(dirname "$0")" || exit 1
qsb=/usr/lib/qt6/bin/qsb
build() {        # build <src.frag> <out.qsb>
    tmp=$(mktemp --suffix=.frag)
    awk -v inc="$(cat noise.glsl)" '/#include "noise.glsl"/ { print inc; next } { print }' "$1" > "$tmp"
    "$qsb" --glsl "100es,120,150" --hlsl 50 --msl 12 -o "$2" "$tmp" || { rm -f "$tmp"; exit 1; }
    rm -f "$tmp"
    echo "built $2"
}
for f in *.frag; do build "$f" "$f.qsb"; done
t="$HOME/.config/theme/transition/burn.frag"
[ -f "$t" ] && build "$t" "$t.qsb"
