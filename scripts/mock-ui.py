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


# Current HUD colors (navy panels, orange actions), used for the Turkey Day preview.
NAVY = (18, 38, 63)
NAVY_2 = (26, 51, 84)
CREAM_N = (245, 249, 255)
DIM_N = (211, 226, 245)
ORANGE = (242, 107, 29)
GOLD_N = (255, 209, 90)
GREEN_N = (31, 157, 87)
SKY_N = (186, 214, 236)
GRASS_N = (92, 148, 62)


def event_hud(w, h, compact, fixed_toast):
    """Phone or desktop HUD with the Turkey Day login note.

    fixed_toast=True is the old spot (y=120), which sits on the guide.
    fixed_toast=False is the spot under the guide and the goals bar.
    """
    img = Image.new("RGB", (w, h), GRASS_N)
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, w, int(h * 0.42)), fill=SKY_N)
    # welcome arch and the pumpkins that only show during Turkey Day week
    arch_y = int(h * 0.28)
    d.rectangle((w // 2 - 70, arch_y, w // 2 - 58, arch_y + 70), fill=(107, 66, 38))
    d.rectangle((w // 2 + 58, arch_y, w // 2 + 70, arch_y + 70), fill=(107, 66, 38))
    d.rectangle((w // 2 - 78, arch_y - 16, w // 2 + 78, arch_y), fill=(139, 69, 19))
    d.text((w // 2 - 62, arch_y - 14), "BACKYARD COOKOUT", font=font(11, True), fill=GOLD_N)
    for px, py, r in ((w // 2 - 110, arch_y + 48, 16), (w // 2 - 132, arch_y + 58, 11), (w // 2 + 100, arch_y + 50, 15), (w // 2 + 124, arch_y + 60, 10)):
        d.ellipse((px, py, px + r * 2, py + r * 2), fill=ORANGE)
        d.rectangle((px + r - 2, py - 6, px + r + 2, py + 2), fill=(78, 107, 42))
    label = ("phone before" if fixed_toast else "phone after") if compact else ("desktop before" if fixed_toast else "desktop after")
    banner(img, "MOCK  ·  Turkey Day  ·  " + label)
    y0 = 44
    if compact:
        rr(d, (8, y0, w - 8, y0 + 44), 14, NAVY, GOLD_N, 2)
        d.text((18, y0 + 12), "1,250 coins    aura 80    Rookie", font=font(14, True), fill=GOLD_N)
        mx = 8
        for label in ("Shop", "Season", "Crew", "Gift"):
            button(d, (mx, 96, mx + 78, 140), label, NAVY)
            mx += 84
        guide = (8, 148, w - 8, 196)
        rr(d, guide, 12, NAVY, GOLD_N, 3)
        d.text((18, 156), "1/4   Claim your ranch", font=font(15, True), fill=GOLD_N)
        d.text((18, 176), "Tap the orange button to start your first brisket.", font=font(12), fill=DIM_N)
        button(d, (12, h - 168, w // 3 - 4, h - 124), "Serve All", GREEN_N)
        button(d, (w // 3 + 4, h - 168, 2 * w // 3 - 4, h - 124), "Collect", (61, 139, 255))
        button(d, (2 * w // 3 + 4, h - 168, w - 12, h - 124), "Home", NAVY_2)
        station(d, 12, h - 116, "Smoker 1", "Empty", "Cook", ORANGE, True)
        toast_y = 112 if fixed_toast else 204
    else:
        pill(d, (w // 2 - 360, y0), 160, 48, "coin", "1,250", GOLD_N)
        pill(d, (w // 2 - 190, y0), 140, 48, "aura", "80", (212, 194, 255))
        pill(d, (w // 2 - 40, y0), 180, 48, "rank", "Rookie", CREAM_N)
        my = 110
        for label in ("Shop", "Season", "Crew", "Daily", "Gift"):
            button(d, (16, my, 120, my + 52), label, NAVY)
            my += 58
        guide = (150, 112, 150 + 520, 164)
        rr(d, guide, 12, NAVY, GOLD_N, 3)
        d.text((164, 122), "1/4   Claim your ranch", font=font(16, True), fill=GOLD_N)
        d.text((164, 142), "Tap the orange button. Pip cooks burgers, not the turkey.", font=font(13), fill=DIM_N)
        button(d, (w - 220, h - 200, w - 24, h - 148), "Serve All", GREEN_N)
        station(d, 150, h - 140, "Smoker 1", "Harvest Turkey Leg", "15 min", ORANGE, False)
        toast_y = 64 if fixed_toast else 176
    note = "It's Turkey Day Cookout week! Smoke a Harvest Turkey Leg and share it at the potluck table."
    tw = min(460, w - 24)
    tx = (w - tw) // 2
    rr(d, (tx, toast_y, tx + tw, toast_y + 64), 10, GREEN_N)
    d.text((tx + 12, toast_y + 8), "Turkey Day", font=font(14, True), fill=NAVY)
    # wrap the note roughly
    words = note.split()
    line, y = "", toast_y + 28
    for word in words:
        trial = (line + " " + word).strip()
        if d.textlength(trial, font=font(13)) > tw - 24:
            d.text((tx + 12, y), line, font=font(13), fill=CREAM_N)
            line, y = word, y + 16
        else:
            line = trial
    if line:
        d.text((tx + 12, y), line, font=font(13), fill=CREAM_N)
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
        "mock-turkey-phone-before.png": event_hud(390, 844, True, True),
        "mock-turkey-phone-after.png": event_hud(390, 844, True, False),
        "mock-turkey-desktop-before.png": event_hud(1280, 720, False, True),
        "mock-turkey-desktop-after.png": event_hud(1280, 720, False, False),
    }
    here = os.path.dirname(os.path.abspath(__file__))
    repo_out = os.path.normpath(os.path.join(here, "..", "marketing", "ui-mocks"))
    os.makedirs(repo_out, exist_ok=True)
    os.makedirs("/opt/cursor/artifacts", exist_ok=True)
    for name, img in pairs.items():
        path = f"{OUT}/{name}"
        try:
            img.save(path)
            print(path, img.size)
        except OSError as err:
            print("skip", path, err)
        if name.startswith("mock-turkey-"):
            img.save(os.path.join(repo_out, name))
            img.save(os.path.join("/opt/cursor/artifacts", name))
            print(os.path.join(repo_out, name), img.size)


if __name__ == "__main__":
    main()
