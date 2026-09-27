#!/usr/bin/env bash
# Create a web app: a launcher that opens a site in Brave's app mode (its own window, no tabs or toolbar).
# usage: webapp.sh [url] [name]   — prompts through walker for anything not given
set -u

prompt() { walker --dmenu --inputonly --placeholder "$1" 2>/dev/null; }

url=${1:-$(prompt "Web app URL (e.g. chatgpt.com)")}
url=$(printf '%s' "$url" | tr -d '[:space:]')
[ -z "$url" ] && exit 0
case "$url" in http://* | https://*) ;; *) url="https://$url" ;; esac

host=$(printf '%s' "$url" | sed -E 's#^https?://([^/:]+).*#\1#')
# "www.chatgpt.com" -> "Chatgpt"
guess=$(printf '%s' "$host" | sed -E 's/^www\.//; s/\.[^.]+$//; s/.*\.//')
guess="$(printf '%s' "${guess:0:1}" | tr '[:lower:]' '[:upper:]')${guess:1}"

name=${2:-$(prompt "Name (Enter for $guess)")}
[ -z "$name" ] && name=$guess

slug=$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-|-$//g')
apps="$HOME/.local/share/applications"
icons="$apps/icons"
mkdir -p "$icons"
desktop="$apps/webapp-$slug.desktop"
icon="$icons/webapp-$slug.png"

# Icon: dashboard-icons by name, then the site's own touch icon, then a favicon service
tmp=$(mktemp)
icon_value="web-browser"
for src in \
    "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/$slug.png" \
    "https://$host/apple-touch-icon.png" \
    "https://www.google.com/s2/favicons?domain=$host&sz=128"; do
    if curl -fsL --max-time 8 -o "$tmp" "$src" && file --mime-type -b "$tmp" | grep -q '^image/'; then
        magick "$tmp" -resize 128x128 "$icon" 2>/dev/null && icon_value="$icon" && break
    fi
done
rm -f "$tmp"

# Escape for a quoted Exec argument (desktop entry spec)
exec_url=$(printf '%s' "$url" | sed -E 's/([\\"`$])/\\\1/g; s/%/%%/g')

# Brave's Wayland app id for --app windows, so the window groups with this launcher
wmclass="brave-$(printf '%s' "$url" | sed -E 's#^https?://##; s#^([^/]*)/?#\1__#; s#/#_#g')-Default"

cat >"$desktop" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=$name
Comment=Web app for $url
Exec=brave --app="$exec_url"
Icon=$icon_value
Terminal=false
StartupNotify=true
StartupWMClass=$wmclass
Categories=Network;WebBrowser;
X-WebApp-URL=$url
EOF

notify-send -a "Web apps" -i "$icon_value" "Web app created" "$name — find it in Apps"
