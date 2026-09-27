"""Curses manager for setups, their themes and the wallpapers you assign to them.
Started by `theme` / `theme pool`.

Main screen: the managed setup's themes on the left (+ Setup, + Pool), the highlighted one's
wallpapers on the right; S picks which setup to manage. Pool screen: every wallpaper you have, with a
preview; number keys put the highlighted one in / take it out of a theme, s in / out of the setup as a
whole. Changes that affect the active theme reach skwd-wall immediately.
"""

import base64
import curses
import fcntl
import os
import re
import shutil
import struct
import subprocess
import sys
import termios

POOL = "_pool"
ALL = "_all"
NAMES = {POOL: "Pool (all wallpapers)", ALL: "Setup (any theme)"}
KEYS = "1234567890"   # theme 1..10 in the pool screen
FILTERS = ("all", "unassigned", "assigned")

HELP = {
    "themes": "enter apply · a assign wallpapers · S setup · w walker image · f fastfetch image · e edit · "
              "n new · → wallpapers · q quit",
    "walls": "enter set wallpaper · p preview · d unassign · a assign more · ← back",
    "pick": "enter use this one · d back to the default · f filter · / search · p big preview · q cancel",
    "pool": "1-9,0 toggle theme · s toggle setup · f filter · t in theme… · / search · c clear · "
            "p big preview · enter set · q back",
}


def xterm256(hex_color):
    """Nearest xterm-256 colour index (cube or grey ramp), so no terminal palette gets changed."""
    r, g, b = (int(hex_color[i:i + 2], 16) for i in (1, 3, 5))
    steps = [0, 95, 135, 175, 215, 255]
    near = lambda v: min(range(6), key=lambda i: abs(steps[i] - v))  # noqa: E731
    ci = [near(v) for v in (r, g, b)]
    cube = tuple(steps[i] for i in ci)
    grey_i = max(0, min(23, round((sum((r, g, b)) / 3 - 8) / 10)))
    grey = 8 + grey_i * 10
    d = lambda c: sum((x - y) ** 2 for x, y in zip(c, (r, g, b)))  # noqa: E731
    if d((grey,) * 3) < d(cube):
        return 232 + grey_i
    return 16 + 36 * ci[0] + 6 * ci[1] + ci[2]


class Preview:
    """Draws a PNG into a rectangle of cells with kitty's graphics protocol (no-op elsewhere)."""
    ID = 4242

    def __init__(self):
        self.ok = bool(os.environ.get("KITTY_WINDOW_ID")) or os.environ.get("TERM", "") == "xterm-kitty"
        self.shown = {}   # slot -> what's drawn there

    def _out(self, data):
        os.write(sys.stdout.fileno(), data.encode())

    def clear(self, slot=None):
        for s in ([slot] if slot is not None else list(self.shown)):
            if self.ok and s in self.shown:
                self._out(f"\x1b_Ga=d,d=I,i={self.ID + s},q=2\x1b\\")
            self.shown.pop(s, None)

    def cell_ratio(self):
        """Cell height / width in pixels (from the tty), 2.1 if the terminal won't say."""
        try:
            rows, cols, xp, yp = struct.unpack("HHHH", fcntl.ioctl(sys.stdout.fileno(), termios.TIOCGWINSZ,
                                                                  b"\0" * 8))
            if xp and yp:
                return (yp / rows) / (xp / cols)
        except OSError:
            pass
        return 2.1

    def show(self, png, y, x, rows, cols, slot=0):
        if not self.ok or rows < 2 or cols < 4:
            return
        if self.shown.get(slot) == (png, y, x, rows, cols):
            return
        self.clear(slot)
        try:
            with open(png, "rb") as f:
                head = f.read(24)
            w, h = struct.unpack(">II", head[16:24])
        except (OSError, struct.error):
            return
        ratio = self.cell_ratio()
        c = cols
        r = max(1, round(c * h / w / ratio))
        if r > rows:
            r = rows
            c = max(1, round(r * w / h * ratio))
        path = base64.b64encode(os.path.abspath(png).encode()).decode()
        self._out(f"\x1b7\x1b[{y + 1};{x + (cols - c) // 2 + 1}H"
                  f"\x1b_Ga=T,f=100,t=f,q=2,C=1,i={self.ID + slot},c={c},r={r};{path}\x1b\\\x1b8")
        self.shown[slot] = (png, y, x, rows, cols)


