#!/usr/bin/env python3
"""Add or remove Hyprland keybinds through Walker prompts.

  keybind.py add      pick keys + an action, append to ~/.config/hypr/binds.lua, reload
  keybind.py remove   pick a bind from binds.lua and delete it

Every bind is one line in binds.lua with an optional trailing "-- description", which is also
mirrored into ~/.config/walker/keybinds.txt (the cheat sheet). If Hyprland rejects a change,
binds.lua is restored.
"""

import configparser
import glob
import os
import re
import subprocess
import sys

HOME = os.path.expanduser("~")
BINDS = f"{HOME}/.config/hypr/binds.lua"
SHEET = f"{HOME}/.config/walker/keybinds.txt"

MODS = {"super": "SUPER", "win": "SUPER", "meta": "SUPER", "mod": "SUPER", "shift": "SHIFT",
        "ctrl": "CTRL", "control": "CTRL", "alt": "ALT"}
KEY_NAMES = {"enter": "Return", "return": "Return", "space": "Space", "tab": "Tab", "esc": "Escape",
             "escape": "Escape", "backspace": "BackSpace", "delete": "Delete", "del": "Delete",
             "left": "left", "right": "right", "up": "up", "down": "down", "print": "Print",
             "home": "Home", "end": "End", "pageup": "Prior", "pagedown": "Next",
             "lmb": "mouse:272", "rmb": "mouse:273", "scrollup": "mouse_up", "scrolldown": "mouse_down"}


# ---------- walker prompts ----------

def ask(placeholder):
    r = subprocess.run(["walker", "--dmenu", "--inputonly", "--placeholder", placeholder],
                       capture_output=True, text=True)
    return r.stdout.strip()


def pick(placeholder, options, index=False):
    cmd = ["walker", "--dmenu", "--placeholder", placeholder] + (["--index"] if index else [])
    r = subprocess.run(cmd, input="\n".join(options), capture_output=True, text=True)
    out = r.stdout.strip()
    if index:
        return int(out) if out.isdigit() else None
    return out


def notify(title, body=""):
    subprocess.run(["notify-send", "-a", "Keybinds", title, body])


# ---------- helpers ----------

def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def exec_cmd(cmd):
    return f"hl.dsp.exec_cmd({lua_str(cmd)})"


def normalize_keys(text):
    """'super+shift+q' -> 'SUPER + SHIFT + Q'"""
    parts = [p.strip() for p in text.split("+") if p.strip()]
    out = []
    for p in parts:
        low = p.lower()
        if low in MODS:
            out.append(MODS[low])
        elif low in KEY_NAMES:
            out.append(KEY_NAMES[low])
        elif len(p) == 1 or re.fullmatch(r"f\d{1,2}", low):
            out.append(p.upper())
        else:
            out.append(p)
    return " + ".join(out)


def modifiers_only(text):
    """For number-key templates: 'super shift' / 'SUPER + SHIFT' -> 'SUPER + SHIFT'"""
    return " + ".join(MODS.get(p.lower(), p.upper()) for p in re.split(r"[\s+]+", text) if p)


def apps():
    """Installed desktop apps as (name, desktop id)."""
    found = {}
    dirs = [f"{HOME}/.local/share/applications", "/usr/share/applications", "/usr/local/share/applications"]
    for d in dirs:
        for path in sorted(glob.glob(f"{d}/*.desktop")):
            cp = configparser.ConfigParser(interpolation=None, strict=False)
            try:
                cp.read(path, encoding="utf-8")
                e = cp["Desktop Entry"]
            except (configparser.Error, KeyError, UnicodeDecodeError):
                continue
            if e.get("NoDisplay", "false").lower() == "true" or e.get("Type") != "Application":
                continue
            found.setdefault(e.get("Name", os.path.basename(path)), os.path.basename(path)[:-8])
    return sorted(found.items(), key=lambda x: x[0].lower())


def read_lines():
    try:
        with open(BINDS) as f:
            return f.read().splitlines()
    except OSError:
        return []


def write_lines(lines):
    with open(BINDS, "w") as f:
        f.write("\n".join(lines).rstrip("\n") + "\n")


def is_bind(line):
    s = line.strip()
    return bool(s) and not s.startswith("--") and "hl.bind(" in s


