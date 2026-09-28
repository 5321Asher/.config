#!/bin/sh
# Grimoire's terminal lines, for fastfetch (templates/fastfetch.jsonc): the reader's arcane rank (from
# how long this install has been kept: the first line of pacman's log; and its circle from how many
# spells, packages, it knows), the candle (uptime), the book's theme, and a greeting.
#   arcana.sh <field>   rank | spells | candle | theme | welcome | motto
days() {
    first=$(head -c 11 /var/log/pacman.log 2>/dev/null | tr -d '[')
    [ -n "$first" ] || { echo 0; return; }
    echo $(( ( $(date +%s) - $(date -d "$first" +%s 2>/dev/null || date +%s) ) / 86400 ))
}
spells() { pacman -Qq 2>/dev/null | wc -l; }
case "$1" in
  rank)
    d=$(days); n=$(spells)
    if   [ "$d" -lt 14 ];   then r="Novice"
    elif [ "$d" -lt 45 ];   then r="Apprentice"
    elif [ "$d" -lt 120 ];  then r="Journeyman"
    elif [ "$d" -lt 365 ];  then r="Adept"
    elif [ "$d" -lt 730 ];  then r="Magus"
    elif [ "$d" -lt 1460 ]; then r="Archmage"
    else r="Elder"; fi
    c=$(( n / 150 + 1 )); [ "$c" -gt 9 ] && c=9
    set -- First Second Third Fourth Fifth Sixth Seventh Eighth Ninth
    eval circle=\${$c}
    echo "$r of the $circle Circle" ;;
  spells)  echo "$(spells) known" ;;
  candle)
    s=$(cut -d. -f1 /proc/uptime); h=$((s / 3600)); m=$((s % 3600 / 60))
    if [ "$h" -gt 0 ]; then echo "burning ${h}h ${m}m"; else echo "burning ${m}m"; fi ;;
  theme)
    jq -r '.setups.grimoire.current // "oxblood"' "${XDG_STATE_HOME:-$HOME/.local/state}/theme/state.json" 2>/dev/null \
      | sed 's/^./\U&/' ;;
  welcome) echo "Welcome back, $USER. The candle is lit." ;;
  motto)
    set -- "Knowledge is the lamp; patience, the oil." "Every spell was once a typo." \
           "Read twice, cast once." "The book remembers what the reader forgets." \
           "Mind the wards; update often." "Ink dries. Commit your work."
    i=$(( $(date +%j | sed 's/^0*//') % 6 + 1 ))
    eval echo "\${$i}" ;;
esac
