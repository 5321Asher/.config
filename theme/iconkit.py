"""Building blocks for a setup's own icon and cursor themes (used by setups/<setup>/style.py).

    cursor_theme(name, comment, shapes, key)   Xcursor theme in ~/.local/share/icons/<name>
    folder_theme(name, comment, draw, key)     icon theme of Papirus's folders, redrawn by the setup

Both rebuild only when `key` (a hash of the colours they use) changes, and return the theme name.
"""

import hashlib
import os
import re
import struct
import subprocess

ICONS = os.path.expanduser("~/.local/share/icons")
PAPIRUS = "/usr/share/icons/Papirus"
PAPIRUS_DARK = "/usr/share/icons/Papirus-Dark"
CURSOR_SIZES = (24, 32, 48)

# Every standard cursor name -> the shape that draws it. A setup's shapes dict uses these keys:
# arrow pointer text crosshair wait progress move ns ew nwse nesw forbidden help copy link
CURSOR_NAMES = {
    "arrow": ["default", "left_ptr", "arrow", "top_left_arrow", "context-menu", "right_ptr", "center_ptr"],
    "pointer": ["pointer", "hand", "hand1", "hand2", "pointing_hand", "grab", "openhand", "e29285e634086352946a0e7090d73106"],
    "text": ["text", "xterm", "ibeam", "vertical-text"],
    "crosshair": ["crosshair", "cross", "tcross", "cross_reverse", "diamond_cross", "cell", "color-picker", "zoom-in", "zoom-out", "plus"],
    "wait": ["wait", "watch"],
    "progress": ["progress", "left_ptr_watch", "half-busy", "00000000000000020006000e7e9ffc3f", "08e8e1c95fe2fc01f976f1e063a24ccd", "3ecb610c1bf2410f44200f48c40d3599"],
    "move": ["move", "fleur", "all-scroll", "grabbing", "closedhand", "dnd-move", "size_all", "4498f0e0c1937ffe01fd06f973665830", "9081237383d90e509aa00f00170e968f"],
    "ns": ["ns-resize", "n-resize", "s-resize", "row-resize", "sb_v_double_arrow", "v_double_arrow", "top_side", "bottom_side", "size_ver", "split_v", "00008160000006810000408080010102"],
    "ew": ["ew-resize", "e-resize", "w-resize", "col-resize", "sb_h_double_arrow", "h_double_arrow", "left_side", "right_side", "size_hor", "split_h", "028006030e0e7ebffc7f7070c0600140"],
    "nwse": ["nwse-resize", "nw-resize", "se-resize", "top_left_corner", "bottom_right_corner", "bd_double_arrow", "size_fdiag", "c7088f0f3e6c8088236ef8e1e3e70000"],
    "nesw": ["nesw-resize", "ne-resize", "sw-resize", "top_right_corner", "bottom_left_corner", "fd_double_arrow", "size_bdiag", "fcf1c3c7cd4491d801f1e1c78f100000"],
    "forbidden": ["not-allowed", "no-drop", "crossed_circle", "forbidden", "circle", "X_cursor", "pirate", "03b6e0fcb3499374a867c041f52298f0"],
    "help": ["help", "question_arrow", "whats_this", "left_ptr_help", "dnd-ask", "d9ce0ab605698f320427677b458ad60b", "5c6cd98b3f3ebcb1f9c7f1c204630408"],
    "copy": ["copy", "dnd-copy", "1081e37283d90000800003c07f3ef6bf", "6407b0e94181790501fd1e167b474872"],
    "link": ["alias", "dnd-link", "link", "3085a0e285430894940527032f8b26df", "640fb0e74195791501fd1ed57b41487f"],
}


def palette_key(*parts):
    return hashlib.sha1("".join(str(p) for p in parts).encode()).hexdigest()[:12]


def _fresh(root, key):
    try:
        return open(f"{root}/.palette").read().strip() == key
    except OSError:
        return False


def _mark(root, key):
    with open(f"{root}/.palette", "w") as f:
        f.write(key + "\n")


# ---------------------------------------------------------------- cursors

def xcursor(images):
    """Xcursor file bytes. images: [(nominal size, w, h, xhot, yhot, delay ms, ARGB32 premultiplied LE bytes)]."""
    header = struct.pack("<4sIII", b"Xcur", 16, 0x10000, len(images))
    toc, chunks, pos = b"", b"", 16 + 12 * len(images)
    for size, w, h, xh, yh, delay, pixels in images:
        toc += struct.pack("<III", 0xFFFD0002, size, pos)
        chunk = struct.pack("<IIIIIIIII", 36, 0xFFFD0002, size, 1, w, h, xh, yh, delay) + pixels
        chunks += chunk
        pos += len(chunk)
    return header + toc + chunks


def render(svg_text, px):
    """An SVG (drawn on a 64 grid) at px x px: RGBA straight -> ARGB32 premultiplied little-endian."""
    raw = subprocess.run(["magick", "-background", "none", "-density", str(96 * px / 64), "svg:-",
                          "-resize", f"{px}x{px}!", "-depth", "8", "rgba:-"], input=svg_text.encode(),
                         capture_output=True, timeout=30).stdout
    out = bytearray(len(raw))
    for i in range(0, len(raw), 4):
        r, g, b, a = raw[i], raw[i + 1], raw[i + 2], raw[i + 3]
        out[i] = b * a // 255
        out[i + 1] = g * a // 255
        out[i + 2] = r * a // 255
        out[i + 3] = a
    return bytes(out)


