"""Memphis's own look beyond colours: Windows 98's widgets for GTK 3, GTK 4 and Qt, drawn from the
colour scheme's system colours (face, highlight, shadow, dark shadow, title gradient, selection),
98's cursors (the white arrow, the hourglass…), and the Chicago95 icons.

Called by ~/.config/theme/writers.py on every theme switch (see writers.setup_style). The little
pictures CSS can't draw (the 50% dither, the check mark, the caption buttons' glyphs, the arrows) are
written as PNGs into the style cache and referenced by path.
"""

import os
import struct
import zlib

import iconkit

CURSOR_THEME = "Memphis-Cursors"


def k(p, key, fallback):
    return p.get(key, fallback)


def colours(p):
    """98's system colours from the palette (Memphis themes define them all)."""
    return {
        "face": k(p, "face", p["bg"]), "light": k(p, "light", "#dfdfdf"), "hi": k(p, "hilight", "#ffffff"),
        "shadow": k(p, "shadow", "#808080"), "dk": k(p, "dkShadow", "#000000"),
        "window": k(p, "window", p["bgDark"]), "wtext": k(p, "windowText", p["fg"]), "text": k(p, "btnText", p["fg"]),
        "title": k(p, "title", p["accent"]), "title2": k(p, "title2", p["purple"]), "ttext": k(p, "titleText", "#ffffff"),
        "ititle": k(p, "inactiveTitle", "#808080"), "ititle2": k(p, "inactiveTitle2", "#b5b5b5"),
        "ittext": k(p, "inactiveTitleText", "#c0c0c0"),
        "sel": k(p, "select", p["accent"]), "seltext": k(p, "selectText", "#ffffff"), "gray": k(p, "grayText", "#808080"),
        "info": k(p, "info", "#ffffe1"), "infotext": k(p, "infoText", "#000000"), "desktop": k(p, "desktop", "#008080"),
    }


# ---------------------------------------------------------------- tiny PNGs

def png(path, rows, palette):
    """rows: strings of palette keys ('.' = transparent); palette: {char: '#rrggbb'}."""
    h, w = len(rows), len(rows[0])
    raw = b""
    for r in rows:
        raw += b"\x00"
        for ch in r:
            if ch == "." or ch not in palette:
                raw += b"\x00\x00\x00\x00"
            else:
                c = palette[ch].lstrip("#")
                raw += bytes(int(c[i:i + 2], 16) for i in (0, 2, 4)) + b"\xff"

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff)
    data = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(data)
    return path


GLYPHS = {
    "close": ["##......##", ".##....##.", "..##..##..", "...####...", "....##....", "...####...", "..##..##..", ".##....##.", "##......##"],
    "min": ["........", "........", "........", "........", "........", "........", "######..", "######.."],
    "max": ["#########", "#########", "#.......#", "#.......#", "#.......#", "#.......#", "#.......#", "#.......#", "#########"],
    "up": ["....#....", "...###...", "..#####..", ".#######.", "#########"],
    "down": ["#########", ".#######.", "..#####..", "...###...", "....#...."],
    "left": ["....#", "...##", "..###", ".####", "#####", ".####", "..###", "...##", "....#"],
    "right": ["#....", "##...", "###..", "####.", "#####", "####.", "###..", "##...", "#...."],
    "check": ["........#", ".......##", "#.....###", "##...###.", "###.###..", ".#####...", "..###....", "...#....."],
    "dot": [".##.", "####", "####", ".##."],
    "dash": ["#######", "#######"],
}


def assets(p, ctx):
    """Write the pictures for this scheme; returns {name: path}."""
    c = colours(p)
    d = os.path.join(ctx["cache"], "assets-" + iconkit.palette_key(*c.values(), "memphis-assets-v1")[:8])
    out = {}
    for name, rows in GLYPHS.items():
        for tone, col in (("", c["text"]), ("-gray", c["gray"]), ("-sel", c["seltext"]), ("-win", c["wtext"])):
            path = f"{d}/{name}{tone}.png"
            out[name + tone] = path if os.path.exists(path) else png(path, [r.replace("#", "x") for r in rows], {"x": col})
    for name, a, b in (("dither", c["hi"], c["face"]), ("dither-sel", c["sel"], c["face"])):
        path = f"{d}/{name}.png"
        out[name] = path if os.path.exists(path) else png(path, ["ab", "ba"], {"a": a, "b": b})
    return out


