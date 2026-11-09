"""Glyph's look beyond colours (after Nothing OS): GTK 3/4, Qt and Satty as Nothing's panels: flat
greys, generous round corners, pills for buttons and fields, the selected thing a white pill with ink
text (black in Light), the caret and destructive actions red and nothing else red; Papirus with
folders in the theme's greys; and dot cursors: an arrow outlined in dots, a ring of dots for busy.

Called by ~/.config/theme/writers.py on every theme switch (see writers.setup_style).
"""

import math

import iconkit

ICON_THEME = "Glyph"
CURSOR_THEME = "Glyph-Cursors"


def gtk_css(p, ctx, gtk4):
    rgba, mix = ctx["rgba"], ctx["mix"]
    fg, bg, s1, s2, s3 = p["fg"], p["bg"], p["s1"], p["s2"], p["s3"]
    mute, grey, ink, red = p["mute"], p["grey"], p["ink"], p["red"]
    # GTK 4: widget rules only inside windows that aren't Walker's (user CSS would outrank its theme)
    s = "window:not(.walker) " if gtk4 else ""
    win = "window:not(.walker)" if gtk4 else "window"
    return f"""
/* Glyph: Nothing's panels */
{s}* {{ -gtk-icon-shadow: none; text-shadow: none; outline-color: {rgba(fg, 0.5)}; outline-offset: -2px; }}
{win}, {s}.background, {s}dialog {{ background-color: {s1}; color: {fg}; }}
{s}.view, {s}textview text, {s}iconview, {s}treeview.view, {s}columnview, {s}listview, {s}list, {s}scrolledwindow > viewport > list {{
  background-color: {s1}; color: {fg};
}}
{s}.sidebar, {s}placessidebar, {s}placessidebar list, {s}.navigation-sidebar {{ background-color: {bg}; }}
{s}*:selected, {s}.view:selected, {s}treeview.view:selected, {s}iconview:selected, {s}text selection, {s}entry selection, {s}label selection {{
  background-color: {fg}; color: {ink};
}}
{s}row {{ border-radius: 14px; }}
{s}row:selected {{ background-color: {fg}; color: {ink}; }}
{s}row:selected label, {s}row:selected image {{ color: {ink}; }}
{s}row:hover:not(:selected) {{ background-color: {s2}; }}
{s}*:disabled {{ color: {mute}; }}
{s}.dim-label {{ color: {grey}; opacity: 1; }}
{s}link, {s}*:link {{ color: {fg}; text-decoration: underline; }}

/* buttons: dark pills; checked / suggested = the white pill */
{s}button {{
  background: {s2}; background-image: none; color: {fg}; border-radius: 999px;
  border: none; box-shadow: none; padding: 5px 16px; min-height: 24px;
}}
{s}button:hover {{ background: {s3}; }}
{s}button:active, {s}button:checked {{ background: {fg}; color: {ink}; }}
{s}button.suggested-action, {s}button.default {{ background: {fg}; color: {ink}; }}
{s}button.suggested-action:hover {{ background: {mix(fg, s3, 0.15)}; }}
{s}button.destructive-action {{ background: {red}; color: #ffffff; }}
{s}button.flat, {s}headerbar button, {s}toolbar button, {s}.toolbar button {{ background: transparent; }}
{s}button.flat:hover, {s}headerbar button:hover, {s}toolbar button:hover {{ background: {s2}; }}
{s}button.circular, {s}headerbar button.titlebutton {{ border-radius: 999px; min-width: 24px; padding: 4px; }}

/* the title bar: the panel itself, no rule */
{s}headerbar, {s}.titlebar {{
  background: {s1}; color: {fg}; min-height: 44px; border: none; box-shadow: none;
}}
{s}headerbar:backdrop, {s}.titlebar:backdrop {{ color: {grey}; }}
{s}headerbar .title {{ font-weight: 500; }}
{s}decoration {{ border-radius: 20px; box-shadow: 0 0 0 1px {s2}; }}

/* fields: pills, the caret red (the live thing while you type) */
{s}entry, {s}spinbutton:not(.vertical), {s}searchentry, {s}passwordentry {{
  background: {s2}; color: {fg}; caret-color: {red}; border-radius: 999px;
  border: 1px solid transparent; box-shadow: none; padding: 5px 14px; min-height: 26px;
}}
{s}entry:focus, {s}entry:focus-within, {s}spinbutton:focus-within {{ border-color: {s3}; }}

/* check boxes, radios, switches */
{s}check, {s}radio {{
  background: {s2}; background-image: none; border: 1px solid {mute}; min-width: 16px; min-height: 16px;
  -gtk-icon-source: none; color: {ink}; border-radius: 6px;
}}
{s}radio {{ border-radius: 999px; }}
{s}check:checked, {s}radio:checked {{ background: {fg}; border-color: {fg}; box-shadow: inset 0 0 0 4px {fg}, inset 0 0 0 9px {ink}; }}
{s}switch {{ background: {s2}; border: 1px solid {s3}; min-width: 44px; min-height: 22px; border-radius: 999px; }}
{s}switch:checked {{ background: {fg}; border-color: {fg}; }}
{s}switch slider {{ background: {mute}; min-width: 18px; min-height: 18px; border: none; box-shadow: none; border-radius: 999px; margin: 2px; }}
{s}switch:checked slider {{ background: {ink}; }}

/* menus and popovers: rounded cards, the hovered row the white pill */
{s}menu, {s}.menu, {s}.context-menu, {s}popover > contents, {s}popover.menu > contents {{
  background: {s1}; color: {fg}; border: 1px solid {s2}; border-radius: 22px; box-shadow: 0 10px 30px rgba(0,0,0,0.45); padding: 6px;
}}
{s}popover, {s}popover.background {{ background: transparent; box-shadow: none; }}
{s}popover > arrow {{ background: none; border: none; }}
{s}menuitem, {s}modelbutton {{ padding: 7px 16px; border-radius: 999px; }}
{s}menuitem:hover, {s}modelbutton:hover, {s}popover.menu modelbutton:selected {{ background: {fg}; color: {ink}; }}
{s}menubar {{ background: {s1}; }}
{s}menubar > item:hover, {s}menubar > menuitem:hover {{ background: {s2}; border-radius: 999px; }}
{s}separator {{ background: {s3}; min-width: 1px; min-height: 1px; }}

/* tabs: chips; the current one the white pill */
{s}notebook > header {{ background: {s1}; border: none; box-shadow: none; padding: 4px; }}
{s}notebook > header tab {{ padding: 6px 16px; color: {grey}; border: none; border-radius: 999px; }}
{s}notebook > header tab:checked {{ background: {fg}; color: {ink}; }}
{s}notebook > stack {{ background: {s1}; }}

/* lists' column headers, frames */
{s}treeview.view header button, {s}columnview > header > button {{ background: {s1}; border: none; border-radius: 0; color: {grey}; padding: 5px 10px; }}
{s}scrolledwindow.frame, {s}frame > border, {s}.frame {{ border: 1px solid {s2}; border-radius: 16px; }}

/* scroll bars: a thin round slider */
{s}scrollbar {{ background: transparent; border: none; }}
{s}scrollbar slider {{ background: {mute}; border: none; min-width: 5px; min-height: 5px; margin: 3px; border-radius: 999px; }}
{s}scrollbar slider:hover, {s}scrollbar slider:active {{ background: {grey}; }}

/* scales, progress: a white pill on dark */
{s}scale trough {{ background: {s3}; min-height: 6px; min-width: 6px; border: none; border-radius: 999px; }}
{s}scale highlight {{ background: {fg}; border-radius: 999px; }}
{s}scale slider {{ background: {fg}; min-width: 18px; min-height: 18px; border: 3px solid {s1}; border-radius: 999px; margin: -8px; }}
{s}progressbar trough {{ background: {s3}; min-height: 6px; border: none; border-radius: 999px; }}
{s}progressbar progress {{ background: {fg}; border: none; min-height: 6px; border-radius: 999px; }}
{s}levelbar block.filled {{ background: {fg}; border-radius: 999px; }}

/* tooltips, notices */
{s}tooltip, tooltip, tooltip.background {{ background: {s1}; color: {fg}; border: 1px solid {s3}; border-radius: 14px; }}
{s}infobar, {s}.app-notification {{ background: {s2}; border: none; border-radius: 22px; }}
{s}statusbar, {s}.statusbar {{ color: {grey}; }}
{s}combobox button.combo, {s}dropdown > button {{ background: {s2}; }}
"""


