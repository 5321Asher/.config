# Glyph's kitty tab bar (tab_bar_style custom): each tab a pill,  01 title  ; the active one is the
# white pill with ink text, the others grey on the bar. Colours come from kitty's own settings (the
# theme writes them), so Dark and Light both work.
from kitty.fast_data_types import Screen, get_options
from kitty.tab_bar import DrawData, ExtraData, TabBarData, as_rgb
from kitty.utils import color_as_int

LEFT, RIGHT = "", ""     # Nerd Font half-circles: the pill's round ends


def _rgb(c):
    return as_rgb(color_as_int(c))


def draw_tab(draw_data: DrawData, screen: Screen, tab: TabBarData, before: int, max_title_length: int,
             index: int, is_last: bool, extra_data: ExtraData) -> int:
    opts = get_options()
    bar = _rgb(opts.tab_bar_background or opts.background)
    fg = _rgb(opts.foreground)
    ink = _rgb(opts.background)
    grey = _rgb(opts.inactive_tab_foreground)
    pill = fg if tab.is_active else _rgb(opts.inactive_tab_background)
    text = ink if tab.is_active else grey

    title = tab.title if len(tab.title) <= 28 else tab.title[:27] + "…"
    screen.cursor.bg = bar
    screen.cursor.fg = pill
    screen.draw(LEFT)
    screen.cursor.bg = pill
    screen.cursor.fg = text
    screen.cursor.bold = tab.is_active
    screen.draw(f"{index:02d} {title}")
    screen.cursor.bold = False
    screen.cursor.bg = bar
    screen.cursor.fg = pill
    screen.draw(RIGHT)
    screen.draw(" ")
    return screen.cursor.x
