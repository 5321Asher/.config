# Disguise: kitty's tab strip drawn as Windows Terminal's. The strip is the dark title-bar grey, the
# active tab is the terminal's own black (so it joins the page below it), inactive tabs are grey text
# with a hairline between them, and each tab carries the PowerShell icon, its title and a close ✕.
# Linked to ~/.config/kitty/tab_bar.py while Disguise is the setup (kitty.conf: tab_bar_style custom).

from kitty.fast_data_types import Screen
from kitty.tab_bar import DrawData, ExtraData, TabBarData, as_rgb

STRIP = 0x202020        # Windows Terminal's tab row (dark Mica)
ACTIVE = 0x0C0C0C       # the terminal background (Campbell)
TEXT = 0xFFFFFF
DIM = 0xB3B3B3
LINE = 0x3A3A3A
ICON = 0x2B88D8         # PowerShell's blue
WIDTH = 30              # cells per tab, like WT's equal-width tabs


def draw_tab(draw_data: DrawData, screen: Screen, tab: TabBarData, before: int, max_title_length: int,
             index: int, is_last: bool, extra_data: ExtraData) -> int:
    active = tab.is_active
    bg = ACTIVE if active else STRIP
    title = tab.title or "Windows PowerShell"
    room = WIDTH - 8
    if len(title) > room:
        title = title[: room - 1] + "…"

    # a hairline before an inactive tab that doesn't follow the active one
    if index > 1 and not active and not (extra_data.prev_tab and extra_data.prev_tab.is_active):
        screen.cursor.bg = as_rgb(STRIP)
        screen.cursor.fg = as_rgb(LINE)
        screen.draw("│")
    else:
        screen.cursor.bg = as_rgb(STRIP)
        screen.draw(" ")

    screen.cursor.bg = as_rgb(bg)
    screen.cursor.fg = as_rgb(ICON)
    screen.draw("  \U000f0a0a ")               # nf-md-powershell
    screen.cursor.fg = as_rgb(TEXT if active else DIM)
    screen.draw(" " + title.ljust(room))
    screen.cursor.fg = as_rgb(TEXT if active else DIM)
    screen.draw(" \U000f0156  ")            # nf-md-close, WT's thin ✕
    screen.cursor.bg = as_rgb(STRIP)
    return screen.cursor.x