class App:
    def __init__(self, scr, th, start_in_pool):
        self.scr, self.th = scr, th
        self.pane = "themes"
        self.ti = self.wi = 0
        self.status = ""
        self.pairs = {}
        self.preview = Preview()
        self.thumb_for = {}      # item key -> png path (or None when it can't be made)
        self.logos = {}          # (theme, image, inode, mtime) -> what fastfetch shows
        curses.curs_set(0)
        curses.use_default_colors()
        self.load()
        if self.active in self.ids:
            self.ti = self.ids.index(self.active)
        self.start_in_pool = start_in_pool
        # Exact 24-bit swatches (curses only knows 256 colours; these are written after each refresh)
        self.truecolor = os.environ.get("COLORTERM", "") in ("truecolor", "24bit") or self.preview.ok
        self.overlays = []
        # pool screen state
        self.pi = self.ptop = 0
        self.filter = "all"
        self.in_theme = None
        self.search = ""
        self.picking = None   # "walker image for Nord" etc. while choosing a theme image

    # ------------------------------------------------------------ data

    def load(self):
        th = self.th
        self.ids = th.theme_ids()
        self.themes = {tid: th.load_theme(tid) for tid in self.ids}
        self.palette = {tid: th.writers.complete(t)[0] for tid, t in self.themes.items()}
        self.entries = self.ids + [ALL, POOL]
        self.setup = th.load_setup(th.SETUP)
        self.live = th.SETUP == th.active_setup()    # managing the setup that's on screen
        self.active = th.current()
        self.items = th.pool_items()
        self.members = th.memberships(self.ids)

    def name(self, tid):
        return NAMES.get(tid) or self.themes[tid]["name"]

    def sel(self):
        return self.entries[min(self.ti, len(self.entries) - 1)]

    def assigned(self, tid):
        """[(item, own)] for a theme (the pool lists everything)."""
        if tid == POOL:
            return [(it, True) for it in self.items]
        return [(it, True) for it in self.items if tid in self.members.get(it["key"], ())]

    def count(self, tid):
        if tid == POOL:
            return len(self.items)
        return sum(1 for m in self.members.values() if tid in m)

    def toggle(self, tid, item):
        on = tid not in self.members.get(item["key"], set())
        self.th.assign(tid, item, on)
        m = self.members.setdefault(item["key"], set())
        (m.add if on else m.discard)(tid)
        if self.live:
            self.th.sync(self.active)   # a theme with none of its own shows the whole setup
        verb = "added to" if on else "removed from"
        self.status = f"{item['name'][:50]} {verb} {self.name(tid)}"

    # ------------------------------------------------------------ drawing helpers

    def colour_cell(self, y, x, text, fg_hex, bg_hex, bold=False):
        """Text in exact colours: 256-colour approximation via curses, then true colour on top."""
        self.put(y, x, text, self._pair(fg_hex, bg_hex) | (curses.A_BOLD if bold else 0))
        h, w = self.scr.getmaxyx()
        if self.truecolor and 0 <= y < h - 1 and x + len(text) <= w:
            self.overlays.append((y, x, text, fg_hex, bg_hex, bold))

    def block(self, y, x, hex_color, width=2):
        self.colour_cell(y, x, " " * width, hex_color, hex_color)

    def swatch(self, y, x, tid, text):
        """A theme in a cell: its accent on its own background (white-on-black for Onyx, etc.)."""
        p = self.palette[tid]
        self.colour_cell(y, x, text, p["accent"], p["bg"], bold=True)

    def refresh(self):
        self.scr.refresh()
        if not self.overlays:
            return
        rgb = lambda c: ";".join(str(int(c[i:i + 2], 16)) for i in (1, 3, 5))  # noqa: E731
        out = "\x1b7"
        for y, x, text, fg_hex, bg_hex, bold in self.overlays:
            out += (f"\x1b[{y + 1};{x + 1}H\x1b[{'1;' if bold else ''}38;2;{rgb(fg_hex)};48;2;{rgb(bg_hex)}m"
                    f"{text}\x1b[0m")
        os.write(sys.stdout.fileno(), (out + "\x1b8").encode())

    def _pair(self, fg_hex, bg_hex):
        if curses.COLORS < 256:
            return curses.A_REVERSE
        key = (xterm256(fg_hex), xterm256(bg_hex))
        if key not in self.pairs:
            n = len(self.pairs) + 1
            if n >= curses.COLOR_PAIRS:
                return curses.A_REVERSE
            curses.init_pair(n, *key)
            self.pairs[key] = n
        return curses.color_pair(self.pairs[key])

    def put(self, y, x, text, attr=0, width=None):
        h, w = self.scr.getmaxyx()
        if 0 <= y < h and 0 <= x < w:
            width = min(width if width is not None else w - x, w - x - (1 if y == h - 1 else 0))
            if width > 0:
                self.scr.addnstr(y, x, text, width, attr)

    def footer(self):
        h, w = self.scr.getmaxyx()
        self.scr.hline(h - 2, 0, curses.ACS_HLINE, w)
        msg = self.status or HELP[self.pane]
        self.put(h - 1, 1, msg, curses.A_BOLD if self.status else curses.A_DIM)

    def thumb(self, item):
        key = item["key"]
        if key not in self.thumb_for:
            self.thumb_for[key] = self.th.thumbnail(item)
        return self.thumb_for[key]

    def draw_preview(self, item, y, x, rows, cols, lazy, slot=0):
        """Preview image; lazy=True only draws it if the thumbnail was already made this session."""
        if item["key"] not in self.thumb_for and lazy:
            self.preview.clear(slot)
            self.put(y + rows // 2, x + max(0, cols // 2 - 4), "loading…", curses.A_DIM)
            self.refresh()
            return False
        png = self.thumb(item)
        if png:
            self.preview.show(png, y, x, rows, cols, slot)
        else:
            self.preview.clear(slot)
            self.put(y + rows // 2, x + max(0, cols // 2 - 5), "no preview", curses.A_DIM)
            self.refresh()
        return True

    # ------------------------------------------------------------ main screen

    def draw_main(self, lazy=True):
        s = self.scr
        s.erase()
        self.overlays = []
        h, w = s.getmaxyx()
        left = 44 if w >= 90 else w * 2 // 5   # 44 fits names, counts and colour swatches
        tid = self.sel()

        self.put(0, 1, f"{self.setup['name'].upper()} · THEMES" + ("" if self.live else "  (not active)"),
                 curses.A_BOLD, left - 2)
        for i, e in enumerate(self.entries):
            y = 2 + i + (1 if e in (ALL, POOL) else 0)
            if y >= h - 2:
                break
            mark = "●" if e == self.active and self.live else " "
            text = f"{mark} {self.name(e):<22}{self.count(e):>5}"
            attr = curses.A_REVERSE if i == self.ti and self.pane == "themes" else (
                curses.A_BOLD if i == self.ti else 0)
            self.put(y, 1, text, attr, left - 2)
            if e in self.themes and left >= 42:
                p = self.th.writers.complete(self.themes[e])[0]
                for j, k in enumerate(("bg", "fg", "accent", "purple")):
                    self.block(y, 32 + j * 2, p[k])
        for y in range(0, h - 2):
            s.addch(y, left, curses.ACS_VLINE)

        rows = self.assigned(tid)
        self.wi = max(0, min(self.wi, len(rows) - 1))
        x = left + 2
        list_w = w - x - 1
        show_prev = self.preview.ok and w - left > 50
        if show_prev:
            list_w = (w - x) // 2
        own = sum(1 for _, o in rows if o)
        head = f"{self.name(tid).upper()} · {own}" + (" wallpapers" if tid == POOL else " assigned")
        if tid in self.themes and not own:
            head += " · shows the whole setup"
        if tid == self.active and self.live:
            head += "  (active)"
        self.put(0, x, head, curses.A_BOLD, list_w)
        cur = self.th.current_wallpaper_rel() if tid == self.active and self.live else None
        top = max(0, self.wi - (h - 6))
        for i, (it, o) in enumerate(rows[top:top + h - 5]):
            i += top
            text = ("◆ " if cur and os.path.basename(cur) == it["key"] else "  ") + it["name"]
            attr = curses.A_REVERSE if i == self.wi and self.pane == "walls" else (0 if o else curses.A_DIM)
            self.put(2 + i - top, x, text, attr, list_w)
        if not rows:
            self.put(2, x, "nothing assigned yet — press a to pick from the pool", curses.A_DIM, list_w)
        self.footer()
        self.refresh()
        if show_prev and self.pane == "walls" and rows:
            self.preview.clear(1)
            return self.draw_preview(rows[self.wi][0], 2, x + list_w + 1, h - 5, w - x - list_w - 2, lazy)
        if show_prev and self.pane == "themes" and tid in self.themes:
            return self.draw_theme_images(tid, x + list_w + 1, w - x - list_w - 2, h, lazy)
        self.preview.clear()
        return True

    def draw_theme_images(self, tid, x, width, h, lazy):
        """The theme's Walker + fastfetch pictures, one above the other."""
        half = (h - 4) // 2
        done = True
        for slot, kind in enumerate(self.th.writers.IMAGE_KINDS):
            y = 1 + slot * half
            path, default = self.th.writers.theme_image(tid, kind)
            key = "W" if kind == "walker" else "F"
            if path and kind == "fastfetch":
                shown = self.fastfetch_logo(tid, path, lazy)
                if shown is None:          # crop not made yet: wait for the cursor to settle
                    done = False
                    self.preview.clear(slot)
                    continue
                cropped = shown != path
                path = shown
            else:
                cropped = False
            label = (f"{kind.capitalize()} image" + (" (default)" if default else "")
                     + (" · cropped to fit" if cropped else "") + f" · {key.lower()} to change")
            self.put(y, x, label, curses.A_BOLD if not default else curses.A_DIM, width)
            if path:
                done &= self.draw_preview({"key": "img:" + path, "preview": path}, y + 1, x, half - 2, width,
                                          lazy, slot)
            else:
                self.preview.clear(slot)
        return done

    def fastfetch_logo(self, tid, path, lazy):
        """What fastfetch will really show (the centre crop for wide pictures); None while lazy."""
        st = os.stat(path)
        key = (tid, path, st.st_ino, st.st_mtime)
        if key not in self.logos:
            if lazy:
                return None
            settings = self.th.load_settings()
            self.logos[key] = self.th.writers.fastfetch_logo(tid, settings.get("fastfetch", {}),
                                                             self.th.cell_ratio(settings)) or path
        return self.logos[key]

    # ------------------------------------------------------------ pool screen

    def visible(self):
        out = []
        q = self.search.lower()
        for it in self.items:
            m = self.members.get(it["key"], set())
            f = self.filter
            if f == "unassigned" and m or f == "assigned" and not m:
                continue
            if self.in_theme and self.in_theme not in m:
                continue
            if q and q not in it["name"].lower() and q not in it["key"].lower():
                continue
            out.append(it)
        return out

    def draw_pool(self, lazy=True):
        s = self.scr
        s.erase()
        self.overlays = []
        h, w = s.getmaxyx()
        items = self.visible()
        self.pi = max(0, min(self.pi, len(items) - 1))
        list_w = w if not self.preview.ok else max(40, min(w - 30, w * 11 // 20))
        nth = self.ids[:len(KEYS)]

        flt = self.filter + (f" · in {self.name(self.in_theme)}" if self.in_theme else "")
        flt += f" · search “{self.search}”" if self.search else ""
        title = f"PICK THE {self.picking.upper()}" if self.picking else "POOL"
        self.put(0, 1, f"{title} · {len(items)} of {len(self.items)} · {flt}", curses.A_BOLD)
        # legend: number key -> theme, in its accent colour (* = active)
        x = 1
        for key, tid in zip(KEYS, nth):
            label = f"{key} {self.themes[tid]['name']}" + ("*" if tid == self.active else "")
            self.swatch(1, x, tid, f" {key} ")
            self.put(1, x + 4, label[2:])
            x += len(label) + 5

        self.put(1, x, " s " + self.setup["name"], curses.A_BOLD)

        rows = h - 5
        self.ptop = min(max(self.ptop, self.pi - rows + 1), self.pi)
        marks_w = len(nth) + 2
        for j, it in enumerate(items[self.ptop:self.ptop + rows]):
            j += self.ptop
            y = 3 + j - self.ptop
            m = self.members.get(it["key"], set())
            for k, tid in enumerate(nth):
                if tid in m:
                    self.swatch(y, 1 + k, tid, KEYS[k])
                else:
                    self.put(y, 1 + k, "·", curses.A_DIM)
            self.put(y, 1 + len(nth), "s" if ALL in m else "·", curses.A_BOLD if ALL in m else curses.A_DIM)
            self.put(y, 1 + marks_w, f" {it['name']}".ljust(list_w - marks_w - 2),
                     curses.A_REVERSE if j == self.pi else 0, list_w - marks_w - 2)
        if not items:
            self.put(3, 2, "nothing matches — f to change the filter, c to clear", curses.A_DIM)

        if not items:
            self.footer()
            self.refresh()
            self.preview.clear()
            return True
        it = items[self.pi]
        m = self.members.get(it["key"], set())
        px, pw = list_w + 1, w - list_w - 2
        ph = max(4, min(h - 10, pw // 3)) if self.preview.ok else 0
        info_y = 3 + ph + 1
        if pw > 10:
            self.put(info_y, px, it["name"], curses.A_BOLD, pw)
            where = ", ".join(self.name(t) for t in self.ids + [ALL] if t in m) or "not in " + self.setup["name"]
            self.put(info_y + 1, px, "in: " + where, 0, pw)
        self.footer()
        self.refresh()
        if not self.preview.ok:
            return True
        return self.draw_preview(it, 3, px, ph, pw, lazy)

    def pool_loop(self, picking=None):
        """Browse/assign; with picking set, Enter returns the highlighted item instead."""
        back, self.pane, self.picking = self.pane, "pick" if picking else "pool", picking
        chosen = None
        while True:
            done = self.draw_pool(lazy=True)
            self.status = ""
            self.scr.timeout(-1 if done else 150)
            k = self.scr.getch()
            if k == -1:
                self.draw_pool(lazy=False)  # cursor settled: make the thumbnail now
                self.scr.timeout(-1)
                k = self.scr.getch()
            items = self.visible()
            h, _ = self.scr.getmaxyx()
            if k in (ord("q"), 27):
                break
            elif k in (curses.KEY_UP, ord("k")):
                self.pi -= 1
            elif k in (curses.KEY_DOWN, ord("j")):
                self.pi += 1
            elif k == curses.KEY_NPAGE:
                self.pi += h - 6
            elif k == curses.KEY_PPAGE:
                self.pi -= h - 6
            elif k in (curses.KEY_HOME, ord("g")):
                self.pi = 0
            elif k in (curses.KEY_END, ord("G")):
                self.pi = len(items) - 1
            elif self.picking and k in (10, 13, curses.KEY_ENTER) and items:
                chosen = items[self.pi]
                break
            elif self.picking and k == ord("d"):
                chosen = "default"
                break
            elif 0 <= k < 256 and chr(k) in KEYS and items and not self.picking:
                n = KEYS.index(chr(k))
                if n < len(self.ids):
                    self.toggle(self.ids[n], items[self.pi])
            elif k == ord("s") and items and not self.picking:
                self.toggle(ALL, items[self.pi])
            elif k == ord("f"):
                self.filter = FILTERS[(FILTERS.index(self.filter) + 1) % len(FILTERS)]
                self.pi = 0
            elif k == ord("t"):
                self.in_theme = self.choose_theme("Show only wallpapers in", allow_none=True)
                self.pi = 0
            elif k == ord("/"):
                self.search = self.prompt("Search:")
                self.pi = 0
            elif k == ord("c"):
                self.search, self.in_theme, self.filter = "", None, "all"
            elif k == ord("p") and items:
                self.full_preview(items[self.pi])
            elif k in (10, 13, curses.KEY_ENTER) and items:
                self.set_wallpaper(items[self.pi])
        self.preview.clear()
        self.pane, self.picking = back if back != "pool" else "themes", None
        return chosen

    # ------------------------------------------------------------ shared helpers

    def shell_out(self, fn):
        """Leave curses, run fn (an interactive program), come back."""
        self.preview.clear()
        curses.def_prog_mode()
        curses.endwin()
        try:
            fn()
        finally:
            curses.reset_prog_mode()
            self.scr.clear()
            curses.curs_set(0)

    def prompt(self, label):
        self.preview.clear()
        h, w = self.scr.getmaxyx()
        self.scr.move(h - 1, 0)
        self.scr.clrtoeol()
        self.put(h - 1, 1, label, curses.A_BOLD)
        curses.echo()
        curses.curs_set(1)
        try:
            text = self.scr.getstr(h - 1, 2 + len(label), 60).decode().strip()
        except (curses.error, UnicodeDecodeError):
            text = ""
        curses.noecho()
        curses.curs_set(0)
        return text

    def choose_setup(self):
        opts = self.th.setup_ids()
        i = opts.index(self.th.SETUP) if self.th.SETUP in opts else 0
        self.preview.clear()
        while True:
            h, w = self.scr.getmaxyx()
            bw, bh = min(50, w - 4), min(len(opts) + 4, h - 2)
            win = curses.newwin(bh, bw, (h - bh) // 2, (w - bw) // 2)
            win.box()
            win.addnstr(0, 2, " Manage setup ", bw - 4, curses.A_BOLD)
            for j, sid in enumerate(opts[:bh - 4]):
                s = self.th.load_setup(sid)
                label = ("● " if sid == self.th.active_setup() else "  ") + s["name"] + "  " + s.get("description", "")
                win.addnstr(2 + j, 2, label, bw - 4, curses.A_REVERSE if j == i else 0)
            win.refresh()
            k = self.scr.getch()
            if k in (curses.KEY_UP, ord("k")):
                i = max(0, i - 1)
            elif k in (curses.KEY_DOWN, ord("j")):
                i = min(len(opts) - 1, i + 1)
            elif k in (10, 13, curses.KEY_ENTER):
                self.th.use(opts[i])
                self.load()
                self.ti, self.wi, self.pane = (self.ids.index(self.active) if self.active in self.ids else 0), 0, "themes"
                self.status = f"Managing {self.setup['name']}" + ("" if self.live else " · enter on a theme switches to it")
                return
            elif k in (27, ord("q")):
                return

    def choose_theme(self, title, allow_none=False):
        opts = self.ids + ([None] if allow_none else [])
        i = 0
        self.preview.clear()
        while True:
            h, w = self.scr.getmaxyx()
            bw, bh = min(40, w - 4), min(len(opts) + 4, h - 2)
            win = curses.newwin(bh, bw, (h - bh) // 2, (w - bw) // 2)
            win.box()
            win.addnstr(0, 2, f" {title} ", bw - 4, curses.A_BOLD)
            for j, e in enumerate(opts[:bh - 4]):
                label = "(any theme)" if e is None else self.name(e)
                win.addnstr(2 + j, 2, label, bw - 4, curses.A_REVERSE if j == i else 0)
            win.refresh()
            k = self.scr.getch()
            if k in (curses.KEY_UP, ord("k")):
                i = max(0, i - 1)
            elif k in (curses.KEY_DOWN, ord("j")):
                i = min(len(opts) - 1, i + 1)
            elif k in (10, 13, curses.KEY_ENTER):
                return opts[i]
            elif k in (27, ord("q")):
                return None

    def full_preview(self, item):
        path = item["preview"]
        if not path:
            self.status = "No preview for that one"
            return
        if self.preview.ok and shutil.which("kitten"):
            h, w = self.scr.getmaxyx()
            self.shell_out(lambda: subprocess.run(
                ["bash", "-c", 'kitten icat --clear --stdin=no --scale-up --place "$1" "$2"; '
                               'read -rsn1; kitten icat --clear --stdin=no', "_", f"{w}x{h - 1}@0x0", path]))
        else:
            subprocess.Popen(["xdg-open", path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                             start_new_session=True)

    def set_wallpaper(self, item):
        view = [p for p in self.th.walk_files(self.th.VIEW).values() if self.th.same_file(p, item["path"])]
        if not self.live or not view:
            self.status = f"Not in {self.name(self.active)} (the active theme) — assign it there first"
            return
        ok = self.th.apply_wallpaper(view[0])
        self.status = f"Wallpaper: {item['name']}" if ok else "skwd-helm apply failed"

    # ------------------------------------------------------------ main-screen actions

    def apply_theme(self):
        tid = self.sel()
        if tid in (POOL, ALL):
            self.open_pool()
            return
        self.status = f"Applying {self.name(tid)}…"
        self.draw_main()
        if self.live:
            pooled = self.th.cmd_set(tid, quiet=True)
        else:   # switching setup too: come up on the chosen theme
            state = self.th.load_state()
            self.th.setup_state(state)["current"] = tid
            self.th.save_state(state)
            pooled = self.th.cmd_setup(self.th.SETUP, quiet=True)
        self.load()
        self.status = f"{self.name(tid)} applied" + (f" · {pooled} new wallpapers moved to the pool" if pooled else "")

    def edit_theme(self):
        tid = self.sel()
        if tid not in self.themes:
            return
        path = f"{self.th.THEMES}/{tid}.toml"
        self.shell_out(lambda: subprocess.run([os.environ.get("EDITOR", "nvim"), path]))
        try:
            self.load()
        except Exception as e:  # noqa: BLE001 - a typo in the file shouldn't kill the TUI
            self.status = f"{tid}.toml: {e}"
            return
        if tid == self.active and self.live:
            self.status = "Re-applying…"
            self.draw_main()
            self.th.cmd_reload()
            self.status = "Theme re-applied"

    def new_theme(self):
        name = self.prompt("New theme name:")
        if not name:
            return
        tid = re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-") or "theme"
        path = f"{self.th.THEMES}/{tid}.toml"
        if os.path.exists(path):
            self.status = f"{tid} already exists"
            return
        base = self.sel() if self.sel() in self.themes else self.active
        with open(f"{self.th.THEMES}/{base}.toml") as f:
            text = f.read()
        text = re.sub(r'(?m)^name\s*=.*$', f'name = "{name}"', text, count=1)
        text = re.sub(r'(?m)^native_nvim\s*=.*\n', "", text)
        text = re.sub(r'(?m)^wallpaper\s*=.*\n', "", text)
        with open(path, "w") as f:
            f.write(text)
        self.load()
        self.ti = self.entries.index(tid)
        self.edit_theme()
        self.status = f"Created {self.name(tid)} (copied from {self.name(base)}) · press a to give it wallpapers"

    def pick_image(self, tid, kind):
        self.filter, self.in_theme, self.pi = "all", None, 0
        chosen = self.pool_loop(picking=f"{kind} image for {self.name(tid)}")
        if chosen is None:
            return
        src = None if chosen == "default" else chosen["preview"]
        self.status = f"Setting {kind} image…"
        self.draw_main()
        self.th.set_image(tid, kind, src)
        self.thumb_for = {k: v for k, v in self.thumb_for.items() if not k.startswith("img:")}
        what = "the default" if src is None else os.path.basename(src)
        self.status = f"{self.name(tid)} {kind} image: {what}" + (" (applied)" if tid == self.active else "")

    def open_pool(self):
        self.filter, self.in_theme, self.pi = "all", None, 0
        self.pool_loop()

    def loop(self):
        if self.start_in_pool:
            self.pool_loop()
            return
        while True:
            done = self.draw_main(lazy=True)
            self.status = ""
            self.scr.timeout(-1 if done else 150)
            k = self.scr.getch()
            if k == -1:
                self.draw_main(lazy=False)
                self.scr.timeout(-1)
                k = self.scr.getch()
            rows = self.assigned(self.sel())
            if k in (ord("q"), 27):
                if self.pane == "walls":
                    self.pane = "themes"
                    continue
                self.preview.clear()
                return
            if k == ord("a"):
                self.open_pool()
                continue
            if k == ord("S"):
                self.choose_setup()
                continue
            if k in (ord("W"), ord("w"), ord("F"), ord("f")):
                if self.sel() in self.themes:
                    self.pick_image(self.sel(), "walker" if k in (ord("W"), ord("w")) else "fastfetch")
                else:
                    self.status = "Highlight a theme first, then w (Walker) or f (fastfetch)"
                continue
            if self.pane == "themes":
                if k in (curses.KEY_UP, ord("k")):
                    self.ti = max(0, self.ti - 1)
                    self.wi = 0
                elif k in (curses.KEY_DOWN, ord("j")):
                    self.ti = min(len(self.entries) - 1, self.ti + 1)
                    self.wi = 0
                elif k in (9, curses.KEY_RIGHT, ord("l")):
                    self.pane = "walls"
                elif k in (10, 13, curses.KEY_ENTER):
                    self.apply_theme()
                elif k == ord("e"):
                    self.edit_theme()
                elif k == ord("n"):
                    self.new_theme()
            else:
                if k in (curses.KEY_UP, ord("k")):
                    self.wi = max(0, self.wi - 1)
                elif k in (curses.KEY_DOWN, ord("j")):
                    self.wi = min(len(rows) - 1, self.wi + 1)
                elif k in (9, curses.KEY_LEFT, ord("h")):
                    self.pane = "themes"
                elif k in (10, 13, curses.KEY_ENTER) and rows:
                    self.set_wallpaper(rows[self.wi][0])
                elif k == ord("p") and rows:
                    self.full_preview(rows[self.wi][0])
                elif k == ord("d") and rows and self.sel() != POOL and (self.sel() == ALL or self.count(self.sel())):
                    self.toggle(self.sel(), rows[self.wi][0])


def run(th, start_in_pool=False):
    os.environ.setdefault("ESCDELAY", "25")
    curses.wrapper(lambda scr: App(scr, th, start_in_pool).loop())