def gtk3(p, ctx):
    return gtk_css(p, ctx, False)


def gtk4(p, ctx):
    return gtk_css(p, ctx, True) + f"""
:root {{ --window-radius: 20px; --accent-color: {p["fg"]}; --accent-bg-color: {p["fg"]}; --accent-fg-color: {p["ink"]}; }}
"""


def satty(p, ctx):
    fg, ink = p["fg"], p["ink"]
    return gtk_css(p, ctx, False) + f"""
.toolbar {{ background: {p["s1"]}; border: 1px solid {p["s2"]}; border-radius: 999px; box-shadow: 0 10px 30px rgba(0,0,0,0.45); padding: 4px; }}
.toolbar button:checked, .toolbar button.editing {{ background: {fg}; color: {ink}; }}
"""


def qss(p, ctx):
    fg, bg, s1, s2, s3 = p["fg"], p["bg"], p["s1"], p["s2"], p["s3"]
    mute, grey, ink, red = p["mute"], p["grey"], p["ink"], p["red"]
    return f"""/* Glyph: Nothing's panels, for Qt apps (qt6ct) */
QWidget {{ background-color: {s1}; color: {fg}; selection-background-color: {fg}; selection-color: {ink}; }}
QPushButton, QToolButton {{ background: {s2}; border: none; border-radius: 14px; padding: 5px 16px; }}
QPushButton:hover, QToolButton:hover {{ background: {s3}; }}
QPushButton:pressed, QPushButton:checked, QToolButton:checked {{ background: {fg}; color: {ink}; }}
QPushButton:default {{ background: {fg}; color: {ink}; }}
QLineEdit, QTextEdit, QPlainTextEdit, QSpinBox, QDoubleSpinBox, QComboBox {{ background: {s2}; border: 1px solid transparent; border-radius: 12px; padding: 4px 10px; }}
QLineEdit:focus, QTextEdit:focus, QComboBox:focus {{ border-color: {s3}; }}
QListView, QTreeView, QTableView, QListWidget, QTreeWidget, QTableWidget {{ background: {s1}; border: 1px solid {s2}; border-radius: 12px; alternate-background-color: {bg}; }}
QListView::item:selected, QTreeView::item:selected {{ background: {fg}; color: {ink}; border-radius: 8px; }}
QHeaderView::section {{ background: {s1}; color: {grey}; border: none; padding: 5px 10px; }}
QMenuBar {{ background: {s1}; }}
QMenuBar::item:selected {{ background: {s2}; border-radius: 10px; }}
QMenu {{ background: {s1}; border: 1px solid {s2}; border-radius: 16px; padding: 6px; }}
QMenu::item {{ padding: 6px 22px; border-radius: 12px; }}
QMenu::item:selected {{ background: {fg}; color: {ink}; }}
QMenu::separator {{ height: 1px; background: {s3}; margin: 5px 10px; }}
QTabBar::tab {{ background: {s1}; color: {grey}; padding: 6px 16px; border: none; border-radius: 12px; }}
QTabBar::tab:selected {{ background: {fg}; color: {ink}; }}
QTabWidget::pane {{ border: 1px solid {s2}; border-radius: 12px; }}
QGroupBox {{ border: 1px solid {s2}; border-radius: 14px; margin-top: 14px; padding-top: 10px; }}
QGroupBox::title {{ subcontrol-origin: margin; left: 14px; padding: 0 4px; color: {grey}; }}
QCheckBox::indicator, QRadioButton::indicator {{ width: 14px; height: 14px; background: {s2}; border: 1px solid {mute}; border-radius: 5px; }}
QRadioButton::indicator {{ border-radius: 8px; }}
QCheckBox::indicator:checked, QRadioButton::indicator:checked {{ background: {fg}; border-color: {fg}; }}
QScrollBar:vertical {{ width: 10px; background: transparent; }}
QScrollBar:horizontal {{ height: 10px; background: transparent; }}
QScrollBar::handle {{ background: {mute}; min-height: 24px; min-width: 24px; border-radius: 4px; margin: 2px; }}
QScrollBar::handle:hover {{ background: {grey}; }}
QScrollBar::add-line, QScrollBar::sub-line, QScrollBar::add-page, QScrollBar::sub-page {{ background: none; border: none; width: 0; height: 0; }}
QSlider::groove:horizontal {{ height: 6px; background: {s3}; border-radius: 3px; }}
QSlider::sub-page:horizontal {{ background: {fg}; border-radius: 3px; }}
QSlider::handle:horizontal {{ width: 16px; height: 16px; margin: -5px 0; background: {fg}; border-radius: 8px; }}
QProgressBar {{ background: {s3}; border: none; border-radius: 6px; text-align: center; color: {fg}; }}
QProgressBar::chunk {{ background: {fg}; border-radius: 6px; }}
QToolTip {{ background: {s1}; color: {fg}; border: 1px solid {s3}; border-radius: 10px; padding: 4px; }}
QStatusBar {{ color: {grey}; }}
QAbstractItemView {{ selection-background-color: {fg}; selection-color: {ink}; }}
QLineEdit {{ selection-background-color: {s3}; selection-color: {fg}; }}
"""


