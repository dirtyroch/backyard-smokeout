#!/usr/bin/env python3
"""Makes a 512x512 store icon for every Game Pass and Developer Product in
src/shared/Monetization.luau -> marketing/shop-icons/<Key>.png.

Each icon is the item's own shop emoji (Noto Emoji artwork, Apache 2.0 / OFL) on a rounded tile
in its shop-tab color, so the Roblox purchase prompt matches the in-game shop. No text on the tiles (Roblox shows the name and price next to them), except a
small corner badge where two items would otherwise look the same (30 MIN / 2 HRS, +1 / +5, x3). scripts/create-shop.luau uploads these.

  python3 scripts/make-shop-icons.py          # needs Pillow + cairosvg, downloads the emoji SVGs once
"""
import io, os, re, sys, urllib.request
from PIL import Image, ImageDraw, ImageFilter
import cairosvg

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src/shared/Monetization.luau")
OUT = os.path.join(ROOT, "marketing/shop-icons")
CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")), "noto-emoji-svg")
NOTO = "https://raw.githubusercontent.com/googlefonts/noto-emoji/main/2D/svg/emoji_u{}.svg"

# Tile colors (top, bottom) by shop tab; passes get the warm "Passes" tile.
TABS = {
    "Passes": ("#FFB547", "#D9531E"),
    "Boosts": ("#6FD3FF", "#2477D6"),
    "Fits": ("#FF8A65", "#C2362B"),
    "Smokers": ("#8C8C8C", "#3B3B3B"),
    "Smoke": ("#B49CFF", "#5B3FD1"),
    "Trails": ("#7CE0B0", "#1F9468"),
    "Bundles": ("#FFE066", "#E09A10"),
    "This Week": ("#FFB07A", "#C9612A"),
    "Turkey Day": ("#E8A15A", "#8A4A1C"),
    "Holiday": ("#6FD18A", "#B8282E"),
    "Season": ("#7FD7E8", "#2C5E9E"),
}
SIZE = 512
# A short corner badge only where two items would otherwise share the same picture.
BADGES = {"Boost30": "30 MIN", "Boost120": "2 HRS", "TierSkip1": "+1", "TierSkip5": "+5", "WagyuPack": "x3", "TomahawkPack": "x3"}
FONT = "/usr/share/fonts/truetype/sand-box/google/Fredoka/Fredoka-VariableFont_wdth,wght.ttf"


def entries():
    text = open(SRC, encoding="utf-8").read()
    section = None
    for line in text.splitlines():
        if line.startswith("Monetization.Passes"):
            section = "Passes"
        elif line.startswith("Monetization.Products"):
            section = "Products"
        elif line.startswith("Monetization.") or line.startswith("}"):
            section = None if not line.startswith("Monetization.P") else section
        m = re.match(r'\s*(\w+) = \{ id = \d+, name = "([^"]+)".*?icon = "([^"]+)"', line)
        if m and section:
            cat = re.search(r'category = "([^"]+)"', line)
            yield m.group(1), m.group(2), m.group(3), ("Passes" if section == "Passes" else cat.group(1))


def emoji_png(ch, px):
    cps = "_".join(f"{ord(c):04x}" for c in ch if ord(c) != 0xFE0F)
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, cps + ".svg")
    if not os.path.exists(path):
        urllib.request.urlretrieve(NOTO.format(cps), path)
    data = cairosvg.svg2png(url=path, output_width=px, output_height=px, unsafe=True)  # some Noto SVGs declare internal XML entities
    return Image.open(io.BytesIO(data)).convert("RGBA")


def hex2rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i : i + 2], 16) for i in (0, 2, 4))


def tile(top, bottom):
    t, b = hex2rgb(top), hex2rgb(bottom)
    grad = Image.new("RGBA", (SIZE, SIZE))
    d = ImageDraw.Draw(grad)
    for y in range(SIZE):
        k = y / (SIZE - 1)
        d.line([(0, y), (SIZE, y)], fill=tuple(int(t[i] + (b[i] - t[i]) * k) for i in range(3)) + (255,))
    # soft light behind the emoji
    glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([96, 80, 416, 400], fill=(255, 255, 255, 90))
    grad = Image.alpha_composite(grad, glow.filter(ImageFilter.GaussianBlur(40)))
    mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, SIZE - 1, SIZE - 1], radius=96, fill=255)
    out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    out.paste(grad, (0, 0), mask)
    # inner rim
    ImageDraw.Draw(out).rounded_rectangle([10, 10, SIZE - 11, SIZE - 11], radius=86, outline=(255, 255, 255, 110), width=8)
    return out


def badge(img, text):
    from PIL import ImageFont
    try:
        font = ImageFont.truetype(FONT, 64)
        font.set_variation_by_name("Bold")
    except Exception:
        font = ImageFont.load_default(64)
    d = ImageDraw.Draw(img)
    l, t, r, b = d.textbbox((0, 0), text, font=font)
    w, h = r - l + 44, b - t + 26
    x0, y0 = SIZE - w - 26, SIZE - h - 26
    d.rounded_rectangle([x0, y0, x0 + w, y0 + h], radius=h // 2, fill=(255, 255, 255, 245), outline=(40, 30, 25, 255), width=5)
    d.text((x0 + 22 - l, y0 + 13 - t), text, font=font, fill=(40, 30, 25, 255))
    return img


def make(icon, cat, key=""):
    top, bottom = TABS.get(cat, TABS["Passes"])
    base = tile(top, bottom)
    em = emoji_png(icon, 300)
    shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    shadow.paste((0, 0, 0, 120), (106, 120), em.split()[3])
    base = Image.alpha_composite(base, shadow.filter(ImageFilter.GaussianBlur(10)))
    base.alpha_composite(em, (106, 100))
    if key in BADGES:
        base = badge(base, BADGES[key])
    return base


def main():
    os.makedirs(OUT, exist_ok=True)
    n = 0
    for key, name, icon, cat in entries():
        make(icon, cat, key).save(os.path.join(OUT, key + ".png"), optimize=True)
        n += 1
    print(f"{n} icons -> {os.path.relpath(OUT, ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
