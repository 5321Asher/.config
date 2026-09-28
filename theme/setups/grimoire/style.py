"""Grimoire's look beyond colours: GTK 3/4, Qt and Satty as a spellbook's furniture (windows of
leather with a gilt rule under the title bar, gold hairline buttons that fill with gold leaf, menus
and tooltips on slips of parchment in ink, the arcane colour for switches that are on), Papirus-Dark
with folders bound in the theme's wax-coloured leather and stamped in gold, and gilded cursors (an
arrow of gold leaf, a quill for text, an hourglass for waiting).

Called by ~/.config/theme/writers.py on every theme switch (see writers.setup_style).
"""

import colorsys

import iconkit

ICON_THEME = "Grimoire"
CURSOR_THEME = "Grimoire-Cursors"


def _lift(h, lo, hi):
    """The colour with its lightness kept between lo and hi."""
    r, g, b = (int(h.lstrip("#")[i:i + 2], 16) / 255 for i in (0, 2, 4))
    hh, l, s = colorsys.rgb_to_hls(r, g, b)
    r, g, b = colorsys.hls_to_rgb(hh, max(lo, min(hi, l)), s)
    return "#" + "".join(f"{round(v * 255):02x}" for v in (r, g, b))


def gtk_css(p, ctx, gtk4):
    rgba, mix = ctx["rgba"], ctx["mix"]
    light = ctx.get("appearance") == "light"
    gold, arcane, bg, dark, fg, dim, line = p["accent"], p["purple"], p["bg"], p["bgDark"], p["fg"], p["dim"], p["border"]
    surf, hover, ongold = p["surface"], p["hover"], p["accentText"]
    page, ink, inkdim = p.get("parchment", "#e8dcc0"), p.get("ink", "#2f1d14"), p.get("inkDim", "#6e5642")
    bright, deep, rubric = p.get("goldBright", gold), p.get("goldDeep", gold), p.get("rubric", p["danger"])
    view = mix(bg, dark, 0.55) if not light else mix(surf, "#ffffff", 0.35)
    # GTK 4: widget rules only inside windows that aren't Walker's (it has its own theme; user CSS
    # would outrank it)
    s = "window:not(.walker) " if gtk4 else ""
    win = "window:not(.walker)" if gtk4 else "window"
    return f"""
/* Grimoire: a spellbook's furniture */
{s}* {{ -gtk-icon-shadow: none; text-shadow: none; outline-color: {rgba(gold, 0.6)}; outline-offset: -2px; outline-width: 1px; }}
{win}, {s}.background, {s}dialog {{ background-color: {bg}; color: {fg}; }}
{s}.view, {s}textview text, {s}iconview, {s}treeview.view, {s}columnview, {s}listview, {s}list, {s}scrolledwindow > viewport > list {{
  background-color: {view}; color: {fg};
}}
{s}.sidebar, {s}placessidebar, {s}placessidebar list, {s}.navigation-sidebar {{ background-color: {mix(bg, dark, 0.3)}; }}
{s}*:selected, {s}row:selected, {s}.view:selected, {s}treeview.view:selected, {s}iconview:selected, {s}text selection, {s}entry selection, {s}label selection {{
  background-color: {rgba(gold, 0.3)}; color: {bright if not light else ink};
}}
{s}row:selected {{ box-shadow: inset 2px 0 {gold}; }}
{s}row:hover {{ background-color: {rgba(gold, 0.07)}; }}
{s}*:disabled {{ color: {rgba(dim, 0.65)}; }}
{s}.dim-label {{ color: {dim}; opacity: 1; }}
{s}link, {s}*:link {{ color: {arcane}; }}

/* buttons: a gold hairline; hover washes them in gold, pressing fills them */
{s}button {{
  background: transparent; background-image: none; color: {fg};
  border: 1px solid {rgba(gold, 0.45)}; border-radius: 3px; box-shadow: none; padding: 4px 12px; min-height: 22px;
}}
{s}button:hover {{ border-color: {gold}; background: {rgba(gold, 0.12)}; }}
{s}button:active, {s}button:checked {{ background: {rgba(gold, 0.28)}; border-color: {gold}; color: {bright if not light else ink}; }}
{s}button.suggested-action, {s}button.default {{ background-image: linear-gradient(to bottom, {bright}, {gold}); color: {ongold}; border-color: {deep}; }}
{s}button.suggested-action:hover {{ background-image: linear-gradient(to bottom, {mix(bright, "#ffffff", 0.2)}, {bright}); }}
{s}button.destructive-action {{ border-color: {p["danger"]}; color: {p["danger"]}; }}
{s}button.flat, {s}headerbar button, {s}toolbar button, {s}.toolbar button {{ background: transparent; border-color: transparent; }}
{s}button.flat:hover, {s}headerbar button:hover, {s}toolbar button:hover {{ border-color: {rgba(gold, 0.5)}; background: {rgba(gold, 0.1)}; }}

/* the title bar (client-side decorations): darker leather over a gilt rule */
{s}headerbar, {s}.titlebar {{
  background: {dark}; color: {fg}; min-height: 38px; border: none; border-radius: 3px 3px 0 0;
  box-shadow: inset 0 -1px {deep}, inset 0 -2px {gold};
}}
{s}headerbar:backdrop, {s}.titlebar:backdrop {{ box-shadow: inset 0 -1px {line}; color: {dim}; }}
{s}headerbar .title {{ font-style: italic; }}
{s}decoration {{ border-radius: 3px; box-shadow: 0 0 0 1px {line}, 0 10px 28px rgba(0,0,0,0.55); }}

/* fields: a darker well with an inked line that turns gold while you write */
{s}entry, {s}spinbutton:not(.vertical), {s}searchentry, {s}passwordentry {{
  background: {view}; color: {fg}; caret-color: {gold};
  border: 1px solid {line}; border-radius: 3px; box-shadow: inset 0 -1px {rgba(gold, 0.35)}; padding: 4px 8px; min-height: 22px;
}}
{s}entry:focus, {s}entry:focus-within, {s}spinbutton:focus-within {{ border-color: {rgba(gold, 0.7)}; box-shadow: inset 0 -2px {gold}; }}

/* check boxes, radios, switches: gold ticks; a switch that's on glows arcane */
{s}check, {s}radio {{
  background: {view}; background-image: none; border: 1px solid {rgba(gold, 0.55)}; min-width: 14px; min-height: 14px;
  -gtk-icon-source: none; color: {ongold};
}}
{s}check {{ border-radius: 3px; }}
{s}radio {{ border-radius: 50%; }}
{s}check:checked, {s}radio:checked {{ background: {gold}; border-color: {deep}; box-shadow: inset 0 0 0 3px {view}; }}
{s}switch {{ background: {view}; border: 1px solid {line}; border-radius: 12px; min-width: 40px; min-height: 20px; }}
{s}switch:checked {{ background: {rgba(arcane, 0.35)}; border-color: {arcane}; }}
{s}switch slider {{ background: {dim}; min-width: 18px; min-height: 18px; border-radius: 50%; border: none; box-shadow: none; }}
{s}switch:checked slider {{ background: {p.get("wax", arcane)}; box-shadow: 0 0 6px {arcane}; }}

/* menus: slips of parchment, in ink */
{s}menu, {s}.menu, {s}.context-menu, {s}popover.menu > contents {{
  background: {page}; color: {ink}; border: 1px solid {mix(page, ink, 0.35)}; border-radius: 3px;
  box-shadow: 0 10px 26px rgba(0,0,0,0.5); padding: 5px;
}}
{s}menu *, {s}.context-menu *, {s}popover.menu > contents * {{ color: {ink}; }}
{s}menu *:disabled, {s}popover.menu > contents *:disabled {{ color: {rgba(inkdim, 0.6)}; }}
{s}popover > contents {{ background: {mix(bg, dark, 0.3)}; color: {fg}; border: 1px solid {rgba(gold, 0.4)}; border-radius: 4px; box-shadow: 0 10px 26px rgba(0,0,0,0.5); }}
{s}popover, {s}popover.background {{ background: transparent; box-shadow: none; }}
{s}popover > arrow {{ background: none; border: none; }}
{s}menuitem, {s}modelbutton {{ padding: 5px 14px; border-radius: 2px; }}
{s}menuitem:hover, {s}popover.menu modelbutton:hover, {s}popover.menu modelbutton:selected {{ background: {rgba(gold, 0.3)}; box-shadow: inset 2px 0 {rubric}; }}
{s}menubar {{ background: {bg}; box-shadow: inset 0 -1px {line}; }}
{s}menubar > item:hover, {s}menubar > menuitem:hover {{ box-shadow: inset 0 -2px {gold}; }}
{s}separator {{ background: {rgba(gold, 0.3)}; min-width: 1px; min-height: 1px; }}

/* tabs: the open one underlined in gold */
{s}notebook > header {{ background: {bg}; border: none; box-shadow: inset 0 -1px {line}; }}
{s}notebook > header tab {{ padding: 6px 14px; color: {dim}; border: none; }}
{s}notebook > header tab:checked {{ color: {fg}; box-shadow: inset 0 -2px {gold}; }}
{s}notebook > stack {{ background: {bg}; }}

/* lists' column headers, frames */
{s}treeview.view header button, {s}columnview > header > button {{ background: {bg}; border: none; border-bottom: 1px solid {line}; border-radius: 0; color: {dim}; padding: 4px 8px; }}
{s}scrolledwindow.frame, {s}frame > border, {s}.frame {{ border: 1px solid {line}; border-radius: 3px; }}

/* scroll bars: a thread of gold */
{s}scrollbar {{ background: transparent; border: none; }}
{s}scrollbar slider {{ background: {rgba(gold, 0.35)}; border: none; border-radius: 4px; min-width: 5px; min-height: 5px; margin: 2px; }}
{s}scrollbar slider:hover, {s}scrollbar slider:active {{ background: {gold}; }}

/* scales, progress: gold leaf on an inked groove, a small gem to drag */
{s}scale trough {{ background: {rgba(dim, 0.25)}; min-height: 4px; min-width: 4px; border: none; border-radius: 2px; }}
{s}scale highlight {{ background-image: linear-gradient(to right, {deep}, {gold}); border-radius: 2px; }}
{s}scale slider {{ background: {gold}; min-width: 12px; min-height: 12px; border: 1px solid {deep}; border-radius: 2px; margin: -5px; }}
{s}progressbar trough {{ background: {rgba(dim, 0.2)}; min-height: 6px; border: none; border-radius: 3px; }}
{s}progressbar progress {{ background-image: linear-gradient(to right, {deep}, {gold}); border: none; border-radius: 3px; min-height: 6px; }}
{s}levelbar block.filled {{ background: {gold}; }}

/* tooltips: a note in the margin */
{s}tooltip, tooltip, tooltip.background {{ background: {page}; color: {ink}; border: 1px solid {mix(page, ink, 0.35)}; border-radius: 3px; }}
tooltip * {{ color: {ink}; }}
{s}infobar, {s}.app-notification {{ background: {surf}; border: 1px solid {line}; box-shadow: inset 2px 0 {arcane}; }}
{s}statusbar, {s}.statusbar {{ color: {dim}; }}
{s}combobox button.combo, {s}dropdown > button {{ background: {view}; }}
"""


