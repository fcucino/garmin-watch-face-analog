#!/usr/bin/env python3
"""Generate the BMFont bitmap fonts used by the watch face.

Outputs (in resources/fonts/):
  numerals.fnt / numerals.png         - dial numerals 0-9 (filled)
  numerals_aod.fnt / numerals_aod.png - dial numerals 0-9 (outline, always-on mode)
  small.fnt / small.png               - small text for slot values (ASCII + degree sign)
  icons.fnt / icons.png               - monochrome data icons, one glyph per letter

Glyphs are white on black in a grayscale PNG, which the Connect IQ resource
compiler turns into an anti-aliased font that can be tinted with setColor().

Usage: python3 tools/make_fonts.py [path/to/numerals.ttf]
Default TTF is OpenSans-Regular from the Connect IQ SDK samples (Apache-2.0).
"""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "resources", "fonts")

NUMERAL_SIZE = 38  # px, font size of the dial numerals
NUMERAL_GAP = 2  # px between digits of "10", "11", "12"
SMALL_SIZE = 23  # px, font size of the slot text
ICON_SIZE = 26  # px, icon cell
SUPERSAMPLE = 8


def default_ttf():
    cfg = os.path.expanduser("~/.Garmin/ConnectIQ/current-sdk.cfg")
    with open(cfg) as f:
        sdk = f.read().strip()
    return os.path.join(sdk, "samples", "Analog", "resources", "resource", "OpenSans-Regular.ttf")


def write_bmfont(name, glyphs, line_height, base):
    """glyphs: list of (char, L image, xoffset, yoffset, xadvance)."""
    pad = 2
    atlas_w = 256
    x = y = pad
    row_h = 0
    places = []
    for ch, img, xo, yo, adv in glyphs:
        w, h = img.size
        if x + w + pad > atlas_w:
            x = pad
            y += row_h + pad
            row_h = 0
        places.append((ch, img, x, y, xo, yo, adv))
        x += w + pad
        row_h = max(row_h, h)
    atlas_h = 1
    while atlas_h < y + row_h + pad:
        atlas_h *= 2
    atlas = Image.new("L", (atlas_w, atlas_h), 0)
    lines = [
        f'info face="{name}" size=-{line_height} bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing=1,1 outline=0',
        f"common lineHeight={line_height} base={base} scaleW={atlas_w} scaleH={atlas_h} pages=1 packed=0 alphaChnl=1 redChnl=0 greenChnl=0 blueChnl=0",
        f'page id=0 file="{name}.png"',
        f"chars count={len(places)}",
    ]
    for ch, img, px, py, xo, yo, adv in places:
        atlas.paste(img, (px, py))
        w, h = img.size
        lines.append(
            f"char id={ord(ch)} x={px} y={py} width={w} height={h} xoffset={xo} yoffset={yo} xadvance={adv} page=0 chnl=15"
        )
    atlas.save(os.path.join(OUT, f"{name}.png"))
    with open(os.path.join(OUT, f"{name}.fnt"), "w") as f:
        f.write("\n".join(lines) + "\n")


def numeral_glyphs(ttf, outline):
    """Render digits on a roomy canvas and crop to the real ink, so outline
    strokes are never clipped; lineHeight covers the tallest/deepest glyph."""
    font = ImageFont.truetype(ttf, NUMERAL_SIZE)
    stroke = 2 if outline else 0
    pad = NUMERAL_SIZE
    origin = (pad, pad + NUMERAL_SIZE)  # baseline position on the canvas
    rendered = []
    for ch in "0123456789":
        img = Image.new("L", (NUMERAL_SIZE * 3, NUMERAL_SIZE * 3), 0)
        d = ImageDraw.Draw(img)
        if outline:
            d.text(origin, ch, font=font, anchor="ls", fill=255, stroke_width=stroke, stroke_fill=255)
            d.text(origin, ch, font=font, anchor="ls", fill=0)
        else:
            d.text(origin, ch, font=font, anchor="ls", fill=255)
        x0, y0, x1, y1 = img.getbbox()
        rendered.append((ch, img.crop((x0, y0, x1, y1)), x0 - origin[0], y0 - origin[1], y1 - origin[1]))
    ascent = max(-top for _, _, _, top, _ in rendered)
    descent = max(max(bottom for _, _, _, _, bottom in rendered), 0)
    glyphs = []
    # Advance = ink width + fixed gap, no side bearings: centered text then
    # centers the visible ink, identically for the filled and outline fonts.
    for ch, img, _, top, _ in rendered:
        glyphs.append((ch, img, 0, ascent + top, img.size[0] + NUMERAL_GAP))
    return glyphs, ascent + descent, ascent


