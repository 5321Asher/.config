#!/bin/sh
# Win + V / Win + . : Windows 11's emoji panel on a tab (clipboard | emoji), opened at the pointer.
# setups/disguise/setup.toml [menus] clipboard / emoji run this.
p=$(hyprctl cursorpos 2>/dev/null)
x=${p%%,*}; y=${p##*, }
exec qs ipc call emoji open "${1:-emoji}" "${x:-0}" "${y:-0}"