# ---------------------------------------------------------------- GTK

def bevel(kind, c):
    """98's two-line edges as a border + an inset shadow."""
    if kind == "button":
        return (f"border: 1px solid; border-color: {c['hi']} {c['dk']} {c['dk']} {c['hi']}; "
                f"box-shadow: inset -1px -1px {c['shadow']}, inset 1px 1px {c['light']};")
    if kind == "pressed":
        return (f"border: 1px solid; border-color: {c['dk']} {c['hi']} {c['hi']} {c['dk']}; "
                f"box-shadow: inset 1px 1px {c['shadow']}, inset -1px -1px {c['light']};")
    if kind == "raised":
        return (f"border: 1px solid; border-color: {c['light']} {c['dk']} {c['dk']} {c['light']}; "
                f"box-shadow: inset -1px -1px {c['shadow']}, inset 1px 1px {c['hi']};")
    if kind == "sunken":
        return (f"border: 1px solid; border-color: {c['shadow']} {c['hi']} {c['hi']} {c['shadow']}; "
                f"box-shadow: inset 1px 1px {c['dk']}, inset -1px -1px {c['light']};")
    if kind == "status":
        return f"border: 1px solid; border-color: {c['shadow']} {c['hi']} {c['hi']} {c['shadow']}; box-shadow: none;"
    return "border: none; box-shadow: none;"


