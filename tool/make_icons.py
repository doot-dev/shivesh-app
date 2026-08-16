#!/usr/bin/env python3
"""Generate launcher-icon source images from assets/logo/logo.png.

Why this exists: the brand logo is a *lockup* — a colourful lotus mark on top
of a dark-teal "SHIVESH / Group of Companies" wordmark — on a transparent
canvas. That is wrong for launcher icons in two ways:

  * iOS rejects icons with an alpha channel, so it needs an opaque backing.
  * Android adaptive icons are masked to a circle/squircle, so artwork must sit
    inside the inner ~66% safe zone or the mask clips it.

So we composite deterministically here instead of hand-editing a PNG. Pure
stdlib (zlib + struct) so it runs anywhere without Pillow.

Run:  python3 tool/make_icons.py
"""

import struct
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "logo" / "logo.png"
OUT_DIR = ROOT / "assets" / "logo"


# ── PNG I/O ─────────────────────────────────────────────────────────────────
def read_png_rgba(path):
    """Decode an 8-bit RGB/RGBA PNG into (width, height, bytearray RGBA)."""
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"{path} is not a PNG")

    pos, idat, w, h, colortype, bitdepth = 8, b"", 0, 0, 0, 0
    while pos < len(data):
        (length,) = struct.unpack(">I", data[pos : pos + 4])
        ctype = data[pos + 4 : pos + 8]
        chunk = data[pos + 8 : pos + 8 + length]
        if ctype == b"IHDR":
            w, h, bitdepth, colortype = struct.unpack(">IIBB", chunk[:10])
        elif ctype == b"IDAT":
            idat += chunk
        elif ctype == b"IEND":
            break
        pos += 12 + length

    if bitdepth != 8 or colortype not in (2, 6):
        raise ValueError(f"unsupported PNG: bitdepth={bitdepth} colortype={colortype}")

    channels = 4 if colortype == 6 else 3
    raw = zlib.decompress(idat)
    stride = w * channels
    out = bytearray(w * h * 4)
    prev = bytearray(stride)
    i = 0

    for y in range(h):
        ftype = raw[i]
        i += 1
        line = bytearray(raw[i : i + stride])
        i += stride
        # Undo the per-scanline filter (PNG spec 9.2).
        for x in range(stride):
            a = line[x - channels] if x >= channels else 0
            b = prev[x]
            c = prev[x - channels] if x >= channels else 0
            f = line[x]
            if ftype == 1:
                line[x] = (f + a) & 255
            elif ftype == 2:
                line[x] = (f + b) & 255
            elif ftype == 3:
                line[x] = (f + (a + b) // 2) & 255
            elif ftype == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pred = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[x] = (f + pred) & 255
        for x in range(w):
            s, d = x * channels, (y * w + x) * 4
            out[d] = line[s]
            out[d + 1] = line[s + 1]
            out[d + 2] = line[s + 2]
            out[d + 3] = line[s + 3] if channels == 4 else 255
        prev = line

    return w, h, out


def write_png_rgba(path, w, h, px):
    """Encode RGBA bytes as a PNG (filter type 0, zlib level 9)."""
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        raw += px[y * w * 4 : (y + 1) * w * 4]

    def chunk(tag, payload):
        return (
            struct.pack(">I", len(payload))
            + tag
            + payload
            + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF)
        )

    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b"")
    )


# ── Geometry ────────────────────────────────────────────────────────────────
def opaque_bbox(w, h, px, threshold=16):
    """Tight bounds of non-transparent pixels — the logo has wide empty margins,
    so trimming first is what lets us control padding precisely."""
    minx, miny, maxx, maxy = w, h, -1, -1
    for y in range(h):
        row = y * w
        for x in range(w):
            if px[(row + x) * 4 + 3] > threshold:
                if x < minx:
                    minx = x
                if x > maxx:
                    maxx = x
                if y < miny:
                    miny = y
                if y > maxy:
                    maxy = y
    if maxx < 0:
        raise ValueError("image is fully transparent")
    return minx, miny, maxx, maxy


def resize_bilinear(sw, sh, src, dw, dh):
    """Premultiplied bilinear resample. Premultiplying matters: interpolating
    straight RGBA drags the colour of transparent pixels into the edges and
    haloes the artwork."""
    dst = bytearray(dw * dh * 4)
    x_ratio = sw / dw
    y_ratio = sh / dh
    for j in range(dh):
        sy = min(max((j + 0.5) * y_ratio - 0.5, 0), sh - 1)
        y0 = int(sy)
        y1 = min(y0 + 1, sh - 1)
        wy = sy - y0
        for i in range(dw):
            sx = min(max((i + 0.5) * x_ratio - 0.5, 0), sw - 1)
            x0 = int(sx)
            x1 = min(x0 + 1, sw - 1)
            wx = sx - x0
            acc = [0.0, 0.0, 0.0, 0.0]
            for (xx, yy, weight) in (
                (x0, y0, (1 - wx) * (1 - wy)),
                (x1, y0, wx * (1 - wy)),
                (x0, y1, (1 - wx) * wy),
                (x1, y1, wx * wy),
            ):
                o = (yy * sw + xx) * 4
                a = src[o + 3] / 255
                acc[0] += src[o] * a * weight
                acc[1] += src[o + 1] * a * weight
                acc[2] += src[o + 2] * a * weight
                acc[3] += src[o + 3] * weight
            d = (j * dw + i) * 4
            alpha = acc[3] / 255
            if alpha > 0.0001:
                dst[d] = min(255, int(acc[0] / alpha + 0.5))
                dst[d + 1] = min(255, int(acc[1] / alpha + 0.5))
                dst[d + 2] = min(255, int(acc[2] / alpha + 0.5))
            dst[d + 3] = min(255, int(acc[3] + 0.5))
    return dst