def cursor_theme(name, comment, shapes, key, inherits="Adwaita"):
    """shapes: {shape: (svg-maker(frame, frames), (xhot, yhot) on the 64 grid, frames)}."""
    root = f"{ICONS}/{name}"
    if _fresh(root, key):
        return name
    cdir = f"{root}/cursors"
    os.makedirs(cdir, exist_ok=True)
    for shape, (make, (hx, hy), frames) in shapes.items():
        images = []
        for size in CURSOR_SIZES:
            for f in range(frames):
                images.append((size, size, size, round(hx * size / 64), round(hy * size / 64),
                               60 if frames > 1 else 0, render(make(f, frames), size)))
        with open(f"{cdir}/{shape}", "wb") as fh:
            fh.write(xcursor(images))
        for alias in CURSOR_NAMES.get(shape, []):
            if alias == shape:
                continue
            link = f"{cdir}/{alias}"
            if os.path.lexists(link):
                os.unlink(link)
            os.symlink(shape, link)
    with open(f"{root}/index.theme", "w") as fh:
        fh.write(f"[Icon Theme]\nName={name.replace('-', ' ')}\nComment={comment}\nInherits={inherits}\n")
    _mark(root, key)
    return name


# ---------------------------------------------------------------- folder icons

_NUM = re.compile(r"-?\d+(?:\.\d+)?")


def _attrs(tag):
    return dict(re.findall(r'(\w[\w:-]*)="([^"]*)"', tag))


def parse_folder(svg):
    """Papirus's folder anatomy from one of its folder-blue*.svg files:
    {"size", "front": (x, y, w, h), "paper": (x, y, w, h), "tab_top", "glyph": [svg elements]}."""
    size = float(_attrs(re.search(r"<svg[^>]*>", svg).group(0)).get("width", 64))
    out = {"size": size, "glyph": []}
    tab_top = None
    for tag in re.findall(r"<(?:rect|path|circle|ellipse|g)\b[^>]*/>", svg):
        a = _attrs(tag)
        style = a.get("style", "") + ";" + a.get("fill", "")
        if "#5294e2" in style.lower() and tag.startswith("<rect"):
            out["front"] = tuple(float(a[k]) for k in ("x", "y", "width", "height"))
        elif "#e4e4e4" in style.lower() and tag.startswith("<rect"):
            out["paper"] = tuple(float(a[k]) for k in ("x", "y", "width", "height"))
        elif "#4877b1" in style.lower() and tag.startswith("<path"):
            nums = [float(n) for n in _NUM.findall(a.get("d", ""))]
            tab_top = min(nums[1::2]) if len(nums) > 1 else None
        elif "#1d344f" in style.lower():
            out["glyph"].append(tag)
    out["tab_top"] = tab_top
    return out if "front" in out and tab_top is not None else None


def folder_theme(name, comment, draw, key, inherits):
    """Redraw every Papirus place icon that is a blue folder (folder-blue*, user-blue*: home, desktop…).
    draw(anatomy) -> SVG text; anatomy is parse_folder()'s dict plus "svg", the original file."""
    root = f"{ICONS}/{name}"
    if _fresh(root, key):
        return name
    if not os.path.isdir(PAPIRUS):
        return None
    dirs = []
    for size in sorted(os.listdir(PAPIRUS)):
        src = f"{PAPIRUS}/{size}/places"
        if not os.path.isdir(src) or os.path.islink(f"{PAPIRUS}/{size}"):
            continue
        out = f"{root}/{size}/places"
        os.makedirs(out, exist_ok=True)
        names = set(os.listdir(src))
        dark = f"{PAPIRUS_DARK}/{size}/places"
        if os.path.isdir(dark):
            names |= set(os.listdir(dark))
        made = 0
        for icon in names:
            path = f"{dark}/{icon}" if os.path.exists(f"{dark}/{icon}") else f"{src}/{icon}"
            real = os.path.realpath(path)
            base = os.path.basename(real)
            if not base.startswith(("folder-blue", "user-blue")) or not real.endswith(".svg"):
                continue
            with open(real) as f:
                text = f.read()
            anatomy = parse_folder(text)
            if not anatomy:
                continue
            anatomy["svg"] = text           # the original, for setups that only recolour it
            with open(f"{out}/{icon}", "w") as f:
                f.write(draw(anatomy))
            made += 1
        if made:
            dim, _, scale = size.partition("@")
            dirs.append((f"{size}/places", int(dim.split("x")[0]), int(scale[:-1]) if scale else 1))
    with open(f"{root}/index.theme", "w") as f:
        f.write(f"[Icon Theme]\nName={name}\nComment={comment}\nInherits={inherits}\n"
                f"Directories={','.join(d for d, _, _ in dirs)}\n\n")
        for d, size, scale in dirs:
            f.write(f"[{d}]\nContext=Places\nSize={size}\n" + (f"Scale={scale}\n" if scale > 1 else "") + "Type=Fixed\n\n")
    _mark(root, key)
    return name
