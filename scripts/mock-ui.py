#!/usr/bin/env python3
"""Draw labeled MOCK screens of the porch-light UI. These are not Roblox Studio captures."""

from PIL import Image, ImageDraw, ImageFont

OUT = "/workspace/marketing/ui-mocks"
BG = (58, 36, 24)
PANEL = (74, 46, 30)
CARD = (84, 53, 36)
CARD_HI = (92, 58, 36)
CREAM = (255, 248, 240)
DIM = (243, 210, 180)
INK = (42, 20, 12)
EMBER = (194, 65, 12)
GOLD = (255, 209, 90)
GREEN = (20, 107, 52)
RED = (180, 35, 24)
BLUE = (29, 78, 137)
GRASS = (92, 148, 62)
SKY = (255, 214, 163)


def font(size, bold=False):
    path = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
    return ImageFont.truetype(path, size)


def rr(draw, box, r, fill, outline=None, width=2):
    draw.rounded_rectangle(box, r, fill=fill, outline=outline, width=width)


def banner(img, text):
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, img.width, 36), fill=(20, 10, 6))
    d.text((12, 8), text, font=font(16, True), fill=GOLD)


def pill(d, xy, w, h, icon, value, color):
    x, y = xy
    rr(d, (x, y, x + w, y + h), 16, BG, color, 2)
    d.text((x + 10, y + 12), icon + "  " + value, font=font(18, True), fill=color)


def button(d, box, text, fill):
    rr(d, box, 10, fill, (42, 22, 14), 2)
    ink = INK if fill == GOLD else CREAM
    tw = d.textlength(text, font=font(16, True))
    x = box[0] + (box[2] - box[0] - tw) / 2
    d.text((x, box[1] + 12), text, font=font(16, True), fill=ink)


def station(d, x, y, title, name, btn, fill, short=False):
    height = 112 if short else 150
    rr(d, (x, y, x + 168, y + height), 12, BG, CARD, 2)
    d.text((x + 10, y + 6), title, font=font(13, True), fill=DIM)
    d.text((x + 10, y + 24), name, font=font(15, True), fill=CREAM)
    bar_y = y + (40 if short else 64)
    d.rounded_rectangle((x + 10, bar_y, x + 158, bar_y + 10), 5, fill=(42, 22, 14))
    d.rounded_rectangle((x + 10, bar_y, x + 90, bar_y + 10), 5, fill=EMBER)
    d.text((x + 10, bar_y + 14), "2m left", font=font(12), fill=DIM)
    button(d, (x + 10, y + height - 40, x + 158, y + height - 6), btn, fill)


