"""Netrunner's look beyond colours: GTK 3/4, Qt and Satty as a deck's panels (near-black glass,
hairline edges, square corners, the accent (red) for focus and selection, the second colour (cyan)
for links and progress), Papirus-Dark with folders in the profile's colours, and cut-corner
targeting cursors.

Called by ~/.config/theme/writers.py on every profile switch (see writers.setup_style).
"""

import iconkit

ICON_THEME = "Netrunner"
CURSOR_THEME = "Netrunner-Cursors"


def gtk_css(p, ctx, gtk4):
    rgba, mix = ctx["rgba"], ctx["mix"]
    f = ctx["fonts"]
    red, cyan, bg, dark, fg, dim, line = p["accent"], p["purple"], p["bg"], p["bgDark"], p["fg"], p["dim"], p["border"]
    surf, hover, onred = p["surface"], p["hover"], p["accentText"]
    # GTK 4: widget rules only inside windows that aren't Walker's (it has its own theme; user CSS
    # would outrank it)
    s = "window:not(.walker) " if gtk4 else ""
    win = "window:not(.walker)" if gtk4 else "window"
    return f"""
/* Netrunner: a deck's panels */
{s}* {{ border-radius: 0; -gtk-icon-shadow: none; text-shadow: none; outline-color: {rgba(red, 0.7)}; outline-offset: -2px; }}
{win}, {s}.background, {s}dialog {{ background-color: {bg}; color: {fg}; }}
{s}.view, {s}textview text, {s}iconview, {s}treeview.view, {s}columnview, {s}listview, {s}list, {s}scrolledwindow > viewport > list {{
  background-color: {dark}; color: {fg};
}}
{s}.sidebar, {s}placessidebar, {s}placessidebar list, {s}.navigation-sidebar {{ background-color: {mix(bg, dark, 0.5)}; }}
{s}*:selected, {s}row:selected, {s}.view:selected, {s}treeview.view:selected, {s}iconview:selected, {s}text selection, {s}entry selection, {s}label selection {{
  background-color: {rgba(red, 0.28)}; color: {p.get("bright", fg)};
}}
{s}row:selected {{ box-shadow: inset 2px 0 {red}; }}
{s}row:hover {{ background-color: {rgba(fg, 0.04)}; }}
{s}*:disabled {{ color: {rgba(dim, 0.7)}; }}
{s}.dim-label {{ color: {dim}; opacity: 1; }}
{s}link, {s}*:link {{ color: {cyan}; }}

/* buttons: outlined; hover lights the edge red */
{s}button {{
  background: {rgba(dark, 0.6)}; background-image: none; color: {fg};
  border: 1px solid {line}; box-shadow: none; padding: 4px 12px; min-height: 22px;
}}
{s}button:hover {{ border-color: {red}; background: {rgba(red, 0.08)}; }}
{s}button:active, {s}button:checked {{ background: {rgba(red, 0.22)}; border-color: {red}; color: {p.get("bright", fg)}; }}
{s}button.suggested-action, {s}button.default {{ background: {red}; color: {onred}; border-color: {red}; }}
{s}button.suggested-action:hover {{ background: {mix(red, "#ffffff", 0.15)}; }}
{s}button.destructive-action {{ border-color: {red}; color: {red}; }}
{s}button.flat, {s}headerbar button, {s}toolbar button, {s}.toolbar button {{ background: transparent; border-color: transparent; }}
{s}button.flat:hover, {s}headerbar button:hover, {s}toolbar button:hover {{ border-color: {line}; background: {rgba(fg, 0.05)}; }}

/* the title bar (client-side decorations): dark, a red rule under it */
{s}headerbar, {s}.titlebar {{
  background: {dark}; color: {fg}; min-height: 38px; border: none;
  box-shadow: inset 0 -1px {line}, inset 90px -2px 0 -88px {red};
}}
{s}headerbar:backdrop, {s}.titlebar:backdrop {{ box-shadow: inset 0 -1px {line}; color: {dim}; }}
{s}headerbar .title {{ font-weight: bold; letter-spacing: 1px; }}
{s}decoration {{ border-radius: 0; box-shadow: 0 0 0 1px {line}, 0 8px 24px rgba(0,0,0,0.6); }}

/* fields: dark, red rule on the left when focused */
{s}entry, {s}spinbutton:not(.vertical), {s}searchentry, {s}passwordentry {{
  background: {dark}; color: {fg}; caret-color: {red};
  border: 1px solid {line}; box-shadow: none; padding: 4px 8px; min-height: 22px;
}}
{s}entry:focus, {s}entry:focus-within, {s}spinbutton:focus-within {{ border-color: {red}; box-shadow: inset 2px 0 {red}; }}

/* check boxes, radios, switches */
{s}check, {s}radio {{
  background: {dark}; background-image: none; border: 1px solid {dim}; min-width: 14px; min-height: 14px;
  -gtk-icon-source: none; color: {onred};
}}
{s}radio {{ border-radius: 0; }}
{s}check:checked, {s}radio:checked {{ background: {red}; border-color: {red}; box-shadow: inset 0 0 0 3px {dark}; }}
{s}switch {{ background: {dark}; border: 1px solid {line}; min-width: 40px; min-height: 18px; }}
{s}switch:checked {{ background: {rgba(red, 0.3)}; border-color: {red}; }}
{s}switch slider {{ background: {dim}; min-width: 16px; min-height: 16px; border: none; box-shadow: none; }}
{s}switch:checked slider {{ background: {red}; }}

/* menus and popovers: dark glass, red hover bar */
{s}menu, {s}.menu, {s}.context-menu, {s}popover > contents, {s}popover.menu > contents {{
  background: {rgba(dark, 0.97)}; color: {fg}; border: 1px solid {line}; box-shadow: 0 8px 24px rgba(0,0,0,0.6); padding: 4px;
}}
{s}popover, {s}popover.background {{ background: transparent; box-shadow: none; }}
{s}popover > arrow {{ background: none; border: none; }}
{s}menuitem, {s}modelbutton {{ padding: 5px 14px; }}
{s}menuitem:hover, {s}modelbutton:hover, {s}popover.menu modelbutton:selected {{ background: {rgba(red, 0.2)}; box-shadow: inset 2px 0 {red}; }}
{s}menubar {{ background: {bg}; box-shadow: inset 0 -1px {line}; }}
{s}menubar > item:hover, {s}menubar > menuitem:hover {{ box-shadow: inset 0 -2px {red}; }}
{s}separator {{ background: {line}; min-width: 1px; min-height: 1px; }}

/* tabs: the current one underlined red */
{s}notebook > header {{ background: {bg}; border: none; box-shadow: inset 0 -1px {line}; }}
{s}notebook > header tab {{ padding: 6px 14px; color: {dim}; border: none; }}
{s}notebook > header tab:checked {{ color: {fg}; box-shadow: inset 0 -2px {red}; }}
{s}notebook > stack {{ background: {bg}; }}

/* lists' column headers, frames */
{s}treeview.view header button, {s}columnview > header > button {{ background: {bg}; border: none; border-bottom: 1px solid {line}; color: {dim}; padding: 4px 8px; }}
{s}scrolledwindow.frame, {s}frame > border, {s}.frame {{ border: 1px solid {line}; }}

/* scroll bars: a thin rail, the slider lights red */
{s}scrollbar {{ background: transparent; border: none; }}
{s}scrollbar slider {{ background: {rgba(dim, 0.55)}; border: none; min-width: 4px; min-height: 4px; margin: 2px; }}
{s}scrollbar slider:hover, {s}scrollbar slider:active {{ background: {red}; }}

/* scales, progress: blocks of cyan */
{s}scale trough {{ background: {rgba(dim, 0.3)}; min-height: 3px; min-width: 3px; border: none; }}
{s}scale highlight {{ background: {cyan}; }}
{s}scale slider {{ background: {red}; min-width: 6px; min-height: 16px; border: none; margin: -7px 0; }}
{s}progressbar trough {{ background: {rgba(dim, 0.25)}; min-height: 6px; border: none; }}
{s}progressbar progress {{ background-color: transparent; border: none; min-height: 6px;
  background-image: repeating-linear-gradient(to right, {cyan} 0px, {cyan} 6px, transparent 6px, transparent 8px); }}
{s}levelbar block.filled {{ background: {cyan}; }}

/* tooltips, notices */
{s}tooltip, tooltip, tooltip.background {{ background: {rgba(dark, 0.96)}; color: {fg}; border: 1px solid {red}; border-radius: 0; }}
{s}infobar, {s}.app-notification {{ background: {surf}; border: 1px solid {line}; box-shadow: inset 2px 0 {cyan}; }}
{s}statusbar, {s}.statusbar {{ color: {dim}; }}
{s}combobox button.combo, {s}dropdown > button {{ background: {dark}; }}
"""