def gtk_css(p, ctx, gtk4):
    c = colours(p)
    a = assets(p, ctx)
    f = ctx["fonts"]
    url = lambda n: f'url("file://{a[n]}")'  # noqa: E731
    # GTK 4: everything under windows that aren't Walker's (it has its own Memphis theme; user CSS
    # would outrank it). GTK 3 has no Walker.
    s = "window:not(.walker) " if gtk4 else ""
    btn = f"{s}button"
    caption_buttons = f"{s}windowcontrols button" if gtk4 else "headerbar button.titlebutton, .titlebar button.titlebutton"
    check = f"{s}check" if gtk4 else "check"
    radio = f"{s}radio" if gtk4 else "radio"
    return f"""
/* Memphis: Windows 98's widgets, in the scheme's system colours */
{s}* {{
  border-radius: 0;
  -gtk-icon-shadow: none;
  text-shadow: none;
  transition: none;
  outline: none;
}}
/* 98's dotted focus rectangle, only where the keyboard is */
{s}*{':focus-visible' if gtk4 else ':focus'} {{ outline: 1px dotted {c['text']}; outline-offset: -4px; }}
{"window:not(.walker)" if gtk4 else "window"}, {s}.background, {s}dialog, {s}messagedialog .dialog-vbox {{
  background-color: {c['face']};
  color: {c['text']};
  font-family: "{f['sans']}";
}}
{s}.view, {s}textview text, {s}iconview, {s}treeview.view, {s}columnview, {s}listview, {s}.sidebar, {s}placessidebar list,
{s}scrolledwindow > viewport > list, {s}list {{
  background-color: {c['window']};
  color: {c['wtext']};
}}
{s}*:selected, {s}.view:selected, {s}treeview.view:selected, {s}row:selected, {s}text selection, {s}entry selection,
{s}label selection, {s}iconview:selected {{
  background-color: {c['sel']};
  color: {c['seltext']};
}}
{s}*:disabled, {s}label:disabled {{ color: {c['gray']}; }}
{s}row:hover {{ background-color: transparent; }}

/* ---------------------------------------------------------------- buttons */
{btn}, {s}.button, {s}combobox button, {s}spinbutton button, {s}filechooserbutton button, {s}menubutton > button,
{s}dropdown > button, {s}colorbutton > button {{
  background: {c['face']};
  background-image: none;
  color: {c['text']};
  min-height: 22px;
  min-width: 16px;
  padding: 3px 10px;
  {bevel("button", c)}
}}
{btn}:hover {{ background: {c['face']}; }}
{btn}:active, {btn}.keyboard-activating {{ {bevel("pressed", c)} padding: 4px 9px 2px 11px; }}
{btn}:checked {{ {bevel("pressed", c)} background-image: {url("dither")}; }}
{btn}:disabled {{ color: {c['gray']}; }}
{btn}.default, {btn}.suggested-action {{
  border-color: {c['dk']};
  box-shadow: inset 1px 1px {c['hi']}, inset -1px -1px {c['dk']}, inset -2px -2px {c['shadow']};
}}
{btn}.flat, {s}toolbar button, {s}.toolbar button, {s}headerbar button:not(.titlebutton), {s}.linked > button.flat,
{s}actionbar button {{
  background: transparent;
  border: 1px solid transparent;
  box-shadow: none;
}}
{btn}.flat:hover, {s}toolbar button:hover, {s}.toolbar button:hover, {s}headerbar button:not(.titlebutton):hover {{
  border-color: {c['hi']} {c['shadow']} {c['shadow']} {c['hi']};
}}
{btn}.flat:active, {btn}.flat:checked, {s}toolbar button:active, {s}toolbar button:checked,
{s}headerbar button:not(.titlebutton):active, {s}headerbar button:not(.titlebutton):checked {{
  border-color: {c['shadow']} {c['hi']} {c['hi']} {c['shadow']};
}}
{s}.linked > button, {s}.linked > entry {{ border-radius: 0; }}

/* ---------------------------------------------------------------- the caption (client-side title bars) */
{s}headerbar, {s}.titlebar:not(headerbar) {{
  background: linear-gradient(to right, {c['title']}, {c['title2']});
  color: {c['ttext']};
  min-height: 26px;
  padding: 2px 3px;
  border: none;
  box-shadow: none;
}}
{s}headerbar:backdrop, {s}.titlebar:backdrop {{
  background: linear-gradient(to right, {c['ititle']}, {c['ititle2']});
  color: {c['ittext']};
}}
{s}headerbar .title, {s}headerbar label.title, {s}.titlebar .title {{ font-weight: bold; color: inherit; }}
{s}headerbar .subtitle {{ color: inherit; opacity: 0.8; }}
{s}headerbar button:not(.titlebutton), {s}headerbar entry, {s}headerbar menubutton > button {{ color: {c['ttext']}; }}
{s}headerbar entry {{ color: {c['wtext']}; }}
{caption_buttons} {{
  background: {c['face']};
  color: {c['text']};
  min-height: 14px; min-width: 16px;
  padding: 1px 2px;
  margin: 0 0 0 2px;
  {bevel("button", c)}
}}
{caption_buttons}:active {{ {bevel("pressed", c)} }}
{caption_buttons} image {{ color: {c['text']}; -gtk-icon-size: 10px; }}
{caption_buttons.replace("button", "button.close") if gtk4 else "headerbar button.titlebutton.close"} image {{ -gtk-icon-source: -gtk-scaled({url("close")}); }}
{caption_buttons.replace("button", "button.minimize") if gtk4 else "headerbar button.titlebutton.minimize"} image {{ -gtk-icon-source: -gtk-scaled({url("min")}); }}
{caption_buttons.replace("button", "button.maximize") if gtk4 else "headerbar button.titlebutton.maximize"} image {{ -gtk-icon-source: -gtk-scaled({url("max")}); }}
{s}decoration {{ border-radius: 0; box-shadow: 0 0 0 1px {c['dk']}, inset 0 0 0 1px {c['hi']}; }}

/* ---------------------------------------------------------------- text fields */
{s}entry, {s}spinbutton:not(.vertical), {s}textview, {s}.entry, {s}searchentry, {s}passwordentry {{
  background: {c['window']};
  color: {c['wtext']};
  caret-color: {c['wtext']};
  min-height: 22px;
  padding: 2px 4px;
  {bevel("sunken", c)}
}}
{s}entry:disabled, {s}spinbutton:disabled {{ background: {c['face']}; color: {c['gray']}; }}
{s}spinbutton > text, {s}spinbutton > entry {{ border: none; box-shadow: none; background: transparent; }}
{s}spinbutton button {{ padding: 0 4px; min-height: 8px; }}

/* ---------------------------------------------------------------- check boxes, option buttons */
{check}, {radio} {{
  min-width: 13px; min-height: 13px;
  margin: 0 6px 0 0;
  background: {c['window']};
  background-image: none;
  color: {c['wtext']};
  -gtk-icon-source: none;
  {bevel("sunken", c)}
}}
{radio} {{ border-radius: 50%; box-shadow: inset 1px 1px {c['dk']}; }}
{check}:checked {{ -gtk-icon-source: -gtk-scaled({url("check-win")}); background-image: none; }}
{check}:indeterminate {{ -gtk-icon-source: -gtk-scaled({url("dash-win")}); }}
{radio}:checked {{ -gtk-icon-source: -gtk-scaled({url("dot-win")}); }}
{check}:disabled, {radio}:disabled {{ background: {c['face']}; }}
{check}:active, {radio}:active {{ background: {c['face']}; }}

/* ---------------------------------------------------------------- menus */
{s}menubar {{ background: {c['face']}; padding: 0; box-shadow: none; border: none; }}
{s}menubar > item, {s}menubar > menuitem {{ padding: 3px 8px; }}
{s}menubar > item:hover, {s}menubar > menuitem:hover {{ background: {c['sel']}; color: {c['seltext']}; }}
{s}menu, {s}.menu, {s}.context-menu, {s}popover.menu > contents, {s}popover > contents {{
  background: {c['face']};
  color: {c['text']};
  padding: 2px;
  {bevel("raised", c)}
}}
{s}popover, {s}popover.background {{ background: transparent; box-shadow: none; }}
{s}popover > arrow {{ background: none; border: none; }}
{s}menuitem, {s}menu menuitem, {s}popover.menu modelbutton, {s}popover modelbutton {{
  padding: 3px 20px 3px 20px;
  min-height: 18px;
  color: {c['text']};
  background: transparent;
}}
{s}menuitem:hover, {s}menu menuitem:hover, {s}popover.menu modelbutton:hover, {s}popover modelbutton:hover,
{s}popover.menu modelbutton:selected {{
  background: {c['sel']};
  color: {c['seltext']};
}}
{s}menuitem:disabled, {s}modelbutton:disabled {{ color: {c['gray']}; }}
{s}menu separator, {s}popover separator, {s}.menu separator {{
  min-height: 0; margin: 3px 2px; background: none;
  border-top: 1px solid {c['shadow']}; border-bottom: 1px solid {c['hi']};
}}

/* ---------------------------------------------------------------- notebooks (tabs) */
{s}notebook > header {{ background: transparent; border: none; box-shadow: none; padding: 0 2px; }}
{s}notebook > header tab {{
  background: {c['face']};
  color: {c['text']};
  padding: 2px 10px;
  margin: 2px 0 0 0;
  border: 1px solid; border-bottom: none;
  border-color: {c['hi']} {c['dk']} transparent {c['hi']};
  box-shadow: inset -1px 0 {c['shadow']};
  min-height: 18px;
}}
{s}notebook > header tab:checked {{ margin-top: 0; padding: 3px 12px 4px 12px; }}
{s}notebook > stack:not(:only-child), {s}notebook > stack {{
  background: {c['face']};
  {bevel("raised", c)}
}}

/* ---------------------------------------------------------------- lists: headers, frames */
{s}treeview.view header button, {s}columnview > header > button, {s}columnview header button {{
  background: {c['face']};
  color: {c['text']};
  padding: 2px 6px;
  {bevel("button", c)}
}}
{s}scrolledwindow.frame, {s}frame > border, {s}.frame, {s}viewport.frame {{ {bevel("sunken", c)} }}
{s}frame > label {{ color: {c['text']}; }}
{s}separator {{ background: {c['shadow']}; min-width: 1px; min-height: 1px; }}
{s}paned > separator {{ background: {c['face']}; min-width: 4px; min-height: 4px; box-shadow: none; }}

/* ---------------------------------------------------------------- scroll bars */
{s}scrollbar {{
  background: {c['face']};
  background-image: {url("dither")};
  border: none;
  box-shadow: none;
{"" if gtk4 else "  -GtkScrollbar-has-backward-stepper: true;\n  -GtkScrollbar-has-forward-stepper: true;"}
}}
{s}scrollbar.vertical {{ min-width: 16px; }}
{s}scrollbar.horizontal {{ min-height: 16px; }}
{s}scrollbar trough {{ background: transparent; border: none; min-width: 16px; min-height: 16px; }}
{s}scrollbar slider {{
  background: {c['face']};
  min-width: 12px; min-height: 16px;
  margin: 0;
  {bevel("button", c)}
}}
{s}scrollbar.vertical slider {{ min-height: 20px; }}
{s}scrollbar.horizontal slider {{ min-width: 20px; }}
{s}scrollbar button {{
  background: {c['face']};
  min-width: 14px; min-height: 14px;
  padding: 0;
  {bevel("button", c)}
}}
{s}scrollbar button:active {{ {bevel("pressed", c)} }}
{s}scrollbar.vertical button.up {{ -gtk-icon-source: -gtk-scaled({url("up")}); }}
{s}scrollbar.vertical button.down {{ -gtk-icon-source: -gtk-scaled({url("down")}); }}
{s}scrollbar.horizontal button.up {{ -gtk-icon-source: -gtk-scaled({url("left")}); }}
{s}scrollbar.horizontal button.down {{ -gtk-icon-source: -gtk-scaled({url("right")}); }}
{s}scrollbar.overlay-indicator:not(.dragging):not(.hovering) slider {{ min-width: 6px; min-height: 6px; }}
{s}undershoot, {s}overshoot {{ background: none; }}

/* ---------------------------------------------------------------- sliders, progress, switches */
{s}scale trough {{
  background: {c['face']};
  min-height: 4px; min-width: 4px;
  {bevel("sunken", c)}
}}
{s}scale highlight {{ background: transparent; }}
{s}scale slider {{
  background: {c['face']};
  min-width: 11px; min-height: 21px;
  margin: -9px 0;
  {bevel("button", c)}
}}
{s}scale.vertical slider {{ min-width: 21px; min-height: 11px; margin: 0 -9px; }}
{s}progressbar trough {{
  background: {c['face']};
  min-height: 18px;
  {bevel("status", c)}
}}
{s}progressbar progress {{
  background-color: transparent;
  background-image: repeating-linear-gradient(to right, {c['sel']} 0px, {c['sel']} 9px, transparent 9px, transparent 11px);
  min-height: 14px;
  margin: 2px;
  border: none;
}}
{s}levelbar block.filled {{ background: {c['sel']}; }}
{s}levelbar block.empty {{ background: {c['window']}; }}
{s}switch {{
  background: {c['window']};
  min-width: 40px; min-height: 18px;
  {bevel("sunken", c)}
}}
{s}switch:checked {{ background: {c['sel']}; }}
{s}switch slider {{ background: {c['face']}; min-width: 18px; min-height: 16px; {bevel("button", c)} }}

/* ---------------------------------------------------------------- combo boxes */
{s}combobox button.combo, {s}dropdown > button {{ background: {c['window']}; color: {c['wtext']}; {bevel("sunken", c)} padding: 2px 2px 2px 5px; }}
{s}combobox arrow, {s}dropdown arrow, {s}menubutton arrow {{
  -gtk-icon-source: -gtk-scaled({url("down")});
  min-width: 16px; min-height: 16px;
  background: {c['face']};
  {bevel("button", c)}
}}

/* ---------------------------------------------------------------- tooltips, info, sidebar */
{s}tooltip, tooltip, tooltip.background {{
  background: {c['info']};
  color: {c['infotext']};
  border: 1px solid {c['dk']};
  border-radius: 0;
  box-shadow: none;
  padding: 2px 4px;
}}
{s}tooltip * {{ color: {c['infotext']}; }}
{s}infobar, {s}.app-notification {{ background: {c['info']}; color: {c['infotext']}; border: 1px solid {c['dk']}; }}
{s}.sidebar row:selected, {s}placessidebar row:selected {{ background: {c['sel']}; color: {c['seltext']}; }}
{s}statusbar, {s}.statusbar {{ {bevel("status", c)} padding: 2px 6px; }}
{s}actionbar, {s}toolbar, {s}.toolbar, {s}searchbar > revealer > box {{ background: {c['face']}; border: none; box-shadow: none; }}
{s}.dim-label {{ color: {c['gray']}; opacity: 1; }}
{s}link, {s}*:link {{ color: #0000ff; }}
"""


