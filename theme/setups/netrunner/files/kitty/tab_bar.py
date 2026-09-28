# Netrunner's kitty tab bar (tab_bar_style custom), after the references' terminal header:
#   ▌TTY.03◤ bash // ~                                                     接続中
# Each tab is a tag: the active one solid red with dark text, the others dim; its title follows
# ("program // directory"); the far right says 接続中 ("connected") in cyan. Colours come from
# kitty's own colour settings (the theme writes them), so every profile recolours it.
from kitty.fast_data_types import Screen, get_options
from kitty.tab_bar import DrawData, ExtraData, TabBarData, as_rgb
from kitty.utils import color_as_int

SLANT = ""          # a powerline slant (Nerd Font): the tag's cut end
RIGHT = "接続中"


def _rgb(c):
    return as_rgb(color_as_int(c))


def draw_tab(draw_data: DrawData, screen: Screen, tab: TabBarData, before: int, max_title_length: int,
             index: int, is_last: bool, extra_data: ExtraData) -> int:
    opts = get_options()
    red = _rgb(opts.active_tab_foreground)          # the theme's accent
    bar_bg = _rgb(opts.tab_bar_background or opts.background)
    dim_bg = _rgb(opts.inactive_tab_background)
    dim_fg = _rgb(opts.inactive_tab_foreground)
    text = _rgb(opts.foreground)
    dark = _rgb(opts.background)
    cyan = _rgb(opts.url_color)

    # the tag
    screen.cursor.bold = True
    screen.cursor.bg = red if tab.is_active else dim_bg
    screen.cursor.fg = dark if tab.is_active else dim_fg
    screen.draw(f" TTY.{index:02d} ")
    screen.cursor.bold = False
    screen.cursor.fg = red if tab.is_active else dim_bg
    screen.cursor.bg = bar_bg
    screen.draw(SLANT)

    # the title: "program // place"
    title = tab.title or ""
    if " " not in title and "/" in title or title.startswith("~"):
        title = "shell // " + title
    title = title[: max(4, max_title_length)]
    screen.cursor.fg = text if tab.is_active else dim_fg
    screen.draw(f" {title} ")
    screen.cursor.fg = bar_bg
    screen.draw("  ")

    # the right-hand status, once, after the last tab
    if is_last:
        width = sum(2 if ord(ch) > 0x2E80 else 1 for ch in RIGHT) + 2
        room = screen.columns - screen.cursor.x - width
        if room > 0:
            screen.draw(" " * room)
            screen.cursor.fg = cyan
            screen.draw(RIGHT + "  ")
    return screen.cursor.x
