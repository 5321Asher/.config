"""Observatory's look for GTK, Qt and Satty (used by ~/.config/theme/writers.py when this setup is active).

Brass instruments on a night sky: rounded plates with brass hairlines, buttons that glow when you
reach for them, headerbars with a brass horizon line and small-caps Cormorant titles, phosphor
readouts (progress, selection), and a faint star-dust field behind window chrome and sidebars.

Each function gets the theme palette `p` (bg, bgDark, surface, hover, border, dim, fg, accent = brass,
accentText, accentMuted, purple = phosphor, warn, danger, green, and brassBright, brassDeep, phosphor,
phosphorDim, signal, starlight) and `ctx` (mix, rgba, fonts, dir, cache) and returns CSS / QSS.
"""

import hashlib
import os
import random
import subprocess

RADIUS = 6


def c(p, key, fallback="accent"):
    return p.get(key) or p[fallback]


def stardust(p, ctx, size=360):
    """A tileable PNG of faint stars in the theme's colours, cached per palette."""
    cols = [c(p, "starlight", "fg"), c(p, "starlight", "fg"), c(p, "starlight", "fg"), c(p, "phosphor", "purple"),
            c(p, "brassBright")]
    key = hashlib.sha1(("|".join(cols) + str(size)).encode()).hexdigest()[:10]
    out = f"{ctx['cache']}/stardust-{key}.png"
    if os.path.exists(out):
        return out
    os.makedirs(ctx["cache"], exist_ok=True)
    rnd = random.Random(42)
    dots = []
    for _ in range(46):
        x, y = rnd.uniform(0, size), rnd.uniform(0, size)
        r = rnd.choice([0.45, 0.55, 0.65, 0.8, 1.0])
        a = rnd.uniform(0.12, 0.42)
        col = rnd.choice(cols)
        # draw near edges on the opposite side too, so the tile wraps without seams
        for dx in (0, -size, size):
            for dy in (0, -size, size):
                dots.append(f'<circle cx="{x + dx:.1f}" cy="{y + dy:.1f}" r="{r}" fill="{col}" opacity="{a:.2f}"/>')
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}">'
           + "".join(dots) + "</svg>")
    tmp = out + ".svg"
    with open(tmp, "w") as f:
        f.write(svg)
    subprocess.run(["magick", "-background", "none", tmp, out], stdout=subprocess.DEVNULL,
                   stderr=subprocess.DEVNULL, timeout=30)
    os.unlink(tmp)
    return out


# ---------------------------------------------------------------- GTK 3

