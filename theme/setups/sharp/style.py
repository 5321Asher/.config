"""Sharp's own look beyond colours: a square-folder icon theme and a flat, mitred cursor theme, both
drawn in the active colour theme's accent. GTK / Qt keep writers.py's built-in flat style.

Called by ~/.config/theme/writers.py on every theme switch (see writers.setup_style); each builder
only redraws when the colours it uses change. Themes land in ~/.local/share/icons/Sharp and
~/.local/share/icons/Sharp-Cursors.
"""

import iconkit

ICON_THEME = "Sharp"
CURSOR_THEME = "Sharp-Cursors"


# ---------------------------------------------------------------- icons

def icons(p, ctx):
    """Papirus's folders redrawn square: a cut-corner tab, flat accent front, no shadows or rounding.
    Papirus's own glyph (download arrow, music note, …) stays, in the theme's dark ink."""
    mix = ctx["mix"]
    light = ctx.get("appearance") == "light"
    front = p["accent"]
    back = mix(p["accent"], p["bgDark"], 0.45)
    edge = mix(p["accent"], "#ffffff", 0.3)
    paper = mix(p["fg"], p["bg"], 0.12) if not light else mix(p["bg"], "#ffffff", 0.6)
    ink = mix(p["bgDark"], p["accent"], 0.12) if not light else mix(p["fg"], p["accent"], 0.15)

    def draw(a):
        s = a["size"]
        fx, fy, fw, fh = a["front"]
        px, py, pw, ph = a.get("paper", (fx + fw * 0.1, fy - fh * 0.3, fw * 0.8, fh * 0.6))
        u = fw / 20                                   # one Papirus 24px-grid unit
        top = a["tab_top"]
        body = top + (fy - top) * 0.45                # where the back panel's top edge runs
        tab = fx + fw * 0.36
        back_path = (f"M {fx},{top} H {tab} L {tab + (body - top)},{body} H {fx + fw} "
                     f"V {fy + fh} H {fx} Z")
        return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{s:g}" height="{s:g}" version="1">\n'
                f' <path style="fill:{back}" d="{back_path}"/>\n'
                f' <rect style="fill:{paper}" x="{px}" y="{py}" width="{pw}" height="{ph}"/>\n'
                f' <rect style="fill:{front}" x="{fx}" y="{fy}" width="{fw}" height="{fh}"/>\n'
                f' <rect style="fill:{edge}" x="{fx}" y="{fy}" width="{fw}" height="{max(0.5, u * 0.5):g}"/>\n'
                + "".join(" " + g.replace("#1d344f", ink).replace("#1D344F", ink) + "\n" for g in a["glyph"])
                + "</svg>\n")

    key = iconkit.palette_key(front, back, edge, paper, ink, "sharp-icons-v2")
    inherits = "Papirus,Adwaita,hicolor" if light else "Papirus-Dark,Adwaita,hicolor"
    return iconkit.folder_theme(ICON_THEME, "Papirus with square folders (written by the Sharp setup)",
                                draw, key + ("l" if light else "d"), inherits)


# ---------------------------------------------------------------- cursors