def icons(p, ctx):
    """Papirus with its blue folders in the theme's greys (front: the line grey, back: a step darker,
    the glyph in the text colour)."""
    front, back, glyph = p["s3"], p["s2"], p["fg"]
    if p.get("appearance") == "light" or ctx.get("appearance") == "light":
        front, back, glyph = p["mute"], p["s3"], p["ink"]
    recolor = {"#5294e2": front, "#4877b1": back, "#e4e4e4": glyph, "#ffffff": glyph}

    def draw(a):
        svg = a["svg"]
        for old, new in recolor.items():
            svg = svg.replace(old, new).replace(old.upper(), new)
        return svg

    return iconkit.folder_theme(ICON_THEME, "Papirus with folders in the theme's greys (written by the Glyph setup)",
                                draw, iconkit.palette_key(front, back, glyph, "glyph-icons-v1"),
                                "Papirus-Dark,Papirus,Adwaita,hicolor" if ctx.get("appearance") != "light" else "Papirus,Adwaita,hicolor")


def _shapes(p):
    """Dot cursors: the arrow drawn as a solid body with an outline of dots, a ring of dots that
    turns for busy (one dot red, the live thing), round targets for the rest."""
    fg, ink, red = p["fg"], p["ink"], p["red"]
    # the arrow's body in the text colour, its edge in the background's (so it reads on both)
    body, edge = fg, ink

    def svg(inner):
        return f'<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">{inner}</svg>'

    arrow_path = "M8 5 L8 47 Q8 50 10.5 48 L19.5 39.5 L27 55 Q28.2 57.4 30.6 56.3 L35 54.2 Q37.3 53 36.2 50.7 L28.8 35.6 L41 35.6 Q43.8 35.6 41.8 33.5 L11 4 Q8 1.5 8 5 Z"

    def dots_on_ring(cx, cy, r, n, size, color, lit=None, litcolor=None):
        out = ""
        for i in range(n):
            a = 2 * math.pi * i / n - math.pi / 2
            c = litcolor if lit is not None and i == lit else color
            out += f'<circle cx="{cx + r * math.cos(a):.2f}" cy="{cy + r * math.sin(a):.2f}" r="{size}" fill="{c}"/>'
        return out

    def arrow(extra=""):
        return lambda f, n: svg(f'<path d="{arrow_path}" fill="{body}" stroke="{edge}" stroke-width="3" stroke-linejoin="round"/>' + extra)

    def spinner(f, n, cx=32, cy=32, r=18, size=3.2):
        return (f'<circle cx="{cx}" cy="{cy}" r="{r + 6}" fill="{edge}" opacity="0.55"/>'
                + dots_on_ring(cx, cy, r, 12, size, fg, lit=f % 12, litcolor=red))

    def double(angle):
        shape = ('<path d="M32 5 L45 19 L36.5 19 L36.5 45 L45 45 L32 59 L19 45 L27.5 45 L27.5 19 L19 19 Z" '
                 f'fill="{body}" stroke="{edge}" stroke-width="3" stroke-linejoin="round"/>')
        return lambda f, n: svg(f'<g transform="rotate({angle} 32 32)">{shape}</g>')

    def badge(inner):
        return (f'<circle cx="49" cy="49" r="12" fill="{edge}"/><circle cx="49" cy="49" r="10" fill="{body}"/>' + inner)

    return {
        "arrow": (arrow(), (8, 4), 1),
        "pointer": (lambda f, n: svg(f'<path d="{arrow_path}" fill="{body}" stroke="{edge}" stroke-width="3" stroke-linejoin="round"/>'
                                     f'<circle cx="16" cy="22" r="4" fill="{red}"/>'), (8, 4), 1),
        "text": (lambda f, n: svg(f'<path d="M23 8 H41 M32 8 V56 M23 56 H41" stroke="{edge}" stroke-width="8" stroke-linecap="round" fill="none"/>'
                                  f'<path d="M23 8 H41 M32 8 V56 M23 56 H41" stroke="{body}" stroke-width="3.5" stroke-linecap="round" fill="none"/>'), (32, 32), 1),
        "crosshair": (lambda f, n: svg(dots_on_ring(32, 32, 16, 16, 2.4, body) + f'<circle cx="32" cy="32" r="3.5" fill="{red}"/>'), (32, 32), 1),
        "wait": (lambda f, n: svg(spinner(f, n)), (32, 32), 12),
        "progress": (lambda f, n: arrow(spinner(f, n, 47, 47, 10, 2.2))(f, n), (8, 4), 12),
        "move": (lambda f, n: svg(dots_on_ring(32, 32, 20, 4, 5, body) + f'<circle cx="32" cy="32" r="6" fill="{body}" stroke="{edge}" stroke-width="3"/>'), (32, 32), 1),
        "ns": (double(0), (32, 32), 1),
        "ew": (double(90), (32, 32), 1),
        "nwse": (double(-45), (32, 32), 1),
        "nesw": (double(45), (32, 32), 1),
        "forbidden": (lambda f, n: svg(dots_on_ring(32, 32, 20, 18, 2.6, body) + f'<path d="M19 45 L45 19" stroke="{red}" stroke-width="5" stroke-linecap="round"/>'), (32, 32), 1),
        "help": (arrow(badge(f'<text x="49" y="55" font-family="sans-serif" font-weight="bold" font-size="16" text-anchor="middle" fill="{edge}">?</text>')), (8, 4), 1),
        "copy": (arrow(badge(f'<path d="M49 43 V55 M43 49 H55" stroke="{edge}" stroke-width="3" stroke-linecap="round"/>')), (8, 4), 1),
        "link": (arrow(badge(f'<path d="M44 54 L54 44 M47 44 H54 V51" stroke="{edge}" stroke-width="3" stroke-linecap="round" fill="none"/>')), (8, 4), 1),
    }


def cursors(p, ctx):
    key = iconkit.palette_key(p["fg"], p["ink"], p["red"], "glyph-cursors-v1")
    return iconkit.cursor_theme(CURSOR_THEME, "Dot cursors in the theme's colours (written by the Glyph setup)",
                                _shapes(p), key)