def gtk3(p, ctx):
    return gtk_css(p, ctx, False)


def gtk4(p, ctx):
    return gtk_css(p, ctx, True) + f"""
:root {{ --window-radius: 0; --accent-color: {p["accent"]}; --accent-bg-color: {p["accent"]}; }}
"""


def satty(p, ctx):
    rgba = ctx["rgba"]
    red = p["accent"]
    return gtk_css(p, ctx, False) + f"""
.toolbar {{ background: {rgba(p["bgDark"], 0.95)}; border: 1px solid {p["border"]}; box-shadow: 0 8px 24px rgba(0,0,0,0.6); }}
.toolbar button:checked, .toolbar button.editing {{ background: {rgba(red, 0.25)}; box-shadow: inset 0 -2px {red}; }}
"""


def qss(p, ctx):
    rgba = ctx["rgba"]
    red, cyan, bg, dark, fg, dim, line = p["accent"], p["purple"], p["bg"], p["bgDark"], p["fg"], p["dim"], p["border"]
    return f"""/* Netrunner: a deck's panels, for Qt apps (qt6ct) */
QWidget {{ background-color: {bg}; color: {fg}; selection-background-color: {rgba(red, 0.35)}; selection-color: {fg}; }}
QPushButton, QToolButton {{ background: {dark}; border: 1px solid {line}; padding: 4px 12px; }}
QPushButton:hover, QToolButton:hover {{ border-color: {red}; }}
QPushButton:pressed, QPushButton:checked, QToolButton:checked {{ background: {rgba(red, 0.25)}; border-color: {red}; }}
QPushButton:default {{ background: {red}; color: {p["accentText"]}; border-color: {red}; }}
QLineEdit, QTextEdit, QPlainTextEdit, QSpinBox, QDoubleSpinBox, QComboBox {{ background: {dark}; border: 1px solid {line}; padding: 3px 6px; }}
QLineEdit:focus, QTextEdit:focus, QComboBox:focus {{ border-color: {red}; }}
QListView, QTreeView, QTableView, QListWidget, QTreeWidget, QTableWidget {{ background: {dark}; border: 1px solid {line}; alternate-background-color: {p["surface"]}; }}
QHeaderView::section {{ background: {bg}; color: {dim}; border: none; border-bottom: 1px solid {line}; padding: 4px 8px; }}
QMenuBar {{ background: {bg}; border-bottom: 1px solid {line}; }}
QMenuBar::item:selected {{ border-bottom: 2px solid {red}; background: transparent; }}
QMenu {{ background: {dark}; border: 1px solid {line}; padding: 4px; }}
QMenu::item {{ padding: 5px 20px; }}
QMenu::item:selected {{ background: {rgba(red, 0.22)}; border-left: 2px solid {red}; }}
QMenu::separator {{ height: 1px; background: {line}; margin: 4px 6px; }}
QTabBar::tab {{ background: {bg}; color: {dim}; padding: 6px 14px; border: none; }}
QTabBar::tab:selected {{ color: {fg}; border-bottom: 2px solid {red}; }}
QTabWidget::pane {{ border: 1px solid {line}; }}
QGroupBox {{ border: 1px solid {line}; margin-top: 12px; padding-top: 8px; }}
QGroupBox::title {{ subcontrol-origin: margin; left: 10px; padding: 0 4px; color: {red}; }}
QCheckBox::indicator, QRadioButton::indicator {{ width: 13px; height: 13px; background: {dark}; border: 1px solid {dim}; }}
QCheckBox::indicator:checked, QRadioButton::indicator:checked {{ background: {red}; border-color: {red}; }}
QScrollBar:vertical {{ width: 8px; background: transparent; }}
QScrollBar:horizontal {{ height: 8px; background: transparent; }}
QScrollBar::handle {{ background: {rgba(dim, 0.6)}; min-height: 20px; min-width: 20px; }}
QScrollBar::handle:hover {{ background: {red}; }}
QScrollBar::add-line, QScrollBar::sub-line, QScrollBar::add-page, QScrollBar::sub-page {{ background: none; border: none; width: 0; height: 0; }}
QSlider::groove:horizontal {{ height: 3px; background: {rgba(dim, 0.35)}; }}
QSlider::sub-page:horizontal {{ background: {cyan}; }}
QSlider::handle:horizontal {{ width: 6px; margin: -7px 0; background: {red}; }}
QProgressBar {{ background: {dark}; border: 1px solid {line}; text-align: center; }}
QProgressBar::chunk {{ background: {cyan}; width: 6px; margin: 1px; }}
QToolTip {{ background: {dark}; color: {fg}; border: 1px solid {red}; padding: 3px; }}
QStatusBar {{ color: {dim}; }}
"""


