"""Disguise's look beyond colours: GTK 3/4, Qt and Satty as Windows 11's WinUI controls (Mica
windows, 4 px rounded controls with the darker bottom edge, the accent for default buttons, checks,
switches and the focused field's underline, rounded flyout menus with a shadow), the Win11 icon
theme (light or dark to match), and Windows' own cursors: the white arrow, the hand, the spinning
ring in the theme's accent.

Called by ~/.config/theme/writers.py on every theme switch (see writers.setup_style).
"""

import os

import iconkit

CURSOR_THEME = "Disguise-Cursors"


def gtk_css(p, ctx, gtk4):
    rgba, mix = ctx["rgba"], ctx["mix"]
    light = ctx["appearance"] == "light"
    acc, on_acc = p["accent"], p["accentText"]
    mica, card, field, fg, fg2, fg3 = p["mica"], p["card"], p["field"], p["text"], p["text2"], p["text3"]
    ctrl, ctrl_hover, ctrl_press = p["control"], p["controlHover"], p["controlPressed"]
    stroke, stroke_bottom, divider, strong = p["controlStroke"], p["controlStrokeBottom"], p["divider"], p["strong"]
    flyout = p["flyout"]
    subtle, subtle2 = rgba(fg, 0.06 if light else 0.08), rgba(fg, 0.035 if light else 0.05)
    shadow = "rgba(0,0,0,0.14)" if light else "rgba(0,0,0,0.45)"
    # GTK 4: widget rules only inside windows that aren't Walker's (it has its own theme; user CSS
    # would outrank it)
    s = "window:not(.walker) " if gtk4 else ""
    win = "window:not(.walker)" if gtk4 else "window"
    return f"""
/* Disguise: Windows 11's WinUI controls */
{s}* {{ -gtk-icon-shadow: none; text-shadow: none; outline: 0 solid transparent; outline-offset: 1px; }}
{s}*:focus-visible {{ outline: 2px solid {rgba(fg, 0.9)}; }}
{win}, {s}.background, {s}dialog {{ background-color: {mica}; color: {fg}; }}
{s}.view, {s}textview text, {s}iconview, {s}treeview.view, {s}columnview, {s}listview, {s}list, {s}scrolledwindow > viewport > list {{
  background-color: {card}; color: {fg};
}}
{s}.sidebar, {s}placessidebar, {s}placessidebar list, {s}.navigation-sidebar, {s}stacksidebar list {{ background-color: {mica}; border: none; }}
{s}placessidebar row, {s}.navigation-sidebar row, {s}.navigation-sidebar > row, {s}stacksidebar row {{ border-radius: 4px; margin: 1px 4px; padding: 6px 8px; }}
{s}*:selected, {s}.view:selected, {s}treeview.view:selected, {s}iconview:selected, {s}text selection, {s}entry selection, {s}label selection {{
  background-color: {p["accentMuted"]}; color: {fg};
}}
{s}row:selected, {s}.navigation-sidebar row:selected, {s}placessidebar row:selected {{ background-color: {subtle}; color: {fg}; box-shadow: inset 3px 0 {acc}; }}
{s}row:hover {{ background-color: {subtle2}; }}
{s}*:disabled {{ color: {p["textDisabled"]}; }}
{s}.dim-label {{ color: {fg2}; opacity: 1; }}
{s}link, {s}*:link {{ color: {p["accentLink"]}; }}

/* buttons: a light fill, a hairline edge that's darker along the bottom, 4 px corners */
{s}button {{
  background: {ctrl}; background-image: none; color: {fg}; border-radius: 4px;
  border: 1px solid {stroke}; border-bottom-color: {stroke_bottom}; box-shadow: none;
  padding: 4px 11px; min-height: 22px;
}}
{s}button:hover {{ background: {ctrl_hover}; }}
{s}button:active {{ background: {ctrl_press}; color: {fg2}; border-bottom-color: {stroke}; }}
{s}button:checked {{ background: {acc}; color: {on_acc}; border-color: {acc}; }}
{s}button.suggested-action, {s}button.default, {s}button.suggested-action:backdrop {{
  background: {acc}; color: {on_acc}; border-color: {rgba("#ffffff", 0.08)}; border-bottom-color: {rgba("#000000", 0.4)};
}}
{s}button.suggested-action:hover {{ background: {p["accentHover"]}; }}
{s}button.suggested-action:active {{ background: {p["accentPressed"]}; color: {rgba(on_acc, 0.8)}; }}
{s}button.destructive-action {{ background: {p["danger"]}; color: {"#ffffff" if light else "#000000"}; border-color: {p["danger"]}; }}
{s}button.flat, {s}headerbar button:not(.titlebutton), {s}toolbar button, {s}.toolbar button, {s}popover button.flat {{
  background: transparent; border-color: transparent; box-shadow: none;
}}
{s}button.flat:hover, {s}headerbar button:not(.titlebutton):hover, {s}toolbar button:hover, {s}.toolbar button:hover {{ background: {subtle}; }}
{s}button.flat:active, {s}headerbar button:not(.titlebutton):active {{ background: {subtle2}; }}
{s}button.circular {{ border-radius: 9999px; }}

/* the title bar: Mica, 32 px buttons at the right: minimise, maximise, close (red when pointed at) */
{s}headerbar, {s}.titlebar {{
  background: {mica}; color: {fg}; min-height: 40px; border: none; box-shadow: none; padding: 0 0 0 8px;
}}
{s}headerbar:backdrop, {s}.titlebar:backdrop {{ background: {mica}; color: {fg3}; }}
{s}headerbar .title {{ font-weight: normal; font-size: 12px; }}
{s}headerbar .subtitle {{ color: {fg2}; }}
{s}headerbar button.titlebutton, {s}windowcontrols button {{
  background: transparent; border: none; border-radius: 0; min-width: 46px; min-height: 32px; padding: 0; margin: 0;
  color: {fg}; box-shadow: none;
}}
{s}headerbar button.titlebutton:hover, {s}windowcontrols button:hover {{ background: {subtle}; }}
{s}headerbar button.titlebutton.close:hover, {s}windowcontrols button.close:hover {{ background: #c42b1c; color: #ffffff; }}
{s}headerbar button.titlebutton.close:active, {s}windowcontrols button.close:active {{ background: #c83c31; color: #ffffff; }}
{s}decoration {{ border-radius: 8px; box-shadow: 0 0 0 1px {p["activeBorder"]}, 0 8px 28px {shadow}; }}
{s}decoration:backdrop {{ box-shadow: 0 0 0 1px {p["inactiveBorder"]}, 0 4px 16px {shadow}; }}

/* fields: a white (or dark) box, an underline that turns into a 2 px accent bar when focused */
{s}entry, {s}spinbutton:not(.vertical), {s}searchentry, {s}passwordentry {{
  background: {field if light else rgba("#ffffff", 0.06)}; color: {fg}; caret-color: {fg}; border-radius: 4px;
  border: 1px solid {stroke}; border-bottom-color: {strong}; box-shadow: none; padding: 4px 10px; min-height: 22px;
}}
{s}entry:hover, {s}searchentry:hover {{ background: {ctrl_hover}; }}
{s}entry:focus, {s}entry:focus-within, {s}spinbutton:focus-within, {s}searchentry:focus-within {{
  background: {field if light else p["field"]}; border-bottom-color: {acc}; box-shadow: inset 0 -1px {acc};
}}
{s}entry image, {s}searchentry image {{ color: {fg2}; }}

/* check boxes and radios: 20 px, accent when on */
{s}check, {s}radio {{
  background: {rgba(fg, 0.03)}; background-image: none; border: 1px solid {strong}; min-width: 18px; min-height: 18px;
  color: {on_acc}; margin: 0 6px 0 0;
}}
{s}check {{ border-radius: 4px; }}
{s}radio {{ border-radius: 9999px; }}
{s}check:hover, {s}radio:hover {{ background: {subtle}; }}
{s}check:checked, {s}check:indeterminate {{ background: {acc}; border-color: {acc}; }}
{s}radio:checked {{ background: {on_acc}; border: 5px solid {acc}; min-width: 10px; min-height: 10px; -gtk-icon-source: none; }}

/* switches: a pill with a round knob; accent when on */
{s}switch {{
  background: {rgba(fg, 0.03)}; border: 1px solid {strong}; border-radius: 9999px; min-width: 40px; min-height: 18px;
  padding: 0 1px; color: transparent;
}}
{s}switch:hover {{ background: {subtle}; }}
{s}switch:checked {{ background: {acc}; border-color: {acc}; }}
{s}switch slider {{
  background: {fg2}; min-width: 12px; min-height: 12px; margin: 3px; border-radius: 9999px; border: none; box-shadow: none;
}}
{s}switch:checked slider {{ background: {on_acc}; }}
{s}switch image {{ color: transparent; }}

/* menus and popovers: the flyout, rounded, with a shadow; rows get a rounded highlight */
{s}menu, {s}.menu, {s}.context-menu, {s}popover > contents, {s}popover.menu > contents {{
  background: {flyout}; color: {fg}; border: 1px solid {rgba("#000000", 0.08) if light else rgba("#000000", 0.35)};
  border-radius: 8px; box-shadow: 0 8px 16px {shadow}; padding: 4px;
}}
{s}popover, {s}popover.background {{ background: transparent; box-shadow: none; border: none; }}
{s}popover > arrow {{ background: none; border: none; }}
{s}menuitem, {s}modelbutton, {s}popover.menu modelbutton {{ padding: 6px 12px; border-radius: 4px; min-height: 20px; }}
{s}menuitem:hover, {s}modelbutton:hover, {s}popover.menu modelbutton:selected, {s}popover.menu modelbutton:hover {{ background: {subtle}; }}
{s}menubar {{ background: {mica}; box-shadow: none; padding: 2px 4px; }}
{s}menubar > item, {s}menubar > menuitem {{ border-radius: 4px; padding: 4px 10px; }}
{s}menubar > item:hover, {s}menubar > menuitem:hover {{ background: {subtle}; }}
{s}separator {{ background: {divider}; min-width: 1px; min-height: 1px; }}

/* tabs: the selected one is the card underneath it */
{s}notebook > header {{ background: {mica}; border: none; box-shadow: none; padding: 4px 4px 0; }}
{s}notebook > header tab {{ padding: 6px 14px; color: {fg2}; border: none; border-radius: 8px 8px 0 0; }}
{s}notebook > header tab:hover {{ background: {subtle2}; }}
{s}notebook > header tab:checked {{ color: {fg}; background: {card}; }}
{s}notebook > stack {{ background: {card}; }}

/* lists' column headers, frames, cards */
{s}treeview.view header button, {s}columnview > header > button {{
  background: {card}; border: none; border-right: 1px solid {divider}; border-bottom: 1px solid {divider}; border-radius: 0; color: {fg2}; padding: 4px 10px;
}}
{s}scrolledwindow.frame, {s}frame > border, {s}.frame {{ border: 1px solid {p["cardStroke"]}; border-radius: 4px; }}
{s}.card, {s}list.boxed-list {{ background: {card}; border: 1px solid {p["cardStroke"]}; border-radius: 8px; }}

/* scroll bars: a hairline that widens when you point at it */
{s}scrollbar {{ background: transparent; border: none; }}
{s}scrollbar slider {{ background: {rgba(fg, 0.45)}; border: none; border-radius: 9999px; min-width: 3px; min-height: 3px; margin: 3px; }}
{s}scrollbar:hover slider {{ min-width: 6px; min-height: 6px; background: {rgba(fg, 0.55)}; }}

/* sliders: a 4 px track, accent up to a white knob with an accent heart */
{s}scale trough {{ background: {strong}; min-height: 4px; min-width: 4px; border: none; border-radius: 9999px; }}
{s}scale highlight {{ background: {acc}; border-radius: 9999px; }}
{s}scale slider {{
  background: {card if light else "#454545"}; min-width: 20px; min-height: 20px; border-radius: 9999px; margin: -9px;
  border: 1px solid {stroke}; box-shadow: inset 0 0 0 5px {card if light else "#454545"}, inset 0 0 0 12px {acc};
}}
{s}progressbar trough {{ background: {rgba(fg, 0.25)}; min-height: 1px; border: none; border-radius: 9999px; }}
{s}progressbar progress {{ background: {acc}; border: none; min-height: 3px; border-radius: 9999px; }}
{s}levelbar block.filled {{ background: {acc}; border-radius: 2px; }}
{s}levelbar block.empty {{ background: {rgba(fg, 0.2)}; }}

/* tooltips, notices */
{s}tooltip, tooltip, tooltip.background {{
  background: {flyout}; color: {fg}; border: 1px solid {rgba("#000000", 0.08) if light else rgba("#000000", 0.35)}; border-radius: 4px; padding: 2px 2px;
}}
{s}infobar, {s}.app-notification {{ background: {card}; border: 1px solid {p["cardStroke"]}; border-radius: 4px; }}
{s}statusbar, {s}.statusbar {{ color: {fg2}; }}
{s}combobox button.combo, {s}dropdown > button {{ background: {ctrl}; }}
"""