def gtk3(p, ctx):
    mix, rgba = ctx["mix"], ctx["rgba"]
    brass, bright, deep = p["accent"], c(p, "brassBright"), c(p, "brassDeep", "accentMuted")
    phos, star = c(p, "phosphor", "purple"), c(p, "starlight", "fg")
    label = ctx["fonts"].get("display", "serif")
    dust = stardust(p, ctx)
    r = RADIUS
    return f"""
/* Observatory: brass instruments on a night sky */
* {{ outline-color: {rgba(brass, 0.55)}; -gtk-outline-radius: {r}px; }}

window.background, dialog, .background {{
  background-color: {p["bg"]};
  color: {p["fg"]};
}}
window.background, .sidebar, .sidebar .view, placessidebar, placessidebar .view, stacksidebar {{
  background-image: url("file://{dust}");
  background-repeat: repeat;
}}
decoration {{ border-radius: {r + 2}px {r + 2}px 0 0; box-shadow: 0 6px 22px rgba(0, 0, 0, 0.55), 0 0 0 1px {rgba(brass, 0.35)}; }}
decoration:backdrop {{ box-shadow: 0 4px 14px rgba(0, 0, 0, 0.45), 0 0 0 1px {rgba(p["border"], 0.9)}; }}

/* Headerbars: a dark plate with a brass horizon along the bottom */
headerbar, .titlebar {{
  background-image: linear-gradient(to bottom, {p["bgDark"]}, {mix(p["bgDark"], p["bg"], 0.6)});
  color: {p["fg"]};
  border: none;
  border-bottom: 1px solid {rgba(brass, 0.55)};
  box-shadow: inset 0 -1px {rgba(brass, 0.18)}, 0 1px 6px {rgba(brass, 0.12)};
  border-radius: {r + 2}px {r + 2}px 0 0;
  min-height: 40px;
}}
headerbar:backdrop, .titlebar:backdrop {{
  background-image: none;
  background-color: {p["bgDark"]};
  border-bottom-color: {rgba(brass, 0.25)};
  box-shadow: none;
}}
headerbar .title, .titlebar .title {{
  font-family: "{label}";
  font-feature-settings: "smcp";
  font-size: 13pt;
  font-weight: 600;
  letter-spacing: 1px;
  color: {bright};
}}
headerbar .subtitle {{ color: {p["dim"]}; }}

/* Buttons: brass-rimmed plates that glow when reached for */
button {{
  background-image: linear-gradient(to bottom, {p["surface"]}, {p["bgDark"]});
  color: {p["fg"]};
  border: 1px solid {rgba(brass, 0.4)};
  border-radius: {r}px;
  box-shadow: inset 0 1px {rgba(star, 0.04)};
  text-shadow: none;
  -gtk-icon-shadow: none;
  transition: all 200ms cubic-bezier(0.33, 1, 0.68, 1);
}}
button:hover {{
  border-color: {brass};
  color: {bright};
  box-shadow: 0 0 8px {rgba(brass, 0.35)}, inset 0 1px {rgba(star, 0.06)};
}}
button:active, button:checked {{
  background-image: linear-gradient(to bottom, {p["accentMuted"]}, {mix(p["accentMuted"], p["bgDark"], 0.5)});
  border-color: {bright};
  color: {star};
  box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.5), 0 0 6px {rgba(brass, 0.3)};
}}
button:disabled {{ background-image: none; background-color: {p["bg"]}; color: {p["dim"]}; border-color: {rgba(p["border"], 0.8)}; }}
button:backdrop {{ box-shadow: none; }}
button.flat, headerbar button, toolbar button {{ background-image: none; background-color: transparent; border-color: transparent; box-shadow: none; }}
button.flat:hover, headerbar button:hover, toolbar button:hover {{
  background-color: {rgba(brass, 0.1)};
  border-color: {rgba(brass, 0.5)};
  box-shadow: 0 0 6px {rgba(brass, 0.25)};
}}
button.suggested-action {{
  background-image: linear-gradient(to bottom, {bright}, {brass});
  color: {p["bgDark"]};
  border-color: {bright};
  font-weight: 600;
}}
button.suggested-action:hover {{ box-shadow: 0 0 12px {rgba(bright, 0.55)}; color: {p["bgDark"]}; }}
button.destructive-action {{
  background-image: linear-gradient(to bottom, {c(p, "signal", "danger")}, {mix(c(p, "signal", "danger"), p["bgDark"], 0.3)});
  color: {star};
  border-color: {c(p, "signal", "danger")};
}}

/* Text entries: dark wells, brass focus ring */
entry, spinbutton:not(.vertical) {{
  background-color: {p["bgDark"]};
  background-image: none;
  color: {p["fg"]};
  border: 1px solid {rgba(brass, 0.28)};
  border-radius: {r}px;
  box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.45);
  caret-color: {phos};
  transition: all 200ms ease-out;
}}
entry:focus, spinbutton:focus {{
  border-color: {brass};
  box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.45), 0 0 0 1px {rgba(brass, 0.35)}, 0 0 10px {rgba(brass, 0.25)};
}}
entry:disabled {{ color: {p["dim"]}; }}
entry image {{ color: {brass}; }}
spinbutton button {{ border-radius: 0; border: none; box-shadow: none; background-image: none; }}

/* Selection: a phosphor glow */
selection, *:selected, *:selected:focus, row:selected, treeview.view:selected, iconview:selected,
.view:selected, textview text selection, entry selection, flowboxchild:selected {{
  background-color: {rgba(phos, 0.22)};
  color: {star};
}}
rubberband, .rubberband {{ background-color: {rgba(phos, 0.15)}; border: 1px solid {phos}; border-radius: 3px; }}

/* Views, lists, sidebars */
.view, treeview.view, iconview, textview text, list {{ background-color: {p["bgDark"]}; color: {p["fg"]}; }}
.view:hover, treeview.view:hover, iconview:hover, row:hover {{ background-color: {rgba(brass, 0.08)}; }}
row {{ border-radius: {r - 2}px; }}
.sidebar, .sidebar .view, placessidebar, placessidebar list, stacksidebar list {{
  background-color: {p["bgDark"]};
  color: {p["fg"]};
  border-color: {rgba(brass, 0.25)};
}}
.sidebar row:selected, placessidebar row:selected {{
  background-color: {rgba(brass, 0.16)};
  color: {bright};
  box-shadow: inset 2px 0 {bright};
}}
treeview.view header button {{
  background-image: none;
  background-color: {p["bg"]};
  color: {brass};
  font-family: "{label}";
  font-feature-settings: "smcp";
  font-weight: 600;
  letter-spacing: 1px;
  border: none;
  border-radius: 0;
  border-bottom: 1px solid {rgba(brass, 0.35)};
  box-shadow: none;
}}
treeview.view header button:hover {{ color: {bright}; }}
frame > border, .frame {{ border-color: {rgba(brass, 0.25)}; border-radius: {r}px; box-shadow: none; }}
scrolledwindow > undershoot {{ box-shadow: none; }}

/* Menus, popovers and tooltips: transmissions */
menubar {{ background: {p["bgDark"]}; box-shadow: none; border-bottom: 1px solid {rgba(brass, 0.3)}; }}
menubar > menuitem {{ color: {p["fg"]}; border-radius: {r - 2}px; }}
menubar > menuitem:hover {{ color: {bright}; box-shadow: inset 0 -2px {brass}; }}
menu, .menu, .context-menu, popover, popover.background {{
  background-color: {rgba(p["bgDark"], 0.97)};
  color: {p["fg"]};
  border: 1px solid {rgba(brass, 0.6)};
  border-radius: {r + 2}px;
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.6), 0 0 10px {rgba(brass, 0.15)};
  padding: 5px;
}}
menu menuitem, .menu menuitem {{ padding: 6px 10px; border-radius: {r - 2}px; }}
menu menuitem:hover, .menu menuitem:hover, modelbutton.flat:hover, popover modelbutton:hover {{
  background-color: {rgba(brass, 0.18)};
  color: {bright};
}}
menu menuitem:disabled {{ color: {p["dim"]}; }}
menu separator, popover separator {{ background-color: {rgba(brass, 0.2)}; margin: 4px 6px; }}
menuitem accelerator {{ color: {p["dim"]}; }}
tooltip, tooltip.background {{
  background-color: {rgba(p["bgDark"], 0.96)};
  color: {p["fg"]};
  border: 1px solid {brass};
  border-radius: {r}px;
  box-shadow: 0 0 10px {rgba(brass, 0.25)};
}}
tooltip * {{ background: transparent; color: {p["fg"]}; }}

/* Tabs: the open one gets a brass horizon */
notebook > header {{ background-color: {p["bgDark"]}; border-color: {rgba(brass, 0.25)}; }}
notebook > header tab {{ border-radius: {r - 2}px {r - 2}px 0 0; color: {p["dim"]}; padding: 6px 14px; }}
notebook > header tab:hover {{ color: {p["fg"]}; box-shadow: none; background-color: {rgba(brass, 0.06)}; }}
notebook > header tab:checked {{ color: {bright}; background-color: {p["bg"]}; }}
notebook > header.top tab:checked {{ box-shadow: inset 0 -2px {bright}, 0 2px 8px {rgba(brass, 0.25)}; }}
notebook > header.bottom tab:checked {{ box-shadow: inset 0 2px {bright}; }}
notebook > header.left tab:checked {{ box-shadow: inset -2px 0 {bright}; }}
notebook > header.right tab:checked {{ box-shadow: inset 2px 0 {bright}; }}
notebook > stack:not(:only-child) {{ background-color: {p["bg"]}; }}

/* Scrollbars: slim brass rails */
scrollbar, scrollbar:backdrop {{ background: transparent; border: none; }}
scrollbar slider {{ background-color: {rgba(brass, 0.35)}; border: none; border-radius: 99px; min-width: 5px; min-height: 5px; }}
scrollbar slider:hover {{ background-color: {brass}; }}
scrollbar slider:active {{ background-color: {bright}; box-shadow: 0 0 6px {rgba(brass, 0.5)}; }}

/* Toggles */
check, radio {{
  background-color: {p["bgDark"]};
  background-image: none;
  color: {p["bgDark"]};
  border: 1px solid {rgba(brass, 0.55)};
  box-shadow: none;
  transition: all 200ms ease-out;
}}
check {{ border-radius: 4px; }}
radio {{ border-radius: 99px; }}
check:hover, radio:hover {{ border-color: {bright}; box-shadow: 0 0 6px {rgba(brass, 0.35)}; }}
check:checked, check:indeterminate, radio:checked {{
  background-image: linear-gradient(to bottom, {bright}, {brass});
  border-color: {bright};
}}
switch {{
  background-color: {p["bgDark"]};
  background-image: none;
  border: 1px solid {rgba(brass, 0.45)};
  border-radius: 99px;
  color: {p["dim"]};
  box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.5);
}}
switch:checked {{ background-color: {p["accentMuted"]}; border-color: {brass}; color: {star}; }}
switch slider {{
  background-image: linear-gradient(to bottom, {bright}, {brass});
  border: 1px solid {p["bgDark"]};
  border-radius: 99px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.5);
}}
switch:not(:checked) slider {{ background-image: linear-gradient(to bottom, {p["dim"]}, {mix(p["dim"], p["bgDark"], 0.4)}); }}

/* Bars: phosphor readouts */
progressbar trough, scale trough, levelbar trough {{
  background-color: {p["bgDark"]};
  border: 1px solid {rgba(brass, 0.25)};
  border-radius: 99px;
  box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.5);
}}
progressbar progress, scale highlight, levelbar block.filled {{
  background-image: linear-gradient(to right, {phos}, {brass});
  border: none;
  border-radius: 99px;
  box-shadow: 0 0 6px {rgba(phos, 0.45)};
}}
scale slider {{
  background-image: linear-gradient(to bottom, {bright}, {brass});
  border: 1px solid {p["bgDark"]};
  border-radius: 99px;
  box-shadow: 0 0 6px {rgba(brass, 0.4)};
}}

separator {{ background-color: {rgba(brass, 0.2)}; }}
statusbar {{ background: {p["bgDark"]}; color: {p["dim"]}; border-top: 1px solid {rgba(brass, 0.25)}; }}
infobar box {{ background: {p["surface"]}; border-radius: {r}px; border: 1px solid {rgba(brass, 0.4)}; }}
toolbar, .inline-toolbar, searchbar > revealer > box {{ background: {p["bgDark"]}; border-color: {rgba(brass, 0.25)}; }}
"""