def bind_keys(line):
    m = re.search(r'hl\.bind\("([^"]*)"', line)
    if m:
        return m.group(1)
    m = re.search(r'hl\.bind\(("[^"]*") \.\.', line)  # number-key loop
    return (m.group(1).strip('"').rstrip(" +") + " + 1‥0") if m else "?"


def bind_desc(line):
    m = re.search(r"\)\s*--\s*(.+)$", line)
    return m.group(1).strip() if m else ""


def reload_ok():
    subprocess.run(["hyprctl", "reload", "config-only"], capture_output=True)
    errors = subprocess.run(["hyprctl", "configerrors"], capture_output=True, text=True).stdout.strip()
    return errors


def sheet_update(keys, desc, remove=False):
    try:
        with open(SHEET) as f:
            lines = f.read().splitlines()
    except OSError:
        lines = []
    lines = [l for l in lines if l.startswith("#") or l.split("|")[0].strip() != keys]
    if not remove:
        lines.append(f"{keys:<23} | {desc}")
    with open(SHEET, "w") as f:
        f.write("\n".join(lines).rstrip("\n") + "\n")


# ---------- actions ----------

def choose_action():
    """Returns (lua dispatcher expression, bind options or '', default description, template) or None."""
    actions = [
        "Run a command",
        "Launch an app",
        "Close window",
        "Toggle floating",
        "Toggle fullscreen",
        "Pseudo-tile",
        "Toggle split",
        "Move focus (left / right / up / down)",
        "Go to workspace…",
        "Move window to workspace…",
        "Workspace number keys (mod + 1‥0 → go to workspace)",
        "Workspace number keys (mod + 1‥0 → move window there)",
        "Toggle scratchpad",
        "Move window to scratchpad",
        "Move window with mouse drag",
        "Resize window with mouse drag",
        "Walker menu",
        "Walker app launcher",
        "Workspace overview (Quickshell)",
        "Screen recording on/off (Quickshell)",
        "Screenshot region (Quickshell)",
        "Screenshot screen (Quickshell)",
        "Copy text from region / OCR (Quickshell)",
        "Clipboard history (Walker)",
        "Dictation start / stop (voxtype)",
        "Cancel dictation (voxtype)",
        "Volume up",
        "Volume down",
        "Mute audio",
        "Media play / pause",
        "Media next",
        "Media previous",
        "Exit Hyprland",
    ]
    a = pick("What should it do?", actions)
    if not a:
        return None

    if a == "Run a command":
        cmd = ask("Command to run")
        return (exec_cmd(cmd), "", cmd, None) if cmd else None
    if a == "Launch an app":
        lst = apps()
        i = pick("Which app?", [n for n, _ in lst], index=True)
        if i is None:
            return None
        name, app_id = lst[i]
        return exec_cmd(f"gtk-launch {app_id}"), "", name, None
    if a.startswith("Move focus"):
        d = pick("Direction", ["left", "right", "up", "down"])
        return (f'hl.dsp.focus({{ direction = "{d}" }})', "", f"Focus {d}", None) if d else None
    if a == "Go to workspace…":
        n = ask("Workspace number")
        return (f"hl.dsp.focus({{ workspace = {int(n)} }})", "", f"Go to workspace {n}", None) if n.isdigit() else None
    if a == "Move window to workspace…":
        n = ask("Workspace number")
        return (f"hl.dsp.window.move({{ workspace = {int(n)} }})", "", f"Move window to workspace {n}", None) if n.isdigit() else None
    if a.startswith("Workspace number keys"):
        move = "move window" in a
        expr = "hl.dsp.window.move({ workspace = i })" if move else "hl.dsp.focus({ workspace = i })"
        return expr, "", ("Move window to workspace" if move else "Go to workspace"), "numbers"

    simple = {
        "Close window": ("hl.dsp.window.close()", ""),
        "Toggle floating": ('hl.dsp.window.float({ action = "toggle" })', ""),
        "Toggle fullscreen": ("hl.dsp.window.fullscreen()", ""),
        "Pseudo-tile": ("hl.dsp.window.pseudo()", ""),
        "Toggle split": ('hl.dsp.layout("togglesplit")', ""),
        "Toggle scratchpad": ('hl.dsp.workspace.toggle_special("magic")', ""),
        "Move window to scratchpad": ('hl.dsp.window.move({ workspace = "special:magic" })', ""),
        "Move window with mouse drag": ("hl.dsp.window.drag()", "{ mouse = true }"),
        "Resize window with mouse drag": ("hl.dsp.window.resize()", "{ mouse = true }"),
        "Menu (setup's)": (exec_cmd("~/.config/theme/menu root"), ""),
        "App launcher (setup's)": (exec_cmd("~/.config/theme/menu apps"), ""),
        "Workspace overview (Quickshell)": (exec_cmd("qs ipc call overview toggle"), ""),
        "Screen recording on/off (Quickshell)": (exec_cmd("qs ipc call capture toggleRecording"), ""),
        "Screenshot region (Quickshell)": (exec_cmd("qs ipc call capture screenshot region"), ""),
        "Screenshot screen (Quickshell)": (exec_cmd("qs ipc call capture screenshot screen"), ""),
        "Copy text from region / OCR (Quickshell)": (exec_cmd("qs ipc call capture ocr"), ""),
        "Clipboard history (Walker)": (exec_cmd("walker -m clipboard"), ""),
        "Dictation start / stop (voxtype)": (exec_cmd("voxtype record toggle"), ""),
        "Cancel dictation (voxtype)": (exec_cmd("voxtype record cancel"), ""),
        "Volume up": (exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), "{ locked = true, repeating = true }"),
        "Volume down": (exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), "{ locked = true, repeating = true }"),
        "Mute audio": (exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), "{ locked = true }"),
        "Media play / pause": (exec_cmd("playerctl play-pause"), "{ locked = true }"),
        "Media next": (exec_cmd("playerctl next"), "{ locked = true }"),
        "Media previous": (exec_cmd("playerctl previous"), "{ locked = true }"),
        "Exit Hyprland": ("hl.dsp.exit()", ""),
    }
    expr, opts = simple[a]
    return expr, opts, a.replace(" (Quickshell)", ""), None