def gtk3(p, ctx):
    return gtk_css(p, ctx, False)


def gtk4(p, ctx):
    return gtk_css(p, ctx, True) + f"""
:root {{ --window-radius: 8px; --accent-color: {p["accentLink"]}; --accent-bg-color: {p["accent"]}; --accent-fg-color: {p["accentText"]};
  --window-bg-color: {p["mica"]}; --view-bg-color: {p["card"]}; --headerbar-bg-color: {p["mica"]}; --popover-bg-color: {p["flyout"]};
  --card-bg-color: {p["card"]}; --sidebar-bg-color: {p["mica"]}; }}
""" + snipping(p, ctx, "window:not(.walker) ")


def satty(p, ctx):
    return gtk_css(p, ctx, False) + snipping(p, ctx, "")


def snipping(p, ctx, s):
    # Satty dressed as Snipping Tool: one flat command bar on Mica above the picture (icon buttons, no
    # frames; the chosen tool gets a soft fill and an accent glyph), the snip centred on a darker canvas,
    # the pen colours as round swatches in a second flat row, and Copy as the accent button. Also in
    # gtk4() (s = its window prefix): the user gtk.css outranks Satty's own overrides.css.
    rgba = ctx["rgba"]
    light = ctx["appearance"] == "light"
    fg, mica = p["text"], p["mica"]
    subtle, subtle2 = rgba(fg, 0.06 if light else 0.08), rgba(fg, 0.035 if light else 0.05)
    canvas = rgba("#000000", 0.05) if light else rgba("#000000", 0.28)
    return f"""
{s}.outer_box, {s}.overlay {{ background: {mica}; }}
{s}.inner_box {{ background: {canvas}; border-top: 1px solid {p["divider"]}; border-bottom: 1px solid {p["divider"]}; }}
{s}.toolbar, {s}.outer_box .toolbar-top, {s}.outer_box .toolbar-bottom, {s}.overlay .toolbar-top, {s}.overlay .toolbar-bottom {{
  background: {mica}; color: {fg}; border: none; border-radius: 0; box-shadow: none; padding: 6px 12px; }}
{s}.toolbar > * {{ margin: 0 1px; }}
{s}.toolbar button, {s}.toolbar togglebutton, {s}.toolbar button.toggle, {s}.toolbar .linked > button {{
  background: transparent; border: 1px solid transparent; border-radius: 4px; box-shadow: none;
  min-width: 36px; min-height: 32px; padding: 0 4px; color: {fg}; outline: 0 solid transparent; }}
{s}.toolbar button:hover {{ background: {subtle}; }}
{s}.toolbar button:active {{ background: {subtle2}; color: {p["text2"]}; }}
{s}.toolbar button:checked, {s}.toolbar button.editing {{ background: {subtle}; color: {p["accentLink"]}; box-shadow: none; }}
{s}.toolbar button:disabled {{ color: {p["textDisabled"]}; background: transparent; }}
{s}.toolbar separator {{ background: {p["divider"]}; min-width: 1px; margin: 6px 8px; }}
{s}.toolbar label {{ color: {p["text2"]}; }}
{s}.toolbar spinbutton, {s}.toolbar entry {{ background: {rgba(fg, 0.04)}; border: 1px solid {p["controlStroke"]}; border-radius: 4px; box-shadow: none; }}
/* the pen colours: round swatches, a ring around the chosen one */
{s}.toolbar-bottom button image {{ -gtk-icon-size: 18px; }}
{s}.toolbar-bottom button {{ min-width: 32px; border-radius: 9999px; }}
{s}.toolbar-bottom button:checked {{ background: transparent; box-shadow: inset 0 0 0 2px {p["accentLink"]}; }}
/* Copy, Save, Save as sit last in the bar: Copy is the accent action, as in Snipping Tool */
{s}.toolbar-top > box:last-child > button:first-child, {s}.toolbar-top > button:nth-last-child(3) {{ background: {p["accent"]}; color: {p["accentText"]}; }}
{s}.toolbar-top > box:last-child > button:first-child:hover, {s}.toolbar-top > button:nth-last-child(3):hover {{ background: {p["accentHover"]}; }}
{s}.toast {{ background: {p["flyout"]}; color: {fg}; border: 1px solid {p["cardStroke"]}; border-radius: 8px; }}
"""