# ---------------------------------------------------------------- GTK 4

def gtk4(p, ctx):
    """GTK4 / libadwaita: colours and rounding only. User CSS outranks an app's own stylesheet, so
    widget rules here would clobber apps with their own look (Walker)."""
    return f"""
:root {{
  --window-radius: {RADIUS + 4}px;
  --accent-color: {c(p, "brassBright")};
}}
"""


# ---------------------------------------------------------------- Qt (qt6ct stylesheet)

def qss(p, ctx):
    mix, rgba = ctx["mix"], ctx["rgba"]
    brass, bright = p["accent"], c(p, "brassBright")
    phos, star = c(p, "phosphor", "purple"), c(p, "starlight", "fg")
    dust = stardust(p, ctx)
    r = RADIUS
    return f"""/* Observatory: brass instruments on a night sky */
QMainWindow, QDialog {{
  background-color: {p["bg"]};
  background-image: url({dust});
}}
QPushButton, QComboBox {{
  background-color: qlineargradient(x1:0, y1:0, x2:0, y2:1, stop:0 {p["surface"]}, stop:1 {p["bgDark"]});
  color: {p["fg"]};
  border: 1px solid {rgba(brass, 0.4)};
  border-radius: {r}px;
  padding: 5px 12px;
}}
QPushButton:hover, QComboBox:hover {{ border-color: {brass}; color: {bright}; }}
QPushButton:pressed, QPushButton:checked {{
  background-color: qlineargradient(x1:0, y1:0, x2:0, y2:1, stop:0 {p["accentMuted"]}, stop:1 {mix(p["accentMuted"], p["bgDark"], 0.5)});
  border-color: {bright};
  color: {star};
}}
QPushButton:default {{
  background-color: qlineargradient(x1:0, y1:0, x2:0, y2:1, stop:0 {bright}, stop:1 {brass});
  color: {p["bgDark"]};
  border-color: {bright};
  font-weight: 600;
}}
QPushButton:disabled, QComboBox:disabled {{ color: {p["dim"]}; background-color: {p["bg"]}; border-color: {p["border"]}; }}
QToolButton {{ background: transparent; border: 1px solid transparent; border-radius: {r}px; padding: 3px; }}
QToolButton:hover {{ background-color: {rgba(brass, 0.12)}; border-color: {rgba(brass, 0.5)}; }}
QToolButton:pressed, QToolButton:checked {{ background-color: {rgba(brass, 0.22)}; border-color: {bright}; }}

QLineEdit, QTextEdit, QPlainTextEdit, QSpinBox, QDoubleSpinBox {{
  background-color: {p["bgDark"]};
  color: {p["fg"]};
  border: 1px solid {rgba(brass, 0.28)};
  border-radius: {r}px;
  padding: 4px 8px;
  selection-background-color: {rgba(phos, 0.3)};
  selection-color: {star};
}}
QLineEdit:focus, QTextEdit:focus, QPlainTextEdit:focus, QSpinBox:focus, QDoubleSpinBox:focus, QComboBox:focus {{
  border-color: {brass};
}}
QComboBox::drop-down {{ border: none; width: 22px; }}
QComboBox QAbstractItemView {{
  background-color: {p["bgDark"]}; color: {p["fg"]}; border: 1px solid {rgba(brass, 0.6)};
  border-radius: {r}px; selection-background-color: {rgba(brass, 0.22)}; outline: 0; padding: 4px;
}}

QMenuBar {{ background-color: {p["bgDark"]}; border-bottom: 1px solid {rgba(brass, 0.3)}; }}
QMenuBar::item {{ background: transparent; padding: 4px 10px; border-radius: {r - 2}px; }}
QMenuBar::item:selected {{ color: {bright}; background-color: {rgba(brass, 0.12)}; }}
QMenu {{
  background-color: {p["bgDark"]}; color: {p["fg"]};
  border: 1px solid {rgba(brass, 0.6)}; border-radius: {r + 2}px; padding: 5px;
}}
QMenu::item {{ padding: 6px 22px 6px 12px; border-radius: {r - 2}px; }}
QMenu::item:selected {{ background-color: {rgba(brass, 0.2)}; color: {bright}; }}
QMenu::item:disabled {{ color: {p["dim"]}; }}
QMenu::separator {{ height: 1px; background: {rgba(brass, 0.2)}; margin: 4px 8px; }}

QToolTip {{
  background-color: {p["bgDark"]}; color: {p["fg"]};
  border: 1px solid {brass}; border-radius: {r}px; padding: 5px 8px;
}}

QTabWidget::pane {{ border: 1px solid {rgba(brass, 0.3)}; border-radius: {r}px; top: -1px; background: {p["bg"]}; }}
QTabBar::tab {{
  background: {p["bgDark"]}; color: {p["dim"]};
  border: 1px solid {rgba(brass, 0.25)}; border-bottom: none;
  border-top-left-radius: {r}px; border-top-right-radius: {r}px;
  padding: 6px 16px; margin-right: 2px;
}}
QTabBar::tab:hover {{ color: {p["fg"]}; }}
QTabBar::tab:selected {{ background: {p["bg"]}; color: {bright}; border-color: {rgba(brass, 0.7)}; border-bottom: 2px solid {bright}; }}

QHeaderView::section {{
  background-color: {p["bg"]}; color: {brass}; border: none;
  border-right: 1px solid {rgba(brass, 0.15)}; border-bottom: 1px solid {rgba(brass, 0.4)};
  padding: 5px 8px; font-weight: 600;
}}
QAbstractItemView {{
  background-color: {p["bgDark"]}; alternate-background-color: {mix(p["bgDark"], p["bg"], 0.5)};
  outline: 0; border-radius: {r}px;
}}
QAbstractItemView::item {{ border-radius: {r - 3}px; padding: 2px; }}
QAbstractItemView::item:hover {{ background: {rgba(brass, 0.1)}; }}
QAbstractItemView::item:selected {{ background: {rgba(phos, 0.22)}; color: {star}; }}
QGroupBox {{ border: 1px solid {rgba(brass, 0.3)}; border-radius: {r}px; margin-top: 14px; padding-top: 8px; }}
QGroupBox::title {{ subcontrol-origin: margin; left: 10px; padding: 0 6px; color: {bright}; }}

QScrollBar:vertical {{ background: transparent; width: 9px; margin: 2px; }}
QScrollBar:horizontal {{ background: transparent; height: 9px; margin: 2px; }}
QScrollBar::handle {{ background: {rgba(brass, 0.35)}; border-radius: 4px; min-height: 24px; min-width: 24px; }}
QScrollBar::handle:hover {{ background: {brass}; }}
QScrollBar::add-line, QScrollBar::sub-line {{ width: 0; height: 0; border: none; }}
QScrollBar::add-page, QScrollBar::sub-page {{ background: none; }}

QCheckBox::indicator, QRadioButton::indicator {{
  width: 14px; height: 14px; background: {p["bgDark"]}; border: 1px solid {rgba(brass, 0.55)};
}}
QCheckBox::indicator {{ border-radius: 4px; }}
QRadioButton::indicator {{ border-radius: 8px; }}
QCheckBox::indicator:checked, QRadioButton::indicator:checked {{
  background: qlineargradient(x1:0, y1:0, x2:0, y2:1, stop:0 {bright}, stop:1 {brass}); border-color: {bright};
}}

QProgressBar {{
  background: {p["bgDark"]}; border: 1px solid {rgba(brass, 0.3)}; border-radius: 6px;
  text-align: center; color: {star}; height: 12px;
}}
QProgressBar::chunk {{ background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 {phos}, stop:1 {brass}); border-radius: 5px; }}
QSlider::groove:horizontal {{ background: {p["bgDark"]}; height: 4px; border-radius: 2px; border: 1px solid {rgba(brass, 0.25)}; }}
QSlider::sub-page:horizontal {{ background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 {phos}, stop:1 {brass}); border-radius: 2px; }}
QSlider::handle:horizontal {{
  background: qlineargradient(x1:0, y1:0, x2:0, y2:1, stop:0 {bright}, stop:1 {brass});
  border: 1px solid {p["bgDark"]}; width: 14px; margin: -6px 0; border-radius: 7px;
}}
QStatusBar {{ background: {p["bgDark"]}; color: {p["dim"]}; border-top: 1px solid {rgba(brass, 0.25)}; }}
QSplitter::handle {{ background: {rgba(brass, 0.2)}; }}
"""