def text_glyphs(ttf, chars):
    font = ImageFont.truetype(ttf, SMALL_SIZE)
    ascent, descent = font.getmetrics()
    glyphs = []
    for ch in chars:
        x0, y0, x1, y1 = font.getbbox(ch, anchor="ls")
        w, h = max(x1 - x0, 1), max(y1 - y0, 1)
        img = Image.new("L", (w, h), 0)
        ImageDraw.Draw(img).text((-x0, -y0), ch, font=font, anchor="ls", fill=255)
        glyphs.append((ch, img, x0, ascent + y0, round(font.getlength(ch))))
    return glyphs, ascent + descent, ascent


# --- icons: drawn on a 26x26 grid (units), supersampled -------------------

def icon_canvas():
    n = ICON_SIZE * SUPERSAMPLE
    img = Image.new("L", (n, n), 0)
    return img, ImageDraw.Draw(img)


def S(v):
    return round(v * SUPERSAMPLE)


def P(points):
    return [(S(x), S(y)) for x, y in points]


def icon_calendar(d):
    d.rounded_rectangle(P([(3, 5), (23, 23)]), radius=S(3), outline=255, width=S(2))
    d.rectangle(P([(3, 5), (23, 10)]), fill=255)
    d.rectangle(P([(7, 2), (9, 7)]), fill=255)
    d.rectangle(P([(17, 2), (19, 7)]), fill=255)
    for cx, cy in [(8, 14), (13, 14), (18, 14), (8, 19), (13, 19)]:
        d.rectangle(P([(cx - 1.3, cy - 1.3), (cx + 1.3, cy + 1.3)]), fill=255)


def icon_battery(d):
    d.rounded_rectangle(P([(2, 8), (22, 19)]), radius=S(2), outline=255, width=S(2))
    d.rectangle(P([(22, 11), (25, 16)]), fill=255)
    d.rectangle(P([(5, 11), (15, 16)]), fill=255)


def icon_steps(d):
    # two footprints
    d.ellipse(P([(4, 3), (11, 14)]), fill=255)
    d.ellipse(P([(5, 15), (10, 19)]), fill=255)
    d.ellipse(P([(15, 7), (22, 18)]), fill=255)
    d.ellipse(P([(16, 19), (21, 23)]), fill=255)


def icon_heart(d):
    d.ellipse(P([(3, 5), (14, 15)]), fill=255)
    d.ellipse(P([(12, 5), (23, 15)]), fill=255)
    d.polygon(P([(3.6, 12), (13, 23), (22.4, 12)]), fill=255)


def icon_flame(d):
    d.polygon(P([(13, 2), (20, 12), (21, 17), (13, 24), (5, 17), (6, 11), (9, 14)]), fill=255)
    d.ellipse(P([(5, 11), (21, 24)]), fill=255)
    d.polygon(P([(13, 13), (16, 18), (13, 21), (10, 18)]), fill=0)


def icon_body_battery(d):
    # person silhouette with energy bolt
    d.ellipse(P([(9, 1), (15, 7)]), fill=255)
    d.rounded_rectangle(P([(6, 8), (18, 25)]), radius=S(3), outline=255, width=S(2))
    d.polygon(P([(13, 10), (8.5, 17.5), (12, 17.5), (11, 23), (15.5, 15.5), (12, 15.5)]), fill=255)


def icon_stress(d):
    pts = [(2, 14), (6, 14), (8, 6), (11, 21), (14, 9), (17, 17), (19, 14), (24, 14)]
    d.line(P(pts), fill=255, width=S(2), joint="curve")


def icon_bell(d):
    d.pieslice(P([(5, 3), (21, 19)]), 180, 360, fill=255)
    d.rectangle(P([(5, 11), (21, 18)]), fill=255)
    d.polygon(P([(3, 20), (5, 17), (21, 17), (23, 20)]), fill=255)
    d.ellipse(P([(10, 20), (16, 25)]), fill=255)
    d.ellipse(P([(11.5, 1), (14.5, 4)]), fill=255)