def qss(p, ctx):
    rgba = ctx["rgba"]
    light = ctx["appearance"] == "light"
    acc, fg, mica, card, ctrl = p["accent"], p["text"], p["mica"], p["card"], p["control"]
    stroke, bottom, strong, flyout = p["controlStroke"], p["controlStrokeBottom"], p["strong"], p["flyout"]
    subtle = rgba(fg, 0.06 if light else 0.08)
    return f"""/* Disguise: Windows 11's WinUI controls, for Qt apps (qt6ct) */
QWidget {{ background-color: {mica}; color: {fg}; selection-background-color: {p["accentMuted"]}; selection-color: {fg}; }}
QPushButton, QToolButton {{ background: {ctrl}; border: 1px solid {stroke}; border-bottom-color: {bottom}; border-radius: 4px; padding: 5px 12px; }}
QPushButton:hover, QToolButton:hover {{ background: {p["controlHover"]}; }}
QPushButton:pressed, QToolButton:pressed {{ background: {p["controlPressed"]}; color: {p["text2"]}; }}
QPushButton:checked, QToolButton:checked {{ background: {acc}; color: {p["accentText"]}; border-color: {acc}; }}
QPushButton:default {{ background: {acc}; color: {p["accentText"]}; border-color: {acc}; }}
QToolButton[autoRaise="true"] {{ background: transparent; border-color: transparent; }}
QToolButton[autoRaise="true"]:hover {{ background: {subtle}; }}
QLineEdit, QTextEdit, QPlainTextEdit, QSpinBox, QDoubleSpinBox, QComboBox {{
  background: {p["field"] if light else rgba("#ffffff", 0.06)}; border: 1px solid {stroke}; border-bottom-color: {strong}; border-radius: 4px; padding: 4px 8px; }}
QLineEdit:focus, QTextEdit:focus, QComboBox:focus, QSpinBox:focus {{ border-bottom: 2px solid {acc}; }}
QComboBox QAbstractItemView {{ background: {flyout}; border: 1px solid {stroke}; border-radius: 8px; padding: 4px; }}
QListView, QTreeView, QTableView, QListWidget, QTreeWidget, QTableWidget {{ background: {card}; border: 1px solid {p["cardStroke"]}; border-radius: 4px; alternate-background-color: {mica}; }}
QListView::item:hover, QTreeView::item:hover {{ background: {subtle}; }}
QListView::item:selected, QTreeView::item:selected {{ background: {subtle}; color: {fg}; border-left: 3px solid {acc}; }}
QHeaderView::section {{ background: {card}; color: {p["text2"]}; border: none; border-right: 1px solid {p["divider"]}; border-bottom: 1px solid {p["divider"]}; padding: 4px 10px; }}
QMenuBar {{ background: {mica}; }}
QMenuBar::item {{ padding: 4px 10px; border-radius: 4px; }}
QMenuBar::item:selected {{ background: {subtle}; }}
QMenu {{ background: {flyout}; border: 1px solid {stroke}; border-radius: 8px; padding: 4px; }}
QMenu::item {{ padding: 6px 24px 6px 12px; border-radius: 4px; }}
QMenu::item:selected {{ background: {subtle}; }}
QMenu::separator {{ height: 1px; background: {p["divider"]}; margin: 4px 0; }}
QTabBar::tab {{ background: transparent; color: {p["text2"]}; padding: 6px 14px; border-top-left-radius: 8px; border-top-right-radius: 8px; }}
QTabBar::tab:selected {{ background: {card}; color: {fg}; }}
QTabWidget::pane {{ background: {card}; border: 1px solid {p["cardStroke"]}; border-radius: 8px; }}
QGroupBox {{ background: {card}; border: 1px solid {p["cardStroke"]}; border-radius: 8px; margin-top: 16px; padding-top: 10px; }}
QGroupBox::title {{ subcontrol-origin: margin; left: 4px; padding: 0 4px; font-weight: 600; }}
QCheckBox::indicator, QRadioButton::indicator {{ width: 18px; height: 18px; border: 1px solid {strong}; background: {rgba(fg, 0.03)}; }}
QCheckBox::indicator {{ border-radius: 4px; }}
QRadioButton::indicator {{ border-radius: 10px; }}
QCheckBox::indicator:checked {{ background: {acc}; border-color: {acc}; }}
QRadioButton::indicator:checked {{ background: {p["accentText"]}; border: 5px solid {acc}; width: 10px; height: 10px; }}
QScrollBar:vertical {{ width: 10px; background: transparent; }}
QScrollBar:horizontal {{ height: 10px; background: transparent; }}
QScrollBar::handle {{ background: {rgba(fg, 0.45)}; border-radius: 3px; min-height: 24px; min-width: 24px; margin: 3px; }}
QScrollBar::add-line, QScrollBar::sub-line, QScrollBar::add-page, QScrollBar::sub-page {{ background: none; border: none; width: 0; height: 0; }}
QSlider::groove:horizontal {{ height: 4px; background: {strong}; border-radius: 2px; }}
QSlider::sub-page:horizontal {{ background: {acc}; border-radius: 2px; }}
QSlider::handle:horizontal {{ width: 12px; height: 12px; margin: -8px 0; border-radius: 10px; background: {acc}; border: 4px solid {card if light else "#454545"}; }}
QProgressBar {{ background: {rgba(fg, 0.25)}; border: none; border-radius: 2px; max-height: 4px; text-align: center; }}
QProgressBar::chunk {{ background: {acc}; border-radius: 2px; }}
QToolTip {{ background: {flyout}; color: {fg}; border: 1px solid {stroke}; border-radius: 4px; padding: 4px 8px; }}
QStatusBar {{ color: {p["text2"]}; }}
"""