# ---------------------------------------------------------------- Satty (screenshot editor)

def satty(p, ctx):
    rgba = ctx["rgba"]
    brass, bright = p["accent"], c(p, "brassBright")
    r = RADIUS
    return f"""@define-color accent_color        {bright};
@define-color accent_bg_color     {brass};
@define-color accent_fg_color     {p["bgDark"]};
@define-color window_bg_color     {p["bg"]};
@define-color window_fg_color     {p["fg"]};
@define-color view_bg_color       {p["bgDark"]};
@define-color view_fg_color       {p["fg"]};
@define-color headerbar_bg_color  {p["bgDark"]};
@define-color headerbar_fg_color  {p["fg"]};
@define-color popover_bg_color    {p["bgDark"]};
@define-color popover_fg_color    {p["fg"]};
@define-color borders             {rgba(brass, 0.4)};
window, .outer_box {{ color: {p["fg"]}; background-color: {p["bg"]}; }}
.inner_box {{ background-color: {p["bgDark"]}; }}
.toolbar {{
  color: {p["fg"]};
  background-color: {rgba(p["bgDark"], 0.94)};
  border: 1px solid {rgba(brass, 0.55)};
  border-radius: {r + 2}px;
  box-shadow: 0 6px 18px rgba(0, 0, 0, 0.5), 0 0 10px {rgba(brass, 0.15)};
}}
.toolbar button, .toolbar togglebutton > button, .toolbar menubutton > button {{
  color: {p["fg"]}; background: none; border-radius: {r}px; box-shadow: none;
}}
.toolbar button:hover {{ background-color: {rgba(brass, 0.14)}; color: {bright}; }}
.toolbar button:checked, .toolbar button.editing {{
  color: {bright};
  background-color: {rgba(brass, 0.2)};
  box-shadow: inset 0 0 0 1px {rgba(brass, 0.7)};
}}
popover > contents {{ color: {p["fg"]}; background-color: {p["bgDark"]}; border: 1px solid {rgba(brass, 0.6)}; border-radius: {r + 2}px; }}
entry, spinbutton {{ background-color: {p["bgDark"]}; color: {p["fg"]}; border-radius: {r}px; }}
.toast {{ color: {p["fg"]}; background-color: {rgba(p["bgDark"], 0.94)}; border: 1px solid {brass}; border-radius: {r}px; }}
"""