def gtk3(p, ctx):
    return gtk_css(p, ctx, False)


def gtk4(p, ctx):
    return gtk_css(p, ctx, True) + f"""
:root {{
  --window-radius: 0;
  --accent-color: {colours(p)['sel']};
  --accent-bg-color: {colours(p)['sel']};
}}
"""


def satty(p, ctx):
    """Satty (the screenshot editor, GTK 4): Memphis's widgets, plus its toolbars as raised strips."""
    c = colours(p)
    return gtk_css(p, ctx, False) + f"""
.toolbar {{ background: {c['face']}; padding: 2px; {bevel("raised", c)} }}
.toolbar button:checked, .toolbar button.editing {{ {bevel("pressed", c)} background-image: url("file://{assets(p, ctx)['dither']}"); }}
"""


# ---------------------------------------------------------------- Qt (qt6ct stylesheet)

def qss(p, ctx):
    c = colours(p)
    a = assets(p, ctx)
    f = ctx["fonts"]

    def edge(tl, br):
        return f"border: 2px solid; border-top-color: {tl}; border-left-color: {tl}; border-bottom-color: {br}; border-right-color: {br};"
    return f"""/* Memphis: Windows 98's widgets for Qt apps (qt6ct) */
* {{ font-family: "{f['sans']}"; }}
QWidget {{ background-color: {c['face']}; color: {c['text']}; selection-background-color: {c['sel']}; selection-color: {c['seltext']}; }}
QMainWindow, QDialog {{ background-color: {c['face']}; }}
QPushButton, QToolButton:checked, QComboBox {{
  background-color: {c['face']}; {edge(c['hi'], c['dk'])} padding: 3px 12px; min-height: 18px;
}}
QPushButton:pressed, QPushButton:checked {{ {edge(c['dk'], c['hi'])} padding: 4px 11px 2px 13px; }}
QPushButton:default {{ border-color: {c['dk']}; }}
QPushButton:disabled, QLabel:disabled, QCheckBox:disabled {{ color: {c['gray']}; }}
QToolButton {{ background: transparent; border: 1px solid transparent; padding: 3px; }}
QToolButton:hover {{ border-top-color: {c['hi']}; border-left-color: {c['hi']}; border-bottom-color: {c['shadow']}; border-right-color: {c['shadow']}; }}
QToolButton:pressed, QToolButton:checked {{ {edge(c['shadow'], c['hi'])} }}
QLineEdit, QTextEdit, QPlainTextEdit, QSpinBox, QDoubleSpinBox, QListView, QTreeView, QTableView, QListWidget, QTreeWidget, QTableWidget {{
  background-color: {c['window']}; color: {c['wtext']}; {edge(c['shadow'], c['hi'])}
}}
QComboBox {{ background-color: {c['window']}; color: {c['wtext']}; {edge(c['shadow'], c['hi'])} padding: 2px 4px; }}
QComboBox::drop-down {{ width: 16px; background: {c['face']}; {edge(c['hi'], c['dk'])} }}
QComboBox::down-arrow {{ image: url({a['down']}); }}
QComboBox QAbstractItemView {{ background: {c['window']}; color: {c['wtext']}; border: 1px solid {c['dk']}; }}
QHeaderView::section {{ background: {c['face']}; color: {c['text']}; {edge(c['hi'], c['dk'])} padding: 2px 6px; }}
QMenuBar {{ background: {c['face']}; }}
QMenuBar::item {{ padding: 3px 8px; background: transparent; }}
QMenuBar::item:selected, QMenu::item:selected {{ background: {c['sel']}; color: {c['seltext']}; }}
QMenu {{ background: {c['face']}; {edge(c['light'], c['dk'])} padding: 2px; }}
QMenu::item {{ padding: 3px 24px 3px 20px; }}
QMenu::separator {{ height: 2px; background: {c['shadow']}; border-bottom: 1px solid {c['hi']}; margin: 3px 2px; }}
QTabWidget::pane {{ {edge(c['hi'], c['dk'])} top: -2px; }}
QTabBar::tab {{ background: {c['face']}; border: 2px solid; border-bottom: none; border-top-color: {c['hi']}; border-left-color: {c['hi']}; border-right-color: {c['dk']}; padding: 3px 12px; margin-top: 2px; }}
QTabBar::tab:selected {{ margin-top: 0; padding-bottom: 5px; }}
QGroupBox {{ border: 1px solid {c['shadow']}; margin-top: 10px; padding-top: 6px; }}
QGroupBox::title {{ subcontrol-origin: margin; left: 8px; padding: 0 3px; }}
QCheckBox::indicator, QRadioButton::indicator {{ width: 13px; height: 13px; background: {c['window']}; {edge(c['shadow'], c['hi'])} }}
QCheckBox::indicator:checked {{ image: url({a['check-win']}); }}
QRadioButton::indicator {{ border-radius: 7px; }}
QRadioButton::indicator:checked {{ image: url({a['dot-win']}); }}
QScrollBar:vertical {{ width: 16px; background: url({a['dither']}); }}
QScrollBar:horizontal {{ height: 16px; background: url({a['dither']}); }}
QScrollBar::handle {{ background: {c['face']}; {edge(c['hi'], c['dk'])} min-height: 16px; min-width: 16px; }}
QScrollBar::add-line, QScrollBar::sub-line {{ background: {c['face']}; {edge(c['hi'], c['dk'])} width: 12px; height: 12px; subcontrol-origin: margin; }}
QScrollBar::add-page, QScrollBar::sub-page {{ background: none; }}
QScrollBar::up-arrow {{ image: url({a['up']}); }}
QScrollBar::down-arrow {{ image: url({a['down']}); }}
QScrollBar::left-arrow {{ image: url({a['left']}); }}
QScrollBar::right-arrow {{ image: url({a['right']}); }}
QSlider::groove:horizontal {{ height: 4px; {edge(c['shadow'], c['hi'])} }}
QSlider::handle:horizontal {{ width: 11px; margin: -9px 0; background: {c['face']}; {edge(c['hi'], c['dk'])} }}
QProgressBar {{ {edge(c['shadow'], c['hi'])} background: {c['face']}; text-align: center; }}
QProgressBar::chunk {{ background: {c['sel']}; width: 9px; margin: 1px; }}
QToolTip {{ background: {c['info']}; color: {c['infotext']}; border: 1px solid {c['dk']}; padding: 2px; }}
QStatusBar {{ background: {c['face']}; }}
QStatusBar::item {{ {edge(c['shadow'], c['hi'])} }}
QToolBar {{ background: {c['face']}; border: none; spacing: 2px; }}
"""