def icons(p, ctx):
    """The Win11 icon theme (yeyushengfan258's, in ~/.local/share/icons): its dark variant for dark
    themes (light symbolic icons), else the light one. Papirus if it isn't installed."""
    name = "Win11-dark" if ctx["appearance"] == "dark" else "Win11"
    for d in ("/usr/share/icons", os.path.expanduser("~/.local/share/icons"), os.path.expanduser("~/.icons")):
        if os.path.isdir(f"{d}/{name}"):
            return name
    return "Papirus-Dark" if ctx["appearance"] == "dark" else "Papirus"


# ---------------------------------------------------------------- cursors

def _shapes(p):
    """Windows 11's (Aero) cursors, drawn on a 64 grid: white with a black edge; the busy ring spins
    in the theme's accent (Windows' is its accent-blue ring)."""
    ink, paper = "#000000", "#ffffff"
    ring = p.get("purple", "#0078d4")

    def svg(body):
        return f'<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">{body}</svg>'

    arrow_d = "M4 2 L4 45 L14.5 35.5 L21.5 51.5 L28 48.8 L21.2 33 L35 33 Z"

    def arrow(extra=""):
        return lambda f, n: svg(f'<path d="{arrow_d}" fill="{paper}" stroke="{ink}" stroke-width="2" stroke-linejoin="round"/>' + extra)

    # the pointing hand: index finger up, three knuckles, the thumb out to the left
    hand_d = ("M22 6 C22 3.5 26.5 3.5 26.5 6 L26.5 26 L27.5 26 L27.5 21.5 C27.5 19 32 19 32 21.5 L32 27 L33 27 L33 23.5 "
              "C33 21 37.5 21 37.5 23.5 L37.5 28.5 L38.5 28.5 L38.5 26 C38.5 23.5 43 23.5 43 26 L43 42 C43 50 38 56 30 56 "
              "L27 56 C21 56 18.5 52 15.5 47 L8.5 36 C7 33.5 10.5 30.5 13 33 L22 41 Z")

    def spinner(f, n, r=14, cx=32, cy=32, w=4.5):
        a = f * 360 / n
        # the ring (faint) and the arc that chases round it
        return (f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="{ring}" stroke-opacity="0.25" stroke-width="{w}"/>'
                f'<g transform="rotate({a} {cx} {cy})"><path d="M{cx} {cy - r} A{r} {r} 0 0 1 {cx + r} {cy}" fill="none" '
                f'stroke="{ring}" stroke-width="{w}" stroke-linecap="round"/></g>')

    def outlined(d, width=2.2):
        # black shape, white edge (the resize and move arrows, the I-beam)
        return (f'<path d="{d}" fill="none" stroke="{paper}" stroke-width="{width + 3}" stroke-linejoin="round" stroke-linecap="round"/>'
                f'<path d="{d}" fill="none" stroke="{ink}" stroke-width="{width}" stroke-linejoin="round" stroke-linecap="round"/>')

    def double(angle):
        body = (f'<g transform="rotate({angle} 32 32)"><path d="M32 6 L41 16 L35 16 L35 48 L41 48 L32 58 L23 48 L29 48 L29 16 L23 16 Z" '
                f'fill="{ink}" stroke="{paper}" stroke-width="2" stroke-linejoin="round"/></g>')
        return lambda f, n: svg(body)

    move_d = ("M32 4 L40 13 L35 13 L35 29 L51 29 L51 24 L60 32 L51 40 L51 35 L35 35 L35 51 L40 51 L32 60 L24 51 L29 51 "
              "L29 35 L13 35 L13 40 L4 32 L13 24 L13 29 L29 29 L29 13 L24 13 Z")
    badge = (f'<rect x="36" y="40" width="20" height="20" rx="3" fill="{paper}" stroke="{ink}" stroke-width="1.6"/>')

    return {
        "arrow": (arrow(), (4, 2), 1),
        "pointer": (lambda f, n: svg(f'<path d="{hand_d}" fill="{paper}" stroke="{ink}" stroke-width="2.2" stroke-linejoin="round"/>'
                                     f'<path d="M27.5 27 L27.5 36 M33 28 L33 36 M38.5 29 L38.5 36" stroke="{ink}" stroke-width="1.4"/>'), (24, 4), 1),
        "text": (lambda f, n: svg(outlined("M24 10 C28 10 30 11 32 13 C34 11 36 10 40 10 M32 13 L32 51 M24 54 C28 54 30 53 32 51 "
                                           "C34 53 36 54 40 54 M27 32 L37 32", 2)), (32, 32), 1),
        "crosshair": (lambda f, n: svg(outlined("M32 8 L32 56 M8 32 L56 32", 1.8)), (32, 32), 1),
        "wait": (lambda f, n: svg(spinner(f, n, r=18, w=5)), (32, 32), 18),
        "progress": (lambda f, n: arrow(spinner(f, n, r=8, cx=46, cy=46, w=3.5))(f, n), (4, 2), 18),
        "move": (lambda f, n: svg(f'<path d="{move_d}" fill="{ink}" stroke="{paper}" stroke-width="2" stroke-linejoin="round"/>'), (32, 32), 1),
        "ns": (double(0), (32, 32), 1),
        "ew": (double(90), (32, 32), 1),
        "nwse": (double(-45), (32, 32), 1),
        "nesw": (double(45), (32, 32), 1),
        "forbidden": (lambda f, n: svg(f'<circle cx="32" cy="32" r="18" fill="none" stroke="{paper}" stroke-width="10"/>'
                                       f'<circle cx="32" cy="32" r="18" fill="none" stroke="{ink}" stroke-width="5"/>'
                                       f'<path d="M19 19 L45 45" stroke="{paper}" stroke-width="10"/><path d="M19 19 L45 45" stroke="{ink}" stroke-width="5"/>'), (32, 32), 1),
        "help": (arrow(badge + f'<text x="46" y="56" font-family="Segoe UI Variable Static Text,sans-serif" font-weight="bold" '
                               f'font-size="17" text-anchor="middle" fill="{ink}">?</text>'), (4, 2), 1),
        "copy": (arrow(badge + f'<path d="M46 44 V56 M40 50 H52" stroke="{ink}" stroke-width="2.6"/>'), (4, 2), 1),
        "link": (arrow(badge + f'<path d="M41 55 L51 45 M44 45 H51 V52" stroke="{ink}" stroke-width="2.4" fill="none"/>'), (4, 2), 1),
    }


def cursors(p, ctx):
    key = iconkit.palette_key(p.get("purple", "#0078d4"), "disguise-cursors-v1")
    return iconkit.cursor_theme(CURSOR_THEME, "Windows 11's cursors, with the busy ring in the theme's colour (written by the Disguise setup)",
                                _shapes(p), key)
