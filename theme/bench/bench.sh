#!/bin/zsh
# bench.sh up [mode] [scale] | down | env : a nested Hyprland with one headless output (NRTEST) for
# testing a shell without touching the session: nothing shows on your screens and nothing takes your
# keyboard. Run from the real session (not from a shell whose environment points at a bench).
#   bench.sh up 1366x768@60 0.67      laptop      bench.sh up 2560x1440@60 1      desktop
#   bench.sh up 1080x1920@60 0.75     portrait
B=${0:A:h}
case $1 in
up)
  [[ -x $B/vptr ]] || { (cd $B && wayland-scanner client-header vp.xml vp.h && wayland-scanner private-code vp.xml vp.c \
                          && gcc -O2 -o vptr vptr.c vp.c -lwayland-client -lm) || exit 1; }
  hyprctl eval 'hl.window_rule({ name = "nr-bench", match = { class = "^(aquamarine|hyprland)$" }, workspace = "special:nrbench silent" })' >/dev/null
  before=($XDG_RUNTIME_DIR/hypr/*(N/))
  NR_MODE=$2 NR_SCALE=$3 Hyprland -c $B/test.lua >$B/hypr.log 2>&1 &
  echo $! > $B/hypr.pid
  for i in {1..50}; do
    sleep 0.2
    for d in $XDG_RUNTIME_DIR/hypr/*(N/); do
      if (( ! ${before[(Ie)$d]} )) && [[ -S $d/.socket.sock ]]; then sig=${d:t}; break 2; fi
    done
  done
  [[ -z $sig ]] && { echo "no instance"; exit 1; }
  echo $sig > $B/sig
  for i in {1..30}; do
    sleep 0.2
    HYPRLAND_INSTANCE_SIGNATURE=$sig hyprctl monitors -j 2>/dev/null | grep -q NRTEST && break
  done
  wl=$(HYPRLAND_INSTANCE_SIGNATURE=$sig hyprctl instances -j | jq -r --arg s $sig '.[] | select(.instance==$s) | .wl_socket')
  echo $wl > $B/wl
  HYPRLAND_INSTANCE_SIGNATURE=$sig hyprctl dismissnotify >/dev/null 2>&1
  echo "sig=$sig wl=$wl"; HYPRLAND_INSTANCE_SIGNATURE=$sig hyprctl monitors -j | jq -r '.[] | "\(.name) \(.width)x\(.height) scale \(.scale) disabled=\(.disabled)"'
  ;;
down)
  if [[ -f $B/hypr.pid ]]; then p=$(cat $B/hypr.pid); kill $p 2>/dev/null; for i in {1..50}; do kill -0 $p 2>/dev/null || break; sleep 0.1; done; fi
  rm -f $B/hypr.pid $B/sig $B/wl ;;
env)
  echo "export HYPRLAND_INSTANCE_SIGNATURE=$(cat $B/sig) WAYLAND_DISPLAY=$(cat $B/wl)" ;;
esac