# ---------------------------------------------------------------- icons

def icons(p, ctx):
    """Chicago95 (Windows 95's icons, redrawn) when it's installed, else Papirus."""
    for d in ("/usr/share/icons", os.path.expanduser("~/.local/share/icons"), os.path.expanduser("~/.icons")):
        if os.path.isfile(f"{d}/Chicago95/index.theme"):
            return "Chicago95"
    return "Papirus-Dark" if ctx.get("appearance") == "dark" else "Papirus"


# ---------------------------------------------------------------- cursors

# 98's cursors, pixel for pixel on a 32 grid (# = black, o = white, . = clear)
ARROW = [
    "#", "##", "#o#", "#oo#", "#ooo#", "#oooo#", "#ooooo#", "#oooooo#", "#ooooooo#", "#oooooooo#",
    "#ooooo#####", "#oo#oo#", "#o# #oo#", "##  #oo#", "#    #oo#", "     #oo#", "      #oo#", "      #oo#", "       ##",
]
HAND = [
    "     ##", "    #oo#", "    #oo#", "    #oo#", "    #oo###", "    #oo#oo###", "    #oo#oo#oo##", " ## #oo#oo#oo#o#",
    "#oo##oooooooo#o#", "#ooo#oooooooooo#", " #oo#oooooooooo#", "  #ooooooooooooo#", "  #oooooooooooo#", "   #ooooooooooo#",
    "   #oooooooooo#", "    #oooooooo#", "    #oooooooo#", "    ##########",
]
IBEAM = ["###.###", "...#...", "...#...", "...#...", "...#...", "...#...", "...#...", "...#...", "...#...",
         "...#...", "...#...", "...#...", "...#...", "...#...", "...#...", "###.###"]
