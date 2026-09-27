# .config

Arch Linux + Hyprland rice with swappable **setups**: whole desktops (shell, launcher, look, fonts,
cursors, icons, colour themes, wallpapers) switched with one command, each with its own colour themes.

| setup | look |
|---|---|
| **Sharp** | flat, square, quick: a tabbed bar along the top, Cascadia everywhere, nine colour themes |
| **Observatory** | brass instruments and phosphor readouts: a horizon line that opens into a panel, orbital workspaces, gauges, a star-chart launcher, a control deck; six colour themes |

```
~/.config/theme/theme setup observatory     switch setup (or Style → Setup in the menu)
~/.config/theme/theme set aurora            switch colour theme within the setup
~/.config/theme/theme                       manager (themes, wallpapers, images)
```

- `theme/` — the setup and theme system (`theme`, `writers.py`, `tui.py`, `iconkit.py`) and the
  setups themselves (`theme/setups/<setup>/`). How setups work, what every setup must provide and the step-by-step procedure for adding one: [theme/SETUPS.md](theme/SETUPS.md)
- `quickshell/<setup>/` — each setup's shell ([Observatory's README](quickshell/observatory/README.md))
- `hypr/` — Hyprland (Lua config); `look.lua` is linked in from the active setup
- `elephant/menus/` — the menus every setup's launcher shows
- `walker/themes/<setup>/` — each setup's Walker theme

Generated files (colours, fonts, icon and cursor themes) are written on every theme switch and are
not tracked.