def _shapes(p, mix):
    """{shape: (svg-maker(frame, frames), hotspot on a 64 grid, frames)}: flat accent, dark mitred
    outline, square details (a square spinner, a square 'no' sign, square badges)."""
    acc = p["accent"]
    hi = mix(p["accent"], "#ffffff", 0.35)
    ink = p["bgDark"] if sum(int(p["bgDark"][i:i + 2], 16) for i in (1, 3, 5)) < 200 else "#0a0a0a"
    fg = mix(p["fg"], "#ffffff", 0.4)
    bad = p["danger"]
    arrow_path = "M6 4 L6 48 L18 37 L27 57 L35 53 L26 34 L42 34 Z"

    def svg(body):
        return f'<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">{body}</svg>'

    def arrow(fill=acc, outline=ink, extra=""):
        return lambda f, n: svg(f'<path d="{arrow_path}" fill="{fill}" stroke="{outline}" stroke-width="3.5" '
                                f'stroke-linejoin="miter" stroke-miterlimit="10"/>' + extra)

    def badge(inner):
        return (f'<rect x="38" y="38" width="22" height="22" fill="{acc}" stroke="{ink}" stroke-width="3"/>' + inner)

    def square_spinner(x, y, cell, gap, f, n):
        # four squares round a 2x2 grid; the lit one walks clockwise
        order = [(0, 0), (1, 0), (1, 1), (0, 1)]
        lit = (f * 4 // n) % 4
        out = f'<rect x="{x - 2}" y="{y - 2}" width="{2 * cell + gap + 4}" height="{2 * cell + gap + 4}" fill="{ink}"/>'
        for i, (cx, cy) in enumerate(order):
            colour = hi if i == lit else mix(acc, ink, 0.55) if i == (lit - 1) % 4 else mix(acc, ink, 0.75)
            out += f'<rect x="{x + cx * (cell + gap)}" y="{y + cy * (cell + gap)}" width="{cell}" height="{cell}" fill="{colour}"/>'
        return out

    def double(angle):
        body = (f'<g transform="rotate({angle} 32 32)"><path d="M32 3 L46 18 L37 18 L37 46 L46 46 L32 61 L18 46 L27 46 '
                f'L27 18 L18 18 Z" fill="{acc}" stroke="{ink}" stroke-width="3.5" stroke-linejoin="miter"/></g>')
        return lambda f, n: svg(body)

    return {
        "arrow": (arrow(), (6, 4), 1),
        # hovering something clickable: the same arrow, inverted
        "pointer": (arrow(fill=fg, outline=acc), (6, 4), 1),
        "text": (lambda f, n: svg(
            f'<path d="M21 7 H43 M32 7 V57 M21 57 H43" stroke="{ink}" stroke-width="9" stroke-linecap="square" fill="none"/>'
            f'<path d="M21 7 H43 M32 7 V57 M21 57 H43" stroke="{acc}" stroke-width="4" stroke-linecap="square" fill="none"/>'), (32, 32), 1),
        "crosshair": (lambda f, n: svg(
            f'<path d="M32 2 V25 M32 39 V62 M2 32 H25 M39 32 H62" stroke="{ink}" stroke-width="6" stroke-linecap="square"/>'
            f'<path d="M32 2 V25 M32 39 V62 M2 32 H25 M39 32 H62" stroke="{acc}" stroke-width="2.5" stroke-linecap="square"/>'
            f'<rect x="29" y="29" width="6" height="6" fill="{acc}" stroke="{ink}" stroke-width="2"/>'), (32, 32), 1),
        "wait": (lambda f, n: svg(square_spinner(15, 15, 15, 4, f, n)), (32, 32), 8),
        "progress": (lambda f, n: arrow(extra=square_spinner(38, 38, 9, 3, f, n))(f, n), (6, 4), 8),
        "move": (lambda f, n: svg(
            f'<path d="M32 3 L43 15 L36 15 L36 28 L49 28 L49 21 L61 32 L49 43 L49 36 L36 36 L36 49 L43 49 L32 61 '
            f'L21 49 L28 49 L28 36 L15 36 L15 43 L3 32 L15 21 L15 28 L28 28 L28 15 L21 15 Z" '
            f'fill="{acc}" stroke="{ink}" stroke-width="3.5" stroke-linejoin="miter"/>'), (32, 32), 1),
        "ns": (double(0), (32, 32), 1),
        "ew": (double(90), (32, 32), 1),
        "nwse": (double(-45), (32, 32), 1),
        "nesw": (double(45), (32, 32), 1),
        "forbidden": (lambda f, n: svg(
            f'<rect x="10" y="10" width="44" height="44" fill="none" stroke="{ink}" stroke-width="10"/>'
            f'<rect x="10" y="10" width="44" height="44" fill="none" stroke="{bad}" stroke-width="5"/>'
            f'<path d="M14 14 L50 50" stroke="{ink}" stroke-width="10"/><path d="M14 14 L50 50" stroke="{bad}" stroke-width="5"/>'), (32, 32), 1),
        "help": (arrow(extra=badge(f'<text x="49" y="56" font-family="{p.get("fontMono", "monospace")}" font-weight="bold" '
                                   f'font-size="17" text-anchor="middle" fill="{ink}">?</text>')), (6, 4), 1),
        "copy": (arrow(extra=badge(f'<path d="M49 42 V56 M42 49 H56" stroke="{ink}" stroke-width="3.5"/>')), (6, 4), 1),
        "link": (arrow(extra=badge(f'<path d="M43 55 L55 43 M46 43 H55 V52" stroke="{ink}" stroke-width="3" fill="none"/>')), (6, 4), 1),
    }


def cursors(p, ctx):
    """Flat accent cursors with a dark mitred outline, redrawn when the theme's colours change."""
    key = iconkit.palette_key(p["accent"], p["bgDark"], p["fg"], p["danger"], "sharp-cursors-v1")
    return iconkit.cursor_theme(CURSOR_THEME, "Flat, mitred cursors in the theme accent (written by the Sharp setup)",
                                _shapes(p, ctx["mix"]), key)
