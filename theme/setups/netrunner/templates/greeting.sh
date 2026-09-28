#!/bin/sh
# Netrunner's terminal greeting lines, for fastfetch (templates/fastfetch.jsonc): what the shell
# knows (~/.cache/netrunner/status.json, written by quickshell/netrunner/services/Status.qml) and the
# queue (~/.local/share/netrunner/queue.json), in the references' words.
#   greeting.sh <field>   session | profile | queue | vuln | shield | ice | welcome | watch | pkg
s="$HOME/.cache/netrunner/status.json"
q="$HOME/.local/share/netrunner/queue.json"
get() { jq -r "$1 // empty" "$s" 2>/dev/null; }
case "$1" in
  session) echo "$(get .session) // LOCAL LAB" ;;
  profile) get .profile | tr '[:lower:]' '[:upper:]' ;;
  queue)   jq -r '"\([.gigs[] | select(.done)] | length)/\(.gigs | length) CLEARED"' "$q" 2>/dev/null ;;
  vuln)    [ "$(get .audit)" = "false" ] && echo "SCAN OFFLINE" || echo "$(get .vulns) ON WATCH" ;;
  shield)  sh="$(get .shield)"; [ "$sh" = "NONE" ] && echo "DOWN // NO FIREWALL" || echo "ARMED // $sh" ;;
  ice)     get .ice ;;
  welcome) echo "Welcome back, $USER. Session $(get .session) initialised." ;;
  watch)   v="$(get .vulns)"; h="$(get .high)"; f="$(get .fixable)"
           if [ "$(get .audit)" = "false" ]; then echo "Vulnerability scan offline (install arch-audit)."
           elif [ "${v:-0}" = "0" ]; then echo "No known vulnerabilities. Clean."
           else echo "Watching $v vulnerabilities, $h high. $([ "${f:-0}" = "0" ] && echo 'No patches yet.' || echo "$f fixable by update.")"; fi ;;
  pkg)     p="$(get .pkg)"; [ "$(get .updates)" = "false" ] && echo "Update feed offline (install pacman-contrib)." || echo "${p:-0} package updates pending." ;;
esac