def compose(size, art_w, art_h, art, bg=None):
    """Centre `art` on a `size`x`size` canvas over an optional opaque colour."""
    if bg is None:
        canvas = bytearray(size * size * 4)
    else:
        canvas = bytearray()
        for _ in range(size * size):
            canvas += bytes((bg[0], bg[1], bg[2], 255))
    ox = (size - art_w) // 2
    oy = (size - art_h) // 2
    for y in range(art_h):
        for x in range(art_w):
            s = (y * art_w + x) * 4
            a = art[s + 3]
            if a == 0:
                continue
            d = ((y + oy) * size + (x + ox)) * 4
            if a == 255:
                canvas[d : d + 4] = art[s : s + 4]
            else:
                f = a / 255
                for k in range(3):
                    canvas[d + k] = int(art[s + k] * f + canvas[d + k] * (1 - f))
                canvas[d + 3] = max(canvas[d + 3], a)
    return canvas


def build(size, coverage, bg, out_name, crop_bottom=1.0):
    """Trim the logo, scale it to `coverage` of the canvas, centre it.

    coverage < 1 leaves the padding Android's adaptive mask needs.
    """
    w, h, px = read_png_rgba(SRC)
    minx, miny, maxx, maxy = opaque_bbox(w, h, px)
    if crop_bottom < 1.0:
        maxy = miny + int((maxy - miny) * crop_bottom)

    cw, ch = maxx - minx + 1, maxy - miny + 1
    cropped = bytearray(cw * ch * 4)
    for y in range(ch):
        s = ((y + miny) * w + minx) * 4
        cropped[y * cw * 4 : (y + 1) * cw * 4] = px[s : s + cw * 4]

    target = int(size * coverage)
    scale = min(target / cw, target / ch)
    nw, nh = max(1, int(cw * scale)), max(1, int(ch * scale))
    art = resize_bilinear(cw, ch, cropped, nw, nh)

    out = OUT_DIR / out_name
    write_png_rgba(out, size, size, compose(size, nw, nh, art, bg))
    print(f"  {out_name:26s} {size}x{size}  art {nw}x{nh}  bg={bg or 'transparent'}")
    return out


# Fraction of the logo's height occupied by the lotus mark, above the
# "SHIVESH / Group of Companies" wordmark. Measured from the artwork: the
# opaque bbox is y43..y208 and luminance collapses from ~141 to ~64 at y153,
# which is exactly where the dark wordmark starts. (153-43)/(208-43) = 0.66.
MARK_ONLY = 0.66

if __name__ == "__main__":
    if not SRC.exists():
        sys.exit(f"missing source logo: {SRC}")
    print("Generating launcher icon sources from", SRC.name)
    # Launcher icons use the lotus MARK only. The full lockup is unreadable at
    # 48px — the tagline turns to mush — and every platform renders the icon
    # small, so the mark alone is both legible and more recognisable.
    # Opaque, near-full-bleed: iOS + legacy Android launcher icons.
    build(1024, 0.72, (255, 255, 255), "icon_source.png", crop_bottom=MARK_ONLY)
    # Android adaptive foreground. NOTE the coverage looks too big on its own:
    # flutter_launcher_icons wraps this drawable in `<inset android:inset="16%">`,
    # which shrinks it to 68% of the 108dp canvas. 0.84 * 0.68 = 57%, just
    # inside the 61% (66dp/108dp) adaptive safe zone. Dropping this to a
    # "safe-looking" 0.46 renders the mark at a comical 24% — measure the
    # generated drawable, don't eyeball this number.
    build(1024, 0.84, None, "icon_foreground.png", crop_bottom=MARK_ONLY)
    # Full lockup kept for comparison / any future use that renders large.
    build(1024, 0.80, (255, 255, 255), "icon_lockup.png")
    # In-app asset: the lotus mark alone, transparent and tightly cropped.
    # Used on the dark brand header, where the lockup's dark-teal wordmark is
    # nearly invisible — see BrandLogo.
    build(512, 1.0, None, "logo_mark.png", crop_bottom=MARK_ONLY)
    print("Done.")