GLASS = [
    "#############", "#ooooooooooo#", " #o#o#o#o#o# ", " #oo#o#o#oo# ", "  #oo#o#oo#  ", "   #oo#oo#   ", "    #ooo#    ",
    "     #o#     ", "    #ooo#    ", "   #oo#oo#   ", "  #ooo#ooo#  ", " #ooo#o#ooo# ", " #oo#o#o#oo# ", "#ooooooooooo#",
    "#############",
]
NO = [
    "     #######     ", "   ##ooooooo##   ", "  #oo#######oo#  ", " #o##       ##o# ", " #o#        ##o# ", "#o#        #o#o#",
    "#o#       #o# #o#", "#o#      #o#  #o#", "#o#     #o#   #o#", "#o#    #o#    #o#", "#o#   #o#     #o#", "#o#  #o#      #o#",
    "#o# #o#       #o#", " #o#o#       ##o# ", " #o##       ##o# ", "  #oo#######oo#  ", "   ##ooooooo##   ", "     #######     ",
]


def pixels(rows, x0, y0, cell=2):
    out = []
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in "#o":
                col = "#000000" if ch == "#" else "#ffffff"
                out.append(f'<rect x="{(x0 + x) * cell}" y="{(y0 + y) * cell}" width="{cell}" height="{cell}" fill="{col}"/>')
    return "".join(out)


