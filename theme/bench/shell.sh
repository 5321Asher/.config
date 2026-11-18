#!/bin/zsh
# shell.sh start|stop|ready|ipc|shot|key|ptr|log : a shell under test inside the bench compositor.
# BENCH_SHELL = the shell.qml to run: a COPY of the setup's shell (never the active setup's own
# folder: a second instance of it grabs the notification server when the live shell restarts).
#   start [secs]   (TIMING=1 logs frame timing for perf2.py)   ready   ipc <target> <fn> [args]
#   notify <notify-send args>   shot [file]    key <wtype args>    ptr <vptr cmds: move X Y | rel DX DY | click [btn] | wheel N>
B=${0:A:h}
SHELL_QML=${BENCH_SHELL:?set BENCH_SHELL to the shell.qml of a copy of the shell}
[[ -s $B/wl && -s $B/sig ]] || { echo "bench compositor is not up (bench.sh up)"; exit 1; }
eval $($B/bench.sh env)
case $1 in
start) pkill -f "qs -p $SHELL_QML" 2>/dev/null; sleep 0.3
       # its own D-Bus session, so it can own the notification server (and tray) like a live shell;
       # `shell.sh notify ...` sends there
       (cd ${SHELL_QML:h} && QSG_RENDER_TIMING=${TIMING:-0} QSG_INFO=${TIMING:-0} dbus-run-session -- sh -c \
           'echo "$DBUS_SESSION_BUS_ADDRESS" > "$1"; exec qs -p "$2"' sh $B/dbus $SHELL_QML > $B/qs.log 2>&1 &) ; sleep ${2:-3} ;;
notify) shift; DBUS_SESSION_BUS_ADDRESS=$(cat $B/dbus) notify-send "$@" ;;
stop)  pkill -f "qs -p $SHELL_QML" ;;
ready) for i in {1..60}; do qs ipc -p $SHELL_QML show >/dev/null 2>&1 && qs ipc -p $SHELL_QML call debug rig >/dev/null 2>&1 && exit 0; sleep 0.25; done; echo "not ready"; exit 1 ;;
ipc)   shift; qs ipc -p $SHELL_QML call "$@" ;;
shot)  timeout 5 grim -o NRTEST ${2:-$B/shot.png} ;;
key)   shift; wtype "$@" ;;
ptr)   shift; W=$(hyprctl monitors -j | jq '.[] | select(.name=="NRTEST") | (.width / .scale | round)'); H=$(hyprctl monitors -j | jq '.[] | select(.name=="NRTEST") | (.height / .scale | round)'); $B/vptr $W $H "$@" ;;
log)   grep -vE "notification server|Registration will be|failed to register listener|polkit.*PolkitAgent|Virtual modifier|textinput" $B/qs.log | grep -iE "warn|error|qml|TypeError|ReferenceError" ;;
esac