def icons(p, ctx):
    """Papirus-Dark with its blue folders in the profile's colours (front: accent, back: darker)."""
    mix = ctx["mix"]
    front, back = p["accent"], mix(p["accent"], p["bgDark"], 0.55)
    glyph = p["bgDark"]
    recolor = {"#5294e2": front, "#4877b1": back, "#e4e4e4": glyph, "#ffffff": glyph}

    def draw(a):
        svg = a["svg"]
        for old, new in recolor.items():
            svg = svg.replace(old, new).replace(old.upper(), new)
        return svg

    return iconkit.folder_theme(ICON_THEME, "Papirus-Dark with folders in the profile's accent (written by the Netrunner setup)",
                                draw, iconkit.palette_key(front, back, glyph, "netrunner-icons-v1"), "Papirus-Dark,Adwaita,hicolor")


def _shapes(p):
    """Cut-corner targeting cursors: a dark body with the accent edge, a cyan tick on some."""
    red, cyan, ink = p["accent"], p["purple"], "#05070a"
    fg = p.get("bright", p["fg"])

    def svg(body):
        return f'<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">{body}</svg>'

    arrow_path = "M6 4 L6 46 L17 36 L26 56 L34 52 L25 33 L40 33 Z"

    def arrow(extra=""):
        return lambda f, n: svg(f'<path d="{arrow_path}" fill="{ink}" stroke="{red}" stroke-width="3" stroke-linejoin="miter"/>'
                                f'<path d="M9 11 L9 22" stroke="{cyan}" stroke-width="2"/>' + extra)

    def brackets(color, inner=""):
        # four corner brackets round the centre: a lock-on reticle
        b = "".join(f'<path d="{d}" fill="none" stroke="{color}" stroke-width="3"/>' for d in
                    ["M10 22 V10 H22", "M42 10 H54 V22", "M54 42 V54 H42", "M22 54 H10 V42"])
        return svg(b + inner)

    def spinner(f, n):
        a = f * 360 / n
        return (f'<g transform="rotate({a} 32 32)"><path d="M32 12 A20 20 0 0 1 52 32" fill="none" stroke="{red}" stroke-width="4"/>'
                f'<path d="M32 52 A20 20 0 0 1 12 32" fill="none" stroke="{cyan}" stroke-width="4"/></g>')

    def double(angle):
        body = (f'<g transform="rotate({angle} 32 32)"><path d="M32 4 L44 18 L36 18 L36 46 L44 46 L32 60 L20 46 L28 46 L28 18 L20 18 Z" '
                f'fill="{ink}" stroke="{red}" stroke-width="3" stroke-linejoin="miter"/></g>')
        return lambda f, n: svg(body)

    return {
        "arrow": (arrow(), (6, 4), 1),
        "pointer": (lambda f, n: svg(f'<path d="{arrow_path}" fill="{red}" stroke="{ink}" stroke-width="3" stroke-linejoin="miter"/>'), (6, 4), 1),
        "text": (lambda f, n: svg(f'<path d="M22 8 H42 M32 8 V56 M22 56 H42" stroke="{ink}" stroke-width="8" fill="none"/>'
                                  f'<path d="M22 8 H42 M32 8 V56 M22 56 H42" stroke="{fg}" stroke-width="3" fill="none"/>'
                                  f'<rect x="30" y="28" width="4" height="8" fill="{red}"/>'), (32, 32), 1),
        "crosshair": (lambda f, n: brackets(red, f'<rect x="30" y="30" width="4" height="4" fill="{cyan}"/>'), (32, 32), 1),
        "wait": (lambda f, n: svg(spinner(f, n)), (32, 32), 12),
        "progress": (lambda f, n: arrow(f'<g transform="translate(34 34) scale(0.45)">{spinner(f, n)}</g>')(f, n), (6, 4), 12),
        "move": (lambda f, n: brackets(cyan, f'<path d="M32 18 V46 M18 32 H46" stroke="{red}" stroke-width="3"/>'), (32, 32), 1),
        "ns": (double(0), (32, 32), 1),
        "ew": (double(90), (32, 32), 1),
        "nwse": (double(-45), (32, 32), 1),
        "nesw": (double(45), (32, 32), 1),
        "forbidden": (lambda f, n: brackets(red, f'<path d="M20 20 L44 44 M44 20 L20 44" stroke="{red}" stroke-width="4"/>'), (32, 32), 1),
        "help": (arrow(f'<rect x="38" y="38" width="22" height="22" fill="{ink}" stroke="{cyan}" stroke-width="2"/>'
                       f'<text x="49" y="56" font-family="monospace" font-weight="bold" font-size="17" text-anchor="middle" fill="{cyan}">?</text>'), (6, 4), 1),
        "copy": (arrow(f'<rect x="38" y="38" width="22" height="22" fill="{ink}" stroke="{cyan}" stroke-width="2"/>'
                       f'<path d="M49 42 V56 M42 49 H56" stroke="{cyan}" stroke-width="3"/>'), (6, 4), 1),
        "link": (arrow(f'<rect x="38" y="38" width="22" height="22" fill="{ink}" stroke="{cyan}" stroke-width="2"/>'
                       f'<path d="M43 55 L55 43 M46 43 H55 V52" stroke="{cyan}" stroke-width="3" fill="none"/>'), (6, 4), 1),
    }


def cursors(p, ctx):
    key = iconkit.palette_key(p["accent"], p["purple"], p.get("bright", p["fg"]), "netrunner-cursors-v1")
    return iconkit.cursor_theme(CURSOR_THEME, "Cut-corner targeting cursors in the profile's colours (written by the Netrunner setup)",
                                _shapes(p), key)