def icon_stairs(d):
    d.polygon(P([(2, 24), (2, 19), (8, 19), (8, 13), (14, 13), (14, 7), (20, 7), (20, 2), (24, 2), (24, 24)]), fill=255)


def icon_pin(d):
    d.ellipse(P([(5, 2), (21, 18)]), fill=255)
    d.polygon(P([(6, 13), (13, 25), (20, 13)]), fill=255)
    d.ellipse(P([(10, 7), (16, 13)]), fill=0)


def icon_runner(d):
    # running man, mid-stride, leaning forward
    w = S(2.6)
    d.ellipse(P([(14.5, 1), (19.5, 6)]), fill=255)
    d.line(P([(16, 8), (12, 15.5)]), fill=255, width=S(3.2), joint="curve")      # torso
    d.line(P([(15.5, 9), (20, 12), (23, 9.5)]), fill=255, width=w, joint="curve")  # front arm
    d.line(P([(15, 9), (10, 10.5), (7, 14)]), fill=255, width=w, joint="curve")    # back arm
    d.line(P([(12, 15.5), (17, 19), (16, 24.5)]), fill=255, width=w, joint="curve")  # front leg
    d.line(P([(12, 15.5), (9, 20), (3, 21)]), fill=255, width=w, joint="curve")      # back leg


def icon_sun(d):
    d.pieslice(P([(7, 10), (19, 22)]), 180, 360, fill=255)
    d.rectangle(P([(2, 17), (24, 19)]), fill=255)
    for a in (180, 225, 270, 315, 360):
        r = math.radians(a)
        cx, cy = 13, 16
        d.line(P([(cx + 8 * math.cos(r), cy + 8 * math.sin(r)), (cx + 11 * math.cos(r), cy + 11 * math.sin(r))]), fill=255, width=S(2))
    d.polygon(P([(10, 25), (13, 21), (16, 25)]), fill=255)


def icon_thermometer(d):
    d.rounded_rectangle(P([(10, 1), (16, 18)]), radius=S(3), outline=255, width=S(2))
    d.ellipse(P([(7, 15), (19, 25)]), fill=255)
    d.rectangle(P([(12, 8), (14, 17)]), fill=255)
    for y in (5, 9, 13):
        d.line(P([(18, y), (21, y)]), fill=255, width=S(1.5))


def icon_bolt(d):
    d.polygon(P([(15, 1), (5, 15), (12, 15), (10, 25), (21, 10), (14, 10)]), fill=255)


ICONS = [
    ("a", icon_calendar),
    ("b", icon_battery),
    ("c", icon_steps),
    ("d", icon_heart),
    ("e", icon_flame),
    ("f", icon_body_battery),
    ("g", icon_stress),
    ("h", icon_bell),
    ("i", icon_stairs),
    ("j", icon_pin),
    ("k", icon_runner),
    ("l", icon_sun),
    ("m", icon_thermometer),
    ("n", icon_bolt),
]


def icon_glyphs():
    glyphs = []
    for ch, fn in ICONS:
        img, d = icon_canvas()
        fn(d)
        img = img.resize((ICON_SIZE, ICON_SIZE), Image.LANCZOS)
        glyphs.append((ch, img, 0, 0, ICON_SIZE))
    return glyphs


def main():
    ttf = sys.argv[1] if len(sys.argv) > 1 else default_ttf()
    os.makedirs(OUT, exist_ok=True)
    glyphs, line, base = numeral_glyphs(ttf, outline=False)
    write_bmfont("numerals", glyphs, line, base)
    glyphs, line, base = numeral_glyphs(ttf, outline=True)
    write_bmfont("numerals_aod", glyphs, line, base)
    glyphs, line, base = text_glyphs(ttf, [chr(c) for c in range(32, 127)] + ["\u00b0"])
    write_bmfont("small", glyphs, line, base)
    write_bmfont("icons", icon_glyphs(), ICON_SIZE, ICON_SIZE)
    print("fonts written to", OUT)


if __name__ == "__main__":
    main()