def _shapes():
    def svg(body):
        return ('<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64" '
                f'shape-rendering="crispEdges">{body}</svg>')

    def arrow(extra=""):
        return lambda f, n: svg(pixels(ARROW, 0, 0) + extra)

    def poly(points):
        """A white arrow with a black 1 px (2-unit) outline, from points on the 32 grid."""
        pts = " ".join(f"{x * 2},{y * 2}" for x, y in points)
        return f'<polygon points="{pts}" fill="#ffffff" stroke="#000000" stroke-width="2" stroke-linejoin="miter"/>'

    ns = [(16, 3), (22, 9), (18, 9), (18, 23), (22, 23), (16, 29), (10, 23), (14, 23), (14, 9), (10, 9)]

    def rot(points, angle):
        import math
        a = math.radians(angle)
        return [(16 + (x - 16) * math.cos(a) - (y - 16) * math.sin(a), 16 + (x - 16) * math.sin(a) + (y - 16) * math.cos(a))
                for x, y in points]

    move = [(16, 2), (20, 6), (17, 6), (17, 15), (26, 15), (26, 12), (30, 16), (26, 20), (26, 17), (17, 17), (17, 26),
            (20, 26), (16, 30), (12, 26), (15, 26), (15, 17), (6, 17), (6, 20), (2, 16), (6, 12), (6, 15), (15, 15),
            (15, 6), (12, 6)]
    cross = ('<path d="M31 2 V26 M31 38 V62 M2 31 H26 M38 31 H62" stroke="#ffffff" stroke-width="6"/>'
             '<path d="M31 2 V26 M31 38 V62 M2 31 H26 M38 31 H62" stroke="#000000" stroke-width="2"/>')
    return {
        "arrow": (arrow(), (1, 1), 1),
        "pointer": (lambda f, n: svg(pixels(HAND, 2, 0)), (12, 1), 1),
        "text": (lambda f, n: svg(pixels([r.replace("#", "o") for r in IBEAM], 11, 7) + pixels(IBEAM, 12, 8)), (31, 31), 1),
        "crosshair": (lambda f, n: svg(cross), (31, 31), 1),
        "wait": (lambda f, n: svg(pixels(GLASS, 9, 8)), (31, 31), 1),
        "progress": (arrow(pixels(GLASS, 14, 14)), (1, 1), 1),
        "move": (lambda f, n: svg(poly(move)), (32, 32), 1),
        "ns": (lambda f, n: svg(poly(ns)), (32, 32), 1),
        "ew": (lambda f, n: svg(poly(rot(ns, 90))), (32, 32), 1),
        "nwse": (lambda f, n: svg(poly(rot(ns, -45))), (32, 32), 1),
        "nesw": (lambda f, n: svg(poly(rot(ns, 45))), (32, 32), 1),
        "forbidden": (lambda f, n: svg(pixels(NO, 7, 7)), (32, 32), 1),
        "help": (arrow(pixels(["#######", "#ooooo#", "#o###o#", "#ooo#o#", "#oo#oo#", "#ooooo#", "#oo#oo#", "#######"], 12, 12)), (1, 1), 1),
        "copy": (arrow(pixels(["#########", "#ooooooo#", "#ooo#ooo#", "#ooo#ooo#", "#o#####o#", "#ooo#ooo#", "#ooo#ooo#", "#ooooooo#", "#########"], 12, 13)), (1, 1), 1),
        "link": (arrow(pixels(["#########", "#ooooooo#", "#oo#####", "#ooo##o#", "#oo#o#o#", "#o#oooo#", "#ooooooo#", "#########"], 12, 13)), (1, 1), 1),
    }


def cursors(p, ctx):
    """98's black-and-white cursors (they didn't follow the colour scheme then either)."""
    return iconkit.cursor_theme(CURSOR_THEME, "Windows 98's cursors, pixel for pixel (written by the Memphis setup)",
                                _shapes(), iconkit.palette_key("memphis-cursors-v1"))