# ---------------------------------------------------------------- icons

ICON_THEME = "Observatory"
PAPIRUS = "/usr/share/icons/Papirus"
PAPIRUS_DARK = "/usr/share/icons/Papirus-Dark"


def icons(p, ctx):
    """An icon theme that is Papirus-Dark with brass folders (in the colour theme's brass).
    Rebuilt in ~/.local/share/icons/Observatory only when the colours change. Returns its name."""
    mix = ctx["mix"]
    if not os.path.isdir(PAPIRUS):
        return None
    front, back = p["accent"], c(p, "brassDeep", "accentMuted")
    glyph = mix(p["bgDark"], back, 0.25)
    root = os.path.expanduser(f"~/.local/share/icons/{ICON_THEME}")
    key = hashlib.sha1(f"{front}{back}{glyph}v1".encode()).hexdigest()[:12]
    marker = f"{root}/.palette"
    try:
        if open(marker).read().strip() == key:
            return ICON_THEME
    except OSError:
        pass

    recolor = {"#5294e2": front, "#4877b1": back, "#e4e4e4": glyph, "#ffffff": glyph}
    dirs = []
    for size in sorted(os.listdir(PAPIRUS)):
        src = f"{PAPIRUS}/{size}/places"
        if not os.path.isdir(src) or os.path.islink(f"{PAPIRUS}/{size}"):
            continue
        out = f"{root}/{size}/places"
        os.makedirs(out, exist_ok=True)
        made = 0
        # Every name Papirus(-Dark) resolves to a blue folder (folder.svg, user-home.svg, …), plus the originals
        names = set(os.listdir(src))
        dark = f"{PAPIRUS_DARK}/{size}/places"
        if os.path.isdir(dark):
            names |= set(os.listdir(dark))
        for name in names:
            path = f"{dark}/{name}" if os.path.exists(f"{dark}/{name}") else f"{src}/{name}"
            real = os.path.realpath(path)
            if not os.path.basename(real).startswith("folder-blue") or not real.endswith(".svg"):
                continue
            with open(real) as f:
                svg = f.read()
            for a, b in recolor.items():
                svg = svg.replace(a, b).replace(a.upper(), b)
            with open(f"{out}/{name}", "w") as f:
                f.write(svg)
            made += 1
        if made:
            dim, _, scale = size.partition("@")
            dirs.append((f"{size}/places", int(dim.split("x")[0]), int(scale[:-1]) if scale else 1))

    with open(f"{root}/index.theme", "w") as f:
        f.write("[Icon Theme]\nName=Observatory\nComment=Papirus-Dark with brass folders (written by the Observatory setup)\n"
                "Inherits=Papirus-Dark,Adwaita,hicolor\n"
                f"Directories={','.join(d for d, _, _ in dirs)}\n\n")
        for d, size, scale in dirs:
            f.write(f"[{d}]\nContext=Places\nSize={size}\n" + (f"Scale={scale}\n" if scale > 1 else "") + "Type=Fixed\n\n")
    with open(marker, "w") as f:
        f.write(key + "\n")
    return ICON_THEME
