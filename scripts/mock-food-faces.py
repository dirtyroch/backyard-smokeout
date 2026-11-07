#!/usr/bin/env python3
"""Offline preview of the burger and steak faces. Not a Roblox Studio capture."""

from PIL import Image, ImageDraw, ImageFont

OUT = "/workspace/marketing/ui-mocks"


def font(size, bold=False):
    path = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
    return ImageFont.truetype(path, size)


def banner(img, text):
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, img.width, 34), fill=(28, 16, 10))
    d.text((12, 8), text, font=font(15, True), fill=(255, 209, 90))


def patty(d, cx, cy, r, color):
    d.ellipse((cx - r, cy - r * 0.72, cx + r, cy + r * 0.72), fill=color, outline=(60, 32, 18), width=3)


def face_happy(d, cx, cy, s, wink=False):
    # eyes
    for side, squint in ((-1, False), (1, wink)):
        ex, ey = cx + side * s * 0.38, cy - s * 0.08
        if squint:
            d.arc((ex - s * 0.22, ey - s * 0.08, ex + s * 0.22, ey + s * 0.16), 200, 340, fill=(255, 248, 240), width=6)
        else:
            d.ellipse((ex - s * 0.22, ey - s * 0.2, ex + s * 0.22, ey + s * 0.2), fill=(255, 248, 240))
            d.ellipse((ex - s * 0.09, ey - s * 0.06, ex + s * 0.08, ey + s * 0.12), fill=(42, 20, 12))
            d.ellipse((ex - s * 0.12, ey - s * 0.12, ex - s * 0.04, ey - s * 0.04), fill=(255, 255, 255))
    # cheeks
    for side in (-1, 1):
        d.ellipse((cx + side * s * 0.62 - s * 0.12, cy + s * 0.08, cx + side * s * 0.62 + s * 0.12, cy + s * 0.28), fill=(244, 160, 176))
    # smile
    d.arc((cx - s * 0.34, cy + s * 0.02, cx + s * 0.34, cy + s * 0.48), 20, 160, fill=(92, 46, 42), width=5)


def face_sad(d, cx, cy, s):
    for side in (-1, 1):
        ex, ey = cx + side * s * 0.36, cy - s * 0.02
        d.line((ex - s * 0.16, ey, ex + s * 0.16, ey), fill=(228, 220, 210), width=5)
    d.arc((cx - s * 0.28, cy + s * 0.18, cx + s * 0.28, cy + s * 0.5), 200, 340, fill=(228, 220, 210), width=5)


def steak_slab(d, box, color):
    d.rounded_rectangle(box, 28, fill=color, outline=(40, 16, 12), width=3)


def main():
    w, h = 1100, 720
    img = Image.new("RGB", (w, h), (244, 226, 196))
    d = ImageDraw.Draw(img)
    banner(img, "MOCK / offline food preview  ·  not a Roblox Studio screenshot")
    d.text((24, 48), "Before: one colored block. After: original face on the top. The meat color is still the cook cue.", font=font(16), fill=(42, 20, 12))

    # burger before / after
    d.text((70, 90), "Burger before", font=font(18, True), fill=(42, 20, 12))
    patty(d, 170, 230, 110, (196, 110, 70))
    d.text((360, 90), "Burger cooking", font=font(18, True), fill=(42, 20, 12))
    patty(d, 470, 230, 110, (139, 74, 43))
    face_happy(d, 470, 220, 150, False)
    d.text((640, 90), "Burger burnt", font=font(18, True), fill=(42, 20, 12))
    patty(d, 790, 230, 110, (20, 20, 20))
    face_sad(d, 790, 220, 140)

    # steak
    d.text((70, 390), "Steak before", font=font(18, True), fill=(42, 20, 12))
    steak_slab(d, (50, 440, 290, 620), (90, 30, 18))
    d.text((360, 390), "Steak cooking", font=font(18, True), fill=(42, 20, 12))
    steak_slab(d, (340, 440, 620, 620), (90, 30, 18))
    face_happy(d, 450, 520, 130, True)
    d.rounded_rectangle((560, 500, 600, 560), 8, fill=(243, 230, 208))
    d.text((640, 390), "Steak burnt", font=font(18, True), fill=(42, 20, 12))
    steak_slab(d, (650, 440, 930, 620), (20, 20, 20))
    face_sad(d, 760, 520, 120)
    d.rounded_rectangle((860, 500, 900, 560), 8, fill=(138, 128, 120))

    d.text((24, 660), "Brown around the face is the cook. Black slab is the burn. Faces do not replace that color.", font=font(16), fill=(42, 20, 12))
    d.text((24, 686), "Close-up of the part plan in CuteFace.luau. Studio lighting, smoke, and camera are not in this picture.", font=font(14), fill=(90, 60, 40))
    path = f"{OUT}/mock-food-faces.png"
    img.save(path)
    print(path)


if __name__ == "__main__":
    main()
