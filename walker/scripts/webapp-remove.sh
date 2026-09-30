#!/usr/bin/env bash
# Remove a web app made by webapp.sh: pick it by name (the setup's prompt), delete its launcher and icon.
set -u

apps="$HOME/.local/share/applications"
shopt -s nullglob
files=("$apps"/webapp-*.desktop)
if [ ${#files[@]} -eq 0 ]; then
    notify-send -a "Web apps" "No web apps to remove"
    exit 0
fi

# "Name  ·  url" per line, in the same order as the files
choice=$(for f in "${files[@]}"; do
    printf '%s  ·  %s\n' "$(sed -n 's/^Name=//p' "$f")" "$(sed -n 's/^X-WebApp-URL=//p' "$f")"
done | ~/.config/theme/prompt --index --placeholder "Remove web app")
[ -z "$choice" ] && exit 0

f=${files[$choice]}
name=$(sed -n 's/^Name=//p' "$f")
rm -f "$f" "$apps/icons/$(basename "$f" .desktop).png"
notify-send -a "Web apps" "Web app removed" "$name"