def add():
    choice = choose_action()
    if not choice:
        return
    expr, opts, default_desc, template = choice

    if template == "numbers":
        mods = modifiers_only(ask("Modifier(s) for the number keys, e.g. SUPER  or  SUPER + SHIFT"))
        if not mods:
            return
        keys = f"{mods} + 1‥0"
        opt = f", {opts}" if opts else ""
        line_body = f'for i = 1, 10 do hl.bind("{mods} + " .. (i % 10), {expr}{opt}) end'
    else:
        hint = "e.g. SUPER + LMB" if opts == "{ mouse = true }" else "e.g. SUPER + Return  ·  SUPER + SHIFT + Q"
        raw = ask(f"Keys  ({hint})")
        if not raw:
            return
        keys = normalize_keys(raw)
        opt = f", {opts}" if opts else ""
        line_body = f"hl.bind({lua_str(keys)}, {expr}{opt})"

    desc = ask(f"Description (Enter for “{default_desc}”)") or default_desc
    line = f"{line_body} -- {desc}"

    old = read_lines()
    lines = list(old)
    clash = [i for i, l in enumerate(lines) if is_bind(l) and bind_keys(l) == keys]
    if clash:
        if pick(f"{keys} is already bound — replace it?", ["Replace", "Cancel"]) != "Replace":
            return
        lines = [l for i, l in enumerate(lines) if i not in clash]
    lines.append(line)
    write_lines(lines)

    errors = reload_ok()
    if errors:
        write_lines(old)
        reload_ok()
        notify("Keybind not added", errors.splitlines()[0])
        return
    sheet_update(keys, desc)
    notify("Keybind added", f"{keys}  →  {desc}")


def remove():
    lines = read_lines()
    binds = [(i, l) for i, l in enumerate(lines) if is_bind(l)]
    if not binds:
        notify("No keybinds to remove")
        return
    labels = [f"{bind_keys(l)}  ·  {bind_desc(l) or l.strip()}" for _, l in binds]
    k = pick("Remove which keybind?", labels, index=True)
    if k is None:
        return
    idx, line = binds[k]
    keys = bind_keys(line)
    new = [l for i, l in enumerate(lines) if i != idx]
    write_lines(new)
    errors = reload_ok()
    if errors:
        write_lines(lines)
        reload_ok()
        notify("Keybind not removed", errors.splitlines()[0])
        return
    sheet_update(keys, "", remove=True)
    notify("Keybind removed", keys)


if __name__ == "__main__":
    {"add": add, "remove": remove}.get(sys.argv[1] if len(sys.argv) > 1 else "add", add)()