def gtk3(p, ctx):
    return gtk_css(p, ctx, False)


def gtk4(p, ctx):
    return gtk_css(p, ctx, True) + f"""
:root {{ --window-radius: 3px; --accent-color: {p["accent"]}; --accent-bg-color: {p["accent"]}; --accent-fg-color: {p["accentText"]}; }}
"""


def satty(p, ctx):
    rgba = ctx["rgba"]
    gold = p["accent"]
    return gtk_css(p, ctx, False) + f"""
.toolbar {{ background: {rgba(p["bgDark"], 0.95)}; border: 1px solid {rgba(gold, 0.5)}; border-radius: 4px; box-shadow: 0 10px 26px rgba(0,0,0,0.55); }}
.toolbar button:checked, .toolbar button.editing {{ background: {rgba(gold, 0.28)}; box-shadow: inset 0 -2px {gold}; }}
"""


def qss(p, ctx):
    rgba, mix = ctx["rgba"], ctx["mix"]
    light = ctx.get("appearance") == "light"
    gold, arcane, bg, dark, fg, dim, line = p["accent"], p["purple"], p["bg"], p["bgDark"], p["fg"], p["dim"], p["border"]
    page, ink = p.get("parchment", "#e8dcc0"), p.get("ink", "#2f1d14")
    bright, deep = p.get("goldBright", gold), p.get("goldDeep", gold)
    view = mix(bg, dark, 0.55) if not light else mix(p["surface"], "#ffffff", 0.35)
    return f"""/* Grimoire: a spellbook's furniture, for Qt apps (qt6ct) */
QWidget {{ background-color: {bg}; color: {fg}; selection-background-color: {rgba(gold, 0.35)}; selection-color: {bright if not light else ink}; }}
QPushButton, QToolButton {{ background: transparent; border: 1px solid {rgba(gold, 0.45)}; border-radius: 3px; padding: 4px 12px; }}
QPushButton:hover, QToolButton:hover {{ border-color: {gold}; background: {rgba(gold, 0.12)}; }}
QPushButton:pressed, QPushButton:checked, QToolButton:checked {{ background: {rgba(gold, 0.28)}; border-color: {gold}; }}
QPushButton:default {{ background: qlineargradient(x1:0, y1:0, x2:0, y2:1, stop:0 {bright}, stop:1 {gold}); color: {p["accentText"]}; border-color: {deep}; }}
QLineEdit, QTextEdit, QPlainTextEdit, QSpinBox, QDoubleSpinBox, QComboBox {{ background: {view}; border: 1px solid {line}; border-radius: 3px; padding: 3px 6px; }}
QLineEdit:focus, QTextEdit:focus, QComboBox:focus {{ border-color: {gold}; }}
QListView, QTreeView, QTableView, QListWidget, QTreeWidget, QTableWidget {{ background: {view}; border: 1px solid {line}; alternate-background-color: {mix(view, bg, 0.5)}; }}
QHeaderView::section {{ background: {bg}; color: {dim}; border: none; border-bottom: 1px solid {line}; padding: 4px 8px; }}
QMenuBar {{ background: {bg}; border-bottom: 1px solid {line}; }}
QMenuBar::item:selected {{ border-bottom: 2px solid {gold}; background: transparent; }}
QMenu {{ background: {page}; color: {ink}; border: 1px solid {mix(page, ink, 0.35)}; padding: 5px; }}
QMenu::item {{ padding: 5px 22px; color: {ink}; }}
QMenu::item:selected {{ background: {rgba(gold, 0.3)}; border-left: 2px solid {p.get("rubric", gold)}; }}
QMenu::item:disabled {{ color: {mix(page, ink, 0.45)}; }}
QMenu::separator {{ height: 1px; background: {mix(page, ink, 0.3)}; margin: 4px 8px; }}
QTabBar::tab {{ background: {bg}; color: {dim}; padding: 6px 14px; border: none; }}
QTabBar::tab:selected {{ color: {fg}; border-bottom: 2px solid {gold}; }}
QTabWidget::pane {{ border: 1px solid {line}; }}
QGroupBox {{ border: 1px solid {line}; border-radius: 3px; margin-top: 12px; padding-top: 8px; }}
QGroupBox::title {{ subcontrol-origin: margin; left: 10px; padding: 0 4px; color: {gold}; }}
QCheckBox::indicator, QRadioButton::indicator {{ width: 13px; height: 13px; background: {view}; border: 1px solid {rgba(gold, 0.6)}; }}
QRadioButton::indicator {{ border-radius: 7px; }}
QCheckBox::indicator:checked, QRadioButton::indicator:checked {{ background: {gold}; border-color: {deep}; }}
QScrollBar:vertical {{ width: 9px; background: transparent; }}
QScrollBar:horizontal {{ height: 9px; background: transparent; }}
QScrollBar::handle {{ background: {rgba(gold, 0.35)}; border-radius: 4px; min-height: 20px; min-width: 20px; }}
QScrollBar::handle:hover {{ background: {gold}; }}
QScrollBar::add-line, QScrollBar::sub-line, QScrollBar::add-page, QScrollBar::sub-page {{ background: none; border: none; width: 0; height: 0; }}
QSlider::groove:horizontal {{ height: 4px; background: {rgba(dim, 0.3)}; border-radius: 2px; }}
QSlider::sub-page:horizontal {{ background: {gold}; border-radius: 2px; }}
QSlider::handle:horizontal {{ width: 12px; margin: -5px 0; background: {gold}; border: 1px solid {deep}; border-radius: 2px; }}
QProgressBar {{ background: {view}; border: 1px solid {line}; border-radius: 3px; text-align: center; }}
QProgressBar::chunk {{ background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 {deep}, stop:1 {gold}); border-radius: 2px; }}
QToolTip {{ background: {page}; color: {ink}; border: 1px solid {mix(page, ink, 0.35)}; padding: 4px; }}
QStatusBar {{ color: {dim}; }}
"""