def hud(w, h, compact):
    img = Image.new("RGB", (w, h), GRASS)
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, w, int(h * 0.45)), fill=SKY)
    d.polygon([(0, int(h * 0.42)), (w, int(h * 0.36)), (w, h), (0, h)], fill=GRASS)
    banner(img, "MOCK UI  ·  not a Roblox Studio screenshot  ·  " + ("phone layout" if compact else "desktop layout"))
    y0 = 44
    if compact:
        pill(d, (12, y0), 150, 44, "coin", "1,250", GOLD)
        pill(d, (170, y0), 140, 44, "aura", "80", (212, 194, 255))
        pill(d, (318, y0), 180, 44, "rank", "Lil Griller", CREAM)
        d.text((510, y0 + 10), "swipe menu →", font=font(14), fill=INK)
        mx = 12
        for label in ("Pit Shop", "Season", "Sauce", "Index", "Path"):
            button(d, (mx, 96, mx + 88, 148), label, BG)
            mx += 96
        rr(d, (12, 154, w - 12, 236), 14, BG, GOLD, 3)
        d.text((24, 160), "Unc's Rookie List   1/5", font=font(15, True), fill=GOLD)
        button(d, (w - 112, 158, w - 24, 198), "Skip", CARD)
        d.text((24, 188), "Flip a burger on the grill", font=font(15, True), fill=CREAM)
        d.text((24, 208), "Finish all 5: bandana + title + 250", font=font(13), fill=GOLD)
        bw = (w - 36) // 3
        button(d, (12, 240, 12 + bw, 276), "Serve All", GREEN)
        button(d, (20 + bw, 240, 20 + bw * 2, 276), "Collect All", BLUE)
        button(d, (28 + bw * 2, 240, w - 12, 276), "Home", CARD)
        station(d, 12, 278, "Grill 1", "Burger", "FLIP!", GOLD, True)
        station(d, 188, 278, "Smoker 1", "Brisket", "Smoking...", CARD, True)
    else:
        pill(d, (w // 2 - 420, y0), 160, 48, "coin", "12,400", GOLD)
        pill(d, (w // 2 - 250, y0), 150, 48, "aura", "860", (212, 194, 255))
        pill(d, (w // 2 - 90, y0), 200, 48, "rank", "Unc", CREAM)
        pill(d, (w // 2 + 120, y0), 150, 48, "cooler", "2/20", (185, 230, 255))
        my = 100
        for label in ("Pit Shop", "Season", "Sauce", "Index", "Path", "Upgrade", "Daily", "Settings"):
            button(d, (16, my, 112, my + 64), label, BG)
            my += 70
        sx = 140
        station(d, sx, h - 188, "Grill 1", "Burger", "FLIP!", GOLD)
        station(d, sx + 180, h - 188, "Grill 2", "Empty grill", "Cook", EMBER)
        station(d, sx + 360, h - 188, "Smoker 1", "Texas Brisket", "Smoking...", CARD)
        button(d, (w - 210, h - 188 - 168, w - 16, h - 188 - 116), "Serve All (3)", GREEN)
        button(d, (w - 210, h - 188 - 108, w - 16, h - 188 - 60), "Collect All", BLUE)
        button(d, (w - 160, h - 188 - 52, w - 16, h - 188 - 8), "Home", CARD)
        rr(d, (w - 380, 110, w - 20, 300), 14, BG, GOLD, 3)
        d.text((w - 360, 124), "Unc's Rookie List     1/5", font=font(18, True), fill=GOLD)
        button(d, (w - 130, 120, w - 36, 164), "Skip", CARD)
        d.text((w - 360, 176), "Flip a burger on the grill", font=font(18, True), fill=CREAM)
        d.text((w - 360, 214), "Tap FLIP! when the button turns gold.", font=font(15), fill=DIM)
        d.text((w - 360, 248), "Finish all 5 to earn the bandana,", font=font(15), fill=GOLD)
        d.text((w - 360, 270), "the title, and +250 coins.", font=font(15), fill=GOLD)
    return img


def shop(w, h, compact):
    img = Image.new("RGB", (w, h), (30, 18, 12))
    d = ImageDraw.Draw(img)
    banner(img, "MOCK UI  ·  not a Roblox Studio screenshot  ·  Pit Shop  ·  " + ("phone" if compact else "desktop"))
    margin = 16 if compact else 80
    rr(d, (margin, 48, w - margin, h - 16), 18, BG, EMBER, 3)
    d.text((margin + 24, 60), "Pitmaster Outfitters", font=font(26 if not compact else 20, True), fill=CREAM)
    button(d, (w - margin - 64, 56, w - margin - 16, 100), "X", RED)
    tabs = ["This Week", "Bundles", "Fits", "Passes"] if compact else ["This Week", "Bundles", "Fits", "Smokers", "Boosts", "Passes"]
    tx = margin + 24
    for i, name in enumerate(tabs):
        button(d, (tx, 112, tx + 120, 156), name, EMBER if i == 0 else CARD)
        tx += 128
    cards = [
        ("Grill Master Apron", "The classic. Red apron, big letters.", "Buy  R$ 75", GREEN),
        ("Pitmaster Cowboy Hat", "A wide-brim hat fit for the pit.", "Buy  R$ 99", GREEN),
        ("Whole Hog Collection", "Six looks. Own 2/6. Price stays put.", "Buy  R$ 499", GREEN),
    ]
    if compact:
        cards = cards[:1]
    cw = 200 if not compact else (w - margin * 2 - 64)
    cx = margin + 28
    cy = 164 if compact else 176
    for title, desc, label, fill in cards:
        card_h = 156 if compact else 250
        rr(d, (cx, cy, cx + cw, cy + card_h), 14, CARD)
        d.text((cx + 16, cy + 12), title, font=font(16, True), fill=CREAM)
        d.text((cx + 16, cy + 44), desc, font=font(14), fill=DIM)
        d.text((cx + 16, cy + 78), "Own 2/6" if "Whole" in title else "Looks only", font=font(14), fill=GOLD)
        button(d, (cx + 16, cy + card_h - 52, cx + cw - 72, cy + card_h - 12), label, fill)
        button(d, (cx + cw - 64, cy + card_h - 52, cx + cw - 12, cy + card_h - 12), "Gift", (157, 23, 77))
        if compact:
            cy += 264
        else:
            cx += cw + 16
    d.text((margin + 24, h - 48), "Every purchase shows exactly what you get. Tap Gift to gift a look.", font=font(14), fill=DIM)
    return img


def settings(w, h, compact):
    img = Image.new("RGB", (w, h), (30, 18, 12))
    d = ImageDraw.Draw(img)
    banner(img, "MOCK UI  ·  not a Roblox Studio screenshot  ·  Settings  ·  " + ("phone" if compact else "desktop"))
    margin = 12 if compact else 100
    rr(d, (margin, 48, w - margin, h - 12), 18, BG, EMBER, 3)
    d.text((margin + 20, 58), "Settings & Fits", font=font(24, True), fill=CREAM)
    button(d, (w - margin - 60, 54, w - margin - 12, 98), "X", RED)
    tx = margin + 20
    for i, name in enumerate(("Fits", "Titles", "Game")):
        button(d, (tx, 108, tx + 110, 152), name, EMBER if i == 2 else CARD)
        tx += 118
    rows = [
        ("Peace Mode: ON", "Nobody can snag plates while this is on.", "Turn off", CARD_HI),
        ("Sound effects: ON", "Sizzles, the register, and Big Bertha's bell.", "Turn off", CARD_HI),
        ("Music: ON  ·  22%", "Porch Light is not on Roblox yet, so the ranch stays quiet. Volume still saves.", None, None),
        ("Unc's Rookie List: skipped", "Bring it back to finish it and still earn the reward.", "Bring it back", GREEN),
    ]
    y = 160 if compact else 168
    row_h = 72 if compact else 100
    inner_r = w - margin - 20
    shown = rows if not compact else (rows[0], rows[2], rows[3])
    for title, detail, action, fill in shown:
        rr(d, (margin + 16, y, inner_r, y + row_h - 6), 12, CARD)
        d.text((margin + 28, y + 8), title, font=font(15, True), fill=CREAM)
        if not compact:
            d.text((margin + 28, y + 34), detail[:78], font=font(13), fill=DIM)
        if action and not compact:
            button(d, (inner_r - 168, y + 26, inner_r - 12, y + 70), action, fill)
        elif action and compact:
            button(d, (inner_r - 150, y + 28, inner_r - 10, y + 62), action, fill)
        else:
            by = y + (34 if compact else 56)
            button(d, (margin + 28, by, margin + 100, by + 32), "Mute", CARD_HI)
            button(d, (margin + 108, by, margin + 190, by + 32), "Quiet", EMBER)
            button(d, (margin + 198, by, margin + 270, by + 32), "Easy", CARD_HI)
            if not compact:
                button(d, (margin + 278, by, margin + 360, by + 32), "Full", CARD_HI)
        y += row_h
    return img


def main():
    import os
    os.makedirs(OUT, exist_ok=True)
    pairs = {
        "mock-desktop-hud.png": hud(1280, 720, False),
        "mock-desktop-shop.png": shop(1280, 720, False),
        "mock-desktop-settings.png": settings(1280, 720, False),
        "mock-mobile-hud.png": hud(844, 390, True),
        "mock-mobile-shop.png": shop(844, 390, True),
        "mock-mobile-settings.png": settings(844, 390, True),
    }
    for name, img in pairs.items():
        path = f"{OUT}/{name}"
        img.save(path)
        print(path, img.size)


if __name__ == "__main__":
    main()