def icons(p, ctx):
    """Papirus-Dark with its folders bound in the theme's wax-coloured leather, their symbols in gold."""
    mix = ctx["mix"]
    front = _lift(mix(p.get("wax", p["accent"]), p["accent"], 0.12), 0.3, 0.46)
    back = mix(front, p["bgDark"], 0.45)
    glyph = p.get("goldBright", p["accent"])
    paper, paper2 = p.get("parchment", "#e8dcc0"), p.get("parchmentDeep", "#c9b48a")
    recolor = {"#5294e2": front, "#4877b1": back, "#1d344f": glyph, "#e4e4e4": paper2, "#ffffff": paper}

    def draw(a):
        svg = a["svg"]
        for old, new in recolor.items():
            svg = svg.replace(old, new).replace(old.upper(), new)
        return svg

    return iconkit.folder_theme(ICON_THEME, "Papirus-Dark with leather-bound folders stamped in gold (written by the Grimoire setup)",
                                draw, iconkit.palette_key(front, back, glyph, paper, paper2, "grimoire-icons-v2"), "Papirus-Dark,Adwaita,hicolor")


def _shapes(p):
    """Gilded cursors: gold leaf with an ink edge; a quill for text; an hourglass for waiting."""
    gold, bright, deep = p["accent"], p.get("goldBright", p["accent"]), p.get("goldDeep", p["accent"])
    arcane, ink = p["purple"], "#1a0e08"
    page = p.get("parchment", "#e8dcc0")

    def svg(body):
        return (f'<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">'
                f'<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="{bright}"/>'
                f'<stop offset="0.55" stop-color="{gold}"/><stop offset="1" stop-color="{deep}"/></linearGradient></defs>{body}</svg>')

    arrow_path = "M6 4 L6 46 L16 37 L24 56 L32 52 L24 34 L38 34 Z"

    def arrow(extra="", fill="url(#g)"):
        return lambda f, n: svg(f'<path d="{arrow_path}" fill="{fill}" stroke="{ink}" stroke-width="3" stroke-linejoin="round"/>'
                                f'<path d="M10 13 L10 36" stroke="{page}" stroke-opacity="0.6" stroke-width="1.5"/>' + extra)

    def hourglass(f, n):
        # sand runs through over the frames
        k = f / max(1, n - 1)
        top = 16 * (1 - k)
        return (f'<path d="M16 6 H48 M16 58 H48" stroke="{ink}" stroke-width="7" stroke-linecap="round"/>'
                f'<path d="M16 6 H48 M16 58 H48" stroke="url(#g)" stroke-width="4" stroke-linecap="round"/>'
                f'<path d="M20 9 C20 24 30 28 31 32 C30 36 20 40 20 55 L44 55 C44 40 34 36 33 32 C34 28 44 24 44 9 Z" fill="{page}" fill-opacity="0.35" stroke="{ink}" stroke-width="2.5"/>'
                f'<path d="M{32 - top * 0.7} {28 - top} L{32 + top * 0.7} {28 - top} L32 31 Z" fill="{deep}"/>'
                f'<path d="M23 54 L32 {54 - 14 * k} L41 54 Z" fill="{deep}"/>'
                f'<path d="M32 31 L32 {54 - 14 * k}" stroke="{deep}" stroke-width="1.5"/>')

    def double(angle):
        body = (f'<g transform="rotate({angle} 32 32)"><path d="M32 4 L44 18 L36 18 L36 46 L44 46 L32 60 L20 46 L28 46 L28 18 L20 18 Z" '
                f'fill="url(#g)" stroke="{ink}" stroke-width="3" stroke-linejoin="round"/></g>')
        return lambda f, n: svg(body)

    def badge(inner):
        return (f'<circle cx="49" cy="49" r="12" fill="{ink}" stroke="url(#g)" stroke-width="2.5"/>' + inner)

    return {
        "arrow": (arrow(), (6, 4), 1),
        "pointer": (arrow(f'<circle cx="8" cy="7" r="5" fill="{arcane}" stroke="{ink}" stroke-width="1.5"/>', fill=f"{arcane}"), (6, 4), 1),
        # the quill: a feathered I-beam
        "text": (lambda f, n: svg(f'<path d="M24 8 Q32 12 40 8 M32 10 V54 M24 56 Q32 52 40 56" stroke="{ink}" stroke-width="7" fill="none" stroke-linecap="round"/>'
                                  f'<path d="M24 8 Q32 12 40 8 M32 10 V54 M24 56 Q32 52 40 56" stroke="url(#g)" stroke-width="3.5" fill="none" stroke-linecap="round"/>'), (32, 32), 1),
        "crosshair": (lambda f, n: svg(f'<circle cx="32" cy="32" r="16" fill="none" stroke="{ink}" stroke-width="6"/>'
                                       f'<circle cx="32" cy="32" r="16" fill="none" stroke="url(#g)" stroke-width="3"/>'
                                       f'<path d="M32 6 V20 M32 44 V58 M6 32 H20 M44 32 H58" stroke="{ink}" stroke-width="6"/>'
                                       f'<path d="M32 6 V20 M32 44 V58 M6 32 H20 M44 32 H58" stroke="url(#g)" stroke-width="3"/>'
                                       f'<circle cx="32" cy="32" r="2.5" fill="{arcane}"/>'), (32, 32), 1),
        "wait": (lambda f, n: svg(hourglass(f, n)), (32, 32), 12),
        "progress": (lambda f, n: arrow(f'<g transform="translate(34 30) scale(0.5)">{hourglass(f, n)}</g>')(f, n), (6, 4), 12),
        "move": (lambda f, n: svg(f'<path d="M32 4 L40 14 H35 V29 H50 V24 L60 32 L50 40 V35 H35 V50 H40 L32 60 L24 50 H29 V35 H14 V40 L4 32 L14 24 V29 H29 V14 H24 Z" '
                                  f'fill="url(#g)" stroke="{ink}" stroke-width="2.5" stroke-linejoin="round"/>'), (32, 32), 1),
        "ns": (double(0), (32, 32), 1),
        "ew": (double(90), (32, 32), 1),
        "nwse": (double(-45), (32, 32), 1),
        "nesw": (double(45), (32, 32), 1),
        "forbidden": (lambda f, n: svg(f'<circle cx="32" cy="32" r="20" fill="none" stroke="{ink}" stroke-width="9"/>'
                                       f'<circle cx="32" cy="32" r="20" fill="none" stroke="{p["danger"]}" stroke-width="5"/>'
                                       f'<path d="M18 46 L46 18" stroke="{ink}" stroke-width="9"/><path d="M18 46 L46 18" stroke="{p["danger"]}" stroke-width="5"/>'), (32, 32), 1),
        "help": (arrow(badge(f'<text x="49" y="55" font-family="serif" font-weight="bold" font-size="17" text-anchor="middle" fill="{bright}">?</text>')), (6, 4), 1),
        "copy": (arrow(badge(f'<path d="M49 42 V56 M42 49 H56" stroke="{bright}" stroke-width="3"/>')), (6, 4), 1),
        "link": (arrow(badge(f'<path d="M43 55 L55 43 M47 43 H55 V51" stroke="{bright}" stroke-width="3" fill="none"/>')), (6, 4), 1),
    }


def cursors(p, ctx):
    key = iconkit.palette_key(p["accent"], p.get("goldBright", ""), p.get("goldDeep", ""), p["purple"], p["danger"],
                              p.get("parchment", ""), "grimoire-cursors-v1")
    return iconkit.cursor_theme(CURSOR_THEME, "Gilded cursors: gold leaf, a quill, an hourglass (written by the Grimoire setup)",
                                _shapes(p), key)
