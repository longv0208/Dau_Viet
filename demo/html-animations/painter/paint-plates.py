# -*- coding: utf-8 -*-
"""Paint the layered art plates for the Bạch Đằng 938 demo.

Outputs transparent PNGs sized for the 1200x700 design space:
  sky-dawn.png            1200x480  opaque — majestic dawn sky + sun radiance + soft clouds
  mountains-far.png       1200x380  alpha — distant karst ridges w/ soft atmospheric haze
  mountains-near.png      1200x400  alpha — craggy karst towers w/ fissures & misty base
  river-high.png          1200x380  alpha — deep river currents + golden sun reflection
  river-surface.png       1200x70   alpha — foamy wavelet strip at waterline
  boats-viet.png          700x340   alpha — sleek Ngô Quyền dragon war galley (red sails)
  boats-han.png           700x340   alpha — massive Southern Han fortress ship (buff sails)
  boats-han-broken.png    700x340   alpha — impaled, shattered & sinking Han warship
  stakes.png              1200x300  alpha — lethal iron-tipped wooden stake field (in river)
  splinters.png           600x200   alpha — shattered timber, broken oars & shields
  reeds.png               1200x220  alpha — lush riverside reed beds (ambush cover)
  mist.png                1200x240  alpha — drifting morning mist banks
  vignette.png            1200x700  alpha — cinematic edge darkening

Run: python -I paint-plates.py (outputs into ../art/)
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw, ImageFilter
from common import (vertical_gradient, noise_layer, apply_noise, stroke,
                    wash, grain, mist_blob, mix, clamp, lerp)

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art")
os.makedirs(OUT, exist_ok=True)
DW, DH = 1200, 700


def save_rgba(img, name):
    path = os.path.join(OUT, name)
    img.convert("RGBA").save(path, "PNG", optimize=True)
    print("wrote", name, img.size, os.path.getsize(path), "bytes")


def _bez(p0, p1, p2, t):
    x = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0]
    y = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]
    return (x, y)


def _bezier_path(p0, p1, p2, steps=24):
    return [_bez(p0, p1, p2, i / steps) for i in range(steps + 1)]


# ---------------- SKY ----------------
def paint_sky():
    w, h = DW, 480
    sky = vertical_gradient((w, h), [
        (0.00, (24, 42, 66)),     # deep twilight sapphire
        (0.24, (54, 76, 104)),
        (0.46, (126, 92, 106)),   # soft coral-purple transition
        (0.66, (214, 122, 72)),   # warm amber dawn band
        (0.84, (252, 180, 88)),   # glowing gold
        (1.00, (255, 234, 172)),  # radiant sunrise at horizon
    ]).convert("RGBA")

    # crepuscular dawn rays emanating from the sun
    rays = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    rd = ImageDraw.Draw(rays)
    sx, sy = w * 0.74, h * 0.62
    rnd_rays = random.Random(42)
    for _ in range(18):
        angle = rnd_rays.uniform(math.pi * 0.72, math.pi * 1.38)
        spread = rnd_rays.uniform(0.03, 0.10)
        length = rnd_rays.uniform(w * 0.55, w * 1.05)
        p1 = (sx + math.cos(angle - spread) * length, sy + math.sin(angle - spread) * length)
        p2 = (sx + math.cos(angle + spread) * length, sy + math.sin(angle + spread) * length)
        alpha = rnd_rays.randint(10, 24)
        rd.polygon([(sx, sy), p1, p2], fill=(255, 230, 165, alpha))
    rays = rays.filter(ImageFilter.GaussianBlur(16))
    sky = Image.alpha_composite(sky, rays)

    # soft layered cloud bands
    clouds = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    cd = ImageDraw.Draw(clouds)
    rnd_c = random.Random(19)
    for _ in range(36):
        cy = h * rnd_c.uniform(0.10, 0.62)
        cx = rnd_c.uniform(-60, w + 60)
        cw = rnd_c.uniform(160, 480)
        ch = rnd_c.uniform(12, 34)
        warm = cy > h * 0.40
        color = (255, 214, 155) if warm else (165, 185, 210)
        alpha = int(rnd_c.uniform(16, 42))
        cd.ellipse([cx - cw / 2, cy - ch / 2, cx + cw / 2, cy + ch / 2], fill=color + (alpha,))
    clouds = clouds.filter(ImageFilter.GaussianBlur(18))
    sky = Image.alpha_composite(sky, clouds)

    # sun with natural atmospheric diffusion
    sun = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sun)
    for r, a in ((320, 18), (220, 32), (150, 58), (90, 95), (50, 160)):
        sd.ellipse([sx - r, sy - r, sx + r, sy + r], fill=(255, 226, 155, a))
    sun = sun.filter(ImageFilter.GaussianBlur(26))
    sd = ImageDraw.Draw(sun)
    sd.ellipse([sx - 34, sy - 34, sx + 34, sy + 34], fill=(255, 248, 215, 240))
    sky = Image.alpha_composite(sky, sun.filter(ImageFilter.GaussianBlur(4)))

    rgb = apply_noise(sky.convert("RGB"), noise_layer((w, h), 70, 14, seed=5), 0.5)
    save_rgba(rgb, "sky-dawn.png")


# ---------------- MOUNTAINS (ORGANIC KARSTS) ----------------
def paint_mountains_far():
    """Dãy núi đá vôi xa: thon mờ, mềm mại trong sương mai, không gai góc."""
    w, h = DW, 380
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Generate smooth organic rolling karst profile using harmonic sine curves
    pts = [(0, h)]
    for x in range(0, w + 12, 8):
        y = (240
             - 70 * math.sin(x * 0.0055)
             - 35 * math.sin(x * 0.011 + 1.2)
             - 22 * math.cos(x * 0.021 + 0.5)
             - 15 * abs(math.sin(x * 0.038)))
        pts.append((x, max(130, y)))
    pts.append((w, h))

    sil = Image.new("L", (w, h), 0)
    ImageDraw.Draw(sil).polygon(pts, fill=220)
    sil = sil.filter(ImageFilter.GaussianBlur(3.5))

    tint = vertical_gradient((w, h), [
        (0.00, (120, 144, 168)),
        (0.65, (95, 118, 136)),
        (1.00, (245, 220, 175)),  # melts into morning river mist
    ]).convert("RGBA")

    img = Image.composite(tint, Image.new("RGBA", (w, h), (0, 0, 0, 0)), sil)
    save_rgba(img, "mountains-far.png")


def paint_mountains_near():
    """Dãy núi đá vôi gần: vách đá tai mèo hiểm trở, rãnh phong hóa và rêu phong."""
    w, h = DW, 400
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Realistic karst towers with stepped vertical cliffs
    pts = [(0, h)]
    rnd = random.Random(89)
    for x in range(0, w + 10, 8):
        # Karst topography: steep spires with saddles
        t1 = math.sin(x * 0.008) * 85
        t2 = abs(math.cos(x * 0.016 + 0.8)) * 55
        t3 = math.sin(x * 0.032) * 22
        y = 260 - t1 - t2 - t3
        pts.append((x, max(150, y)))
    pts.append((w, h))

    sil = Image.new("L", (w, h), 0)
    ImageDraw.Draw(sil).polygon(pts, fill=255)
    sil = sil.filter(ImageFilter.GaussianBlur(1.8))

    tint = vertical_gradient((w, h), [
        (0.00, (68, 92, 108)),
        (0.55, (46, 68, 82)),
        (0.85, (36, 56, 70)),
        (1.00, (240, 215, 170)),  # base fades into river fog
    ]).convert("RGBA")
    img = Image.composite(tint, Image.new("RGBA", (w, h), (0, 0, 0, 0)), sil)

    # Cliff face vertical fissures & lighting
    crags = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    cd = ImageDraw.Draw(crags)
    for i in range(12, len(pts) - 12, 5):
        px, py = pts[i]
        if py < 250:
            # shady side wash
            cd.polygon([(px, py), (px + 35, py + 110), (px - 15, py + 130)],
                       fill=(20, 32, 42, 45))
            # vertical fissures
            cd.line([(px + 4, py + 6), (px + 8, py + 85)], fill=(15, 22, 30, 65), width=2)
            # morning light edge
            cd.line([(px - 2, py + 2), (px + 12, py + 60)], fill=(255, 230, 175, 55), width=2)

    crags = crags.filter(ImageFilter.GaussianBlur(2.5))
    img = Image.alpha_composite(img, Image.composite(crags, Image.new("RGBA", (w, h), (0, 0, 0, 0)), sil))

    save_rgba(img, "mountains-near.png")


# ---------------- RIVER ----------------
def paint_river():
    """Mặt nước sông Bạch Đằng: độ sâu ngọc bích, dòng chảy cuộn xiết, phản chiếu nắng bình minh."""
    w, h = DW, 380
    img = vertical_gradient((w, h), [
        (0.00, (172, 210, 220)),  # sky reflection at tide level
        (0.20, (102, 166, 188)),
        (0.50, (42, 122, 156)),   # deep flowing tidal channel
        (0.80, (24, 72, 102)),
        (1.00, (14, 48, 72)),
    ]).convert("RGBA")

    ov = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    rnd = random.Random(77)

    # current streaks rushing horizontally towards sea (rightward)
    for _ in range(240):
        y = rnd.uniform(4, h - 4)
        x = rnd.uniform(0, w)
        ln = rnd.uniform(60, 240)
        c = (235, 248, 255) if rnd.random() < 0.6 else (14, 50, 72)
        stroke(d, x, y, ln, rnd.uniform(-0.02, 0.02), rnd.uniform(1.8, 4.5), c, alpha=int(rnd.uniform(14, 34)))

    # brilliant sun-glint lane on the right
    for _ in range(85):
        y = rnd.uniform(0, h * 0.55)
        x = w * 0.66 + rnd.uniform(-70, 260)
        ln = rnd.uniform(20, 100)
        stroke(d, x, y, ln, rnd.uniform(-0.02, 0.02), rnd.uniform(2, 4.2),
               (255, 234, 172), alpha=int(rnd.uniform(30, 70)))

    ov = ov.filter(ImageFilter.GaussianBlur(1.2))
    img = Image.alpha_composite(img, ov)
    img = apply_noise(img, noise_layer((w, h), 60, 12, seed=12), 0.4)
    save_rgba(img, "river-high.png")

    # Wavelet strip for moving waterline
    wv = Image.new("RGBA", (DW, 70), (0, 0, 0, 0))
    dd = ImageDraw.Draw(wv)
    rnd_w = random.Random(49)
    for i in range(10):
        y = 5 + i * 6 + rnd_w.uniform(-1, 2)
        amp = rnd_w.uniform(2.0, 4.0)
        period = rnd_w.uniform(65, 125)
        phase = rnd_w.uniform(0, 6.28)
        pts = [(x, y + math.sin(x / period * 6.28 + phase) * amp) for x in range(0, DW + 8, 6)]
        alpha = int(max(14, 70 - i * 6))
        dd.line(pts, fill=(240, 252, 255, alpha), width=2)
    wv = wv.filter(ImageFilter.GaussianBlur(0.7))
    save_rgba(wv, "river-surface.png")


# ---------------- REEDS (BÃI LAU SẬY) ----------------
def paint_reeds():
    """Bãi lau sậy ven bờ sông Bạch Đằng: nơi quân Ngô Quyền giấu quân phục kích."""
    w, h = DW, 220
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rnd = random.Random(88)

    # Clusters on left and right riverbanks
    clusters = [(0, 360), (w - 360, w)]
    for x_min, x_max in clusters:
        for _ in range(150):
            rx = rnd.uniform(x_min, x_max)
            r_base = h + 10
            r_height = rnd.uniform(90, 190)
            r_top = r_base - r_height
            bend = rnd.uniform(-22, 22)
            reed_color = mix((78, 96, 58), (160, 136, 82), rnd.random())

            # Stem
            stem = _bezier_path((rx, r_base), (rx + bend * 0.4, r_base - r_height * 0.5), (rx + bend, r_top), 12)
            d.line(stem, fill=reed_color + (rnd.randint(160, 230),), width=2)

            # Leaves
            for _ in range(2):
                ly = r_base - r_height * rnd.uniform(0.2, 0.7)
                lx = rx + bend * (ly / r_height)
                lang = rnd.uniform(-0.55, 0.55)
                lln = rnd.uniform(25, 55)
                d.line([(lx, ly), (lx + math.cos(lang) * lln, ly + math.sin(lang) * 18)],
                       fill=reed_color + (150,), width=2)

            # Feathery white/gold plumes (bông lau trắng phơ phất)
            px, py = rx + bend, r_top
            for _ in range(7):
                p_len = rnd.uniform(10, 24)
                p_ang = math.pi * 0.5 + rnd.uniform(-0.65, 0.65)
                d.line([(px, py), (px + math.cos(p_ang) * p_len, py - math.sin(p_ang) * p_len)],
                       fill=(248, 240, 226, rnd.randint(110, 190)), width=2)

    img = img.filter(ImageFilter.GaussianBlur(0.6))
    save_rgba(img, "reeds.png")


# ---------------- STAKES (BÃI CỌC BẠCH ĐẰNG) ----------------
def paint_stakes():
    """Bãi cọc gỗ lim bịt sắt: cắm trong lòng sông (y=430..680), nhọn hoắt, không chạm núi."""
    w, h = DW, 300
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rnd = random.Random(107)

    # 4 distinct rows of stakes (from distant small stakes to large foreground stakes)
    # Inside this 300-height image:
    # Row 1 (farthest): tip at y=45, base at y=230
    # Row 4 (nearest):  tip at y=20, base at y=290
    rows = [
        (0.38, 0.55, 15, 0.75),
        (0.52, 0.72, 13, 0.88),
        (0.68, 0.88, 11, 0.95),
        (0.85, 1.05, 9, 1.00),
    ]

    for yf, sf, n, al in rows:
        dx = w / (n + 1)
        for i in range(1, n + 1):
            x = i * dx + rnd.uniform(-dx * 0.32, dx * 0.32)
            base_y = 70 + yf * 200 + rnd.uniform(-10, 10)
            stake_len = 120 * sf
            top_y = base_y - stake_len
            sw = 9 * sf  # trunk radius

            # Stakes angle sharply seaward (rightward) to impale incoming hulls
            lean = rnd.uniform(0.16, 0.32)
            tip_x = x + lean * (base_y - top_y)

            # Dark ancient ironwood (gỗ lim / táu)
            wood = mix((72, 44, 26), (38, 24, 14), rnd.random())

            # Main tapered wooden trunk
            trunk_poly = [
                (x - sw, base_y),
                (x + sw, base_y),
                (tip_x + sw * 0.52, top_y + 32 * sf),
                (tip_x - sw * 0.52, top_y + 32 * sf),
            ]
            d.polygon(trunk_poly, fill=wood + (int(255 * al),))

            # Iron-capped lethal tip (đầu bịt sắt bén nhọn bóng loáng)
            iron_base_y = top_y + 32 * sf
            iron_tip_y = top_y - 8 * sf
            iron_tip_x = tip_x + lean * 8 * sf

            iron_poly = [
                (tip_x - sw * 0.58, iron_base_y),
                (iron_tip_x, iron_tip_y),
                (tip_x + sw * 0.58, iron_base_y),
            ]
            iron_color = mix((105, 114, 122), (58, 64, 72), rnd.random())
            d.polygon(iron_poly, fill=iron_color + (int(255 * al),))

            # Metallic glint on the sharp iron edge
            d.line([(tip_x - sw * 0.4, iron_base_y), (iron_tip_x, iron_tip_y)],
                   fill=(255, 242, 205, int(220 * al)), width=max(1, int(1.8 * sf)))

            # Iron ferrule band ring
            d.line([(tip_x - sw * 0.6, iron_base_y), (tip_x + sw * 0.6, iron_base_y)],
                   fill=(36, 40, 46, int(240 * al)), width=max(2, int(2.5 * sf)))

            # Weathered wood grain fissures
            for _ in range(3):
                gy = rnd.uniform(top_y + 36 * sf, base_y - 15 * sf)
                g_x = lerp(x, tip_x, (base_y - gy) / max(1, base_y - top_y)) + rnd.uniform(-sw * 0.35, sw * 0.35)
                stroke(d, g_x, gy, 15 * sf, math.pi * 0.5 - lean * 0.6, 1.6 * sf,
                       mix(wood, (8, 4, 2), 0.7), alpha=int(100 * al))

            # Dark waterline algae marks
            stroke(d, x, base_y - 8 * sf, sw * 2.2, 0, sw * 0.8,
                   (22, 42, 32), alpha=int(120 * al))

    img = img.filter(ImageFilter.GaussianBlur(0.4))
    save_rgba(img, "stakes.png")


# ---------------- WARSHIPS (THUYỀN CHIẾN) ----------------
def paint_boat_viet():
    """Chiến thuyền Ngô Quyền: dáng rồng vút cao, buồm đỏ cánh dơi, cờ lệnh tung bay."""
    w, h = 700, 340
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy, s = w * 0.5, h * 0.66, 1.25

    def T(x, y):
        return (cx + x * s, cy + y * s)

    # Sleek dragon-galley hull
    keel = _bezier_path(T(-160, -4), T(0, 30), T(155, -8), 32)
    gunwale = _bezier_path(T(-155, -16), T(0, -4), T(150, -26), 32)
    hull = gunwale + list(reversed(keel))
    d.polygon(hull, fill=(116, 64, 34, 255))

    # Dragon prow (mũi rồng sơn son thếp vàng)
    prow = [gunwale[-1], T(166, -40), T(172, -30), keel[-1]]
    d.polygon(prow, fill=(162, 44, 28, 255))
    d.line([T(150, -26), T(166, -40), T(172, -30)], fill=(255, 218, 115, 245), width=3)

    # Stern upswept tip
    d.polygon([gunwale[0], T(-166, -30), keel[0]], fill=(86, 44, 22, 255))

    # Gunwale lacquer rail & bronze shield discs (khiên đồng Đông Sơn)
    d.line([(p[0], p[1]) for p in gunwale], fill=(232, 188, 118, 240), width=max(2, int(3 * s)))
    for i in range(-5, 6):
        bx = cx + i * 24 * s
        by = cy + (abs(i) * 1.4 - 6) * s
        d.ellipse([bx - 6, by - 6, bx + 6, by + 6], fill=(188, 132, 48, 240), outline=(238, 192, 78, 255))

    # Oars
    for i in range(-5, 6):
        ox = cx + i * 24 * s
        d.line([(ox, cy), (ox - 18 * s, cy + 32 * s)], fill=(108, 58, 30, 220), width=3)

    # Mast
    mast_top = cy - 135 * s
    d.line([(cx - 10 * s, cy - 16 * s), (cx - 10 * s, mast_top)], fill=(52, 32, 16, 255), width=5)

    # Red battened sail (buồm đỏ cánh dơi Đại Việt)
    s_top = cy - 130 * s
    s_bot = cy - 30 * s
    m_x = cx - 10 * s
    b_x = cx + 80 * s
    top_edge = _bezier_path((m_x, s_top), ((m_x + b_x) / 2, s_top + 8 * s), (b_x, s_top + 14 * s), 16)
    right_edge = _bezier_path((b_x, s_top + 14 * s), (b_x + 18 * s, (s_top + s_bot) / 2), (b_x, s_bot + 6 * s), 16)
    bot_edge = _bezier_path((b_x, s_bot + 6 * s), ((m_x + b_x) / 2, s_bot + 22 * s), (m_x, s_bot), 16)
    left_edge = _bezier_path((m_x, s_bot), (m_x - 4 * s, (s_top + s_bot) / 2), (m_x, s_top), 16)
    sail = top_edge + right_edge + bot_edge + left_edge

    sail_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sail_img)
    sd.polygon(sail, fill=(190, 36, 30, 255))
    # Sun emblem on the red sail
    sd.ellipse([cx + 34 * s - 16, (s_top + s_bot) / 2 - 16, cx + 34 * s + 16, (s_top + s_bot) / 2 + 16],
               fill=(248, 208, 88, 225))
    # Battens
    for i in range(1, 5):
        t = i / 5
        by = lerp(s_top, s_bot, t)
        sd.line([(m_x, by), (lerp(b_x, m_x, 0.08) + 8 * s, by + 4 * s)], fill=(42, 10, 8, 220), width=2)
    sd.line(sail + [sail[0]], fill=(68, 14, 10, 230), width=2)
    img = Image.alpha_composite(img, sail_img)

    # Flying swallow-tail battle pennant on mast top
    pennant = _bezier_path((m_x, mast_top), (m_x + 24 * s, mast_top + 4 * s), (m_x + 46 * s, mast_top - 2 * s), 12)
    ImageDraw.Draw(img).line(pennant, fill=(248, 198, 42, 255), width=5)

    # Stern commander canopy (mái che quan quân)
    d = ImageDraw.Draw(img)
    canopy = [T(-125, -6), T(-120, -28), T(-95, -34), T(-70, -28), T(-65, -6)]
    d.polygon(canopy, fill=(166, 40, 32, 255))
    d.line(canopy, fill=(255, 222, 128, 225), width=2)

    img = img.filter(ImageFilter.GaussianBlur(0.4))
    save_rgba(img, "boats-viet.png")


def paint_boat_han():
    """Lâu thuyền Nam Hán: đồ sộ, hai tầng lầu, nặng nề, cờ Hán kiêu ngạo."""
    w, h = 700, 340
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy, s = w * 0.5, h * 0.65, 1.3

    def T(x, y):
        return (cx + x * s, cy + y * s)

    # Heavy iron-plated hull
    keel = _bezier_path(T(165, -4), T(0, 36), T(-165, -4), 32)
    gunwale = _bezier_path(T(162, -18), T(0, -6), T(-162, -18), 32)
    hull = gunwale + list(reversed(keel))
    hull_color = (66, 70, 82)
    d.polygon(hull, fill=hull_color + (255,))

    # Castle superstructure (2-tier tower)
    tier1 = [T(-70, -18), T(-70, -46), T(50, -46), T(50, -18)]
    tier2 = [T(-50, -46), T(-50, -70), T(30, -70), T(30, -46)]
    d.polygon(tier1, fill=(50, 54, 64, 255), outline=(118, 124, 138, 240))
    d.polygon(tier2, fill=(42, 46, 54, 255), outline=(138, 144, 158, 240))

    # Defensive arrow ports
    for x_off in (-52, -26, 0, 26):
        d.rectangle([T(x_off, -38)[0], T(x_off, -38)[1], T(x_off + 12, -28)[0], T(x_off + 12, -28)[1]],
                    fill=(16, 18, 22, 255))

    # Gunwale iron armor rim
    d.line([(p[0], p[1]) for p in gunwale], fill=(128, 134, 148, 255), width=max(2, int(3.5 * s)))

    # Heavy timber plank lines
    for i in (1, 2, 3):
        off_y = i * 9 * s
        pl = [(p[0], p[1] + off_y * 0.85) for p in
              _bezier_path(T(150, -6), T(0, 28), T(-150, -6), 24)]
        d.line(pl, fill=(22, 24, 30, 160), width=2)

    # Heavy mast
    mast_top = cy - 145 * s
    d.line([(cx + 14 * s, cy - 20 * s), (cx + 14 * s, mast_top)], fill=(42, 38, 34, 255), width=6)

    # Large buff/ochre lug sail
    s_top = cy - 140 * s
    s_bot = cy - 36 * s
    m_x = cx + 14 * s
    b_x = cx - 86 * s
    top_edge = _bezier_path((m_x, s_top), ((m_x + b_x) / 2, s_top + 10 * s), (b_x, s_top + 16 * s), 16)
    left_edge = _bezier_path((b_x, s_top + 16 * s), (b_x - 18 * s, (s_top + s_bot) / 2), (b_x, s_bot + 8 * s), 16)
    bot_edge = _bezier_path((b_x, s_bot + 8 * s), ((m_x + b_x) / 2, s_bot + 24 * s), (m_x, s_bot), 16)
    right_edge = _bezier_path((m_x, s_bot), (m_x + 4 * s, (s_top + s_bot) / 2), (m_x, s_top), 16)
    sail = top_edge + left_edge + bot_edge + right_edge

    sail_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sail_img)
    sd.polygon(sail, fill=(210, 196, 160, 255))
    # Chinese military insignia / banner on sail
    sd.rectangle([cx - 48 * s - 12, (s_top + s_bot) / 2 - 24, cx - 48 * s + 12, (s_top + s_bot) / 2 + 24],
                 fill=(158, 30, 26, 220))
    # Battens
    for i in range(1, 5):
        t = i / 5
        by = lerp(s_top, s_bot, t)
        sd.line([(m_x, by), (lerp(b_x, m_x, 0.08) - 8 * s, by + 4 * s)], fill=(60, 52, 40, 220), width=2)
    sd.line(sail + [sail[0]], fill=(78, 70, 54, 240), width=2)
    img = Image.alpha_composite(img, sail_img)

    # Han command banner on mast
    d = ImageDraw.Draw(img)
    banner = [T(14, -145), T(14, -165), T(-20, -155), T(14, -145)]
    d.polygon(banner, fill=(172, 32, 26, 255), outline=(232, 212, 118, 240))

    img = img.filter(ImageFilter.GaussianBlur(0.4))
    save_rgba(img, "boats-han.png")


def paint_boat_han_broken():
    """Chiến thuyền Nam Hán bị vỡ vụn, cọc đâm thủng toác đáy, cột buồm gãy sập, đang chìm!"""
    w, h = 700, 340
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy, s = w * 0.5, h * 0.65, 1.3

    def T(x, y):
        # Ship is heavily listed / tilted 22 degrees
        rad = math.radians(22)
        rx = x * math.cos(rad) - y * math.sin(rad)
        ry = x * math.sin(rad) + y * math.cos(rad) + 18
        return (cx + rx * s, cy + ry * s)

    # 1. Shattered Hull in two jagged halves
    hull_color = (56, 58, 68)
    aft_hull = [
        T(-165, -12), T(-60, -4), T(-20, 14), T(-10, 36),
        T(-70, 34), T(-165, 4)
    ]
    d.polygon(aft_hull, fill=hull_color + (255,))

    fwd_hull = [
        T(10, -22), T(162, -26), T(165, 4), T(70, 36),
        T(18, 38), T(5, 18),
    ]
    d.polygon(fwd_hull, fill=hull_color + (255,))

    # Gaping fracture breach with splintered timber
    breach = [T(-22, 12), T(12, 16), T(18, 38), T(-12, 38)]
    d.polygon(breach, fill=(10, 12, 16, 255))
    for _ in range(8):
        x_sp = random.uniform(-25, 20)
        d.line([T(x_sp, 14), T(x_sp + random.uniform(-6, 6), random.uniform(22, 42))],
               fill=(138, 98, 58, 255), width=3)

    # 2. Fatal iron-tipped stake impaling straight through hull
    stake_base = (cx - 10, cy + 90 * s)
    stake_tip = (cx + 15, cy - 20 * s)
    d.polygon([
        (stake_base[0] - 14, stake_base[1]),
        (stake_base[0] + 14, stake_base[1]),
        (stake_tip[0] + 7, stake_tip[1] + 25),
        (stake_tip[0] - 7, stake_tip[1] + 25),
    ], fill=(60, 36, 20, 255))
    # Iron point bursting through deck
    d.polygon([
        (stake_tip[0] - 8, stake_tip[1] + 25),
        (stake_tip[0], stake_tip[1] - 8),
        (stake_tip[0] + 8, stake_tip[1] + 25),
    ], fill=(92, 102, 112, 255), outline=(218, 228, 238, 240))

    # Shattered planks around the impaling point
    for _ in range(12):
        bx = cx + random.uniform(-30, 30)
        by = cy + random.uniform(0, 35)
        d.line([(bx, by), (bx + random.uniform(-15, 15), by + random.uniform(-12, 12))],
               fill=(158, 108, 62, 255), width=2)

    # 3. Toppled, snapped mast (cột buồm gãy sập 45 độ)
    mast_base = T(14, -10)
    mast_snap = T(14, -55)
    d.line([mast_base, mast_snap], fill=(40, 34, 28, 255), width=6)
    mast_fall_top = (mast_snap[0] - 110 * s, mast_snap[1] + 25 * s)
    d.line([mast_snap, mast_fall_top], fill=(40, 34, 28, 255), width=5)

    # 4. Torn, shredded sail drooping in ruins
    shred1 = [mast_snap, (mast_snap[0] - 50 * s, mast_snap[1] + 55 * s), (mast_snap[0] - 30 * s, mast_snap[1] + 80 * s)]
    shred2 = [(mast_snap[0] - 50 * s, mast_snap[1] + 20 * s), mast_fall_top, (mast_fall_top[0] + 20 * s, mast_fall_top[1] + 45 * s)]
    d.polygon(shred1, fill=(178, 162, 128, 230), outline=(58, 48, 34, 200))
    d.polygon(shred2, fill=(162, 148, 116, 220), outline=(58, 48, 34, 200))

    # Charred fire & burn marks (cháy đen do hỏa công)
    burn = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    bd = ImageDraw.Draw(burn)
    for _ in range(25):
        bx = cx + random.uniform(-80, 60)
        by = cy + random.uniform(-20, 25)
        bd.ellipse([bx - 12, by - 6, bx + 12, by + 6], fill=(16, 10, 6, 160))
    img = Image.alpha_composite(img, burn.filter(ImageFilter.GaussianBlur(3)))

    img = img.filter(ImageFilter.GaussianBlur(0.5))
    save_rgba(img, "boats-han-broken.png")


# ---------------- SPLINTERS & DEBRIS ----------------
def paint_splinters():
    w, h = 600, 200
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rnd = random.Random(55)

    # Broken timber planks floating
    for _ in range(22):
        x = rnd.uniform(20, w - 20)
        y = rnd.uniform(20, h - 20)
        length = rnd.uniform(25, 75)
        angle = rnd.uniform(-0.4, 0.4)
        c = mix((128, 82, 42), (58, 38, 22), rnd.random())
        p1 = (x - math.cos(angle) * length / 2, y - math.sin(angle) * length / 2)
        p2 = (x + math.cos(angle) * length / 2, y + math.sin(angle) * length / 2)
        d.line([p1, p2], fill=c + (240,), width=rnd.randint(4, 8))
        d.line([p1, (p1[0] - rnd.uniform(4, 10), p1[1] + rnd.uniform(-4, 4))], fill=(158, 118, 68, 255), width=2)
        d.line([p2, (p2[0] + rnd.uniform(4, 10), p2[1] + rnd.uniform(-4, 4))], fill=(158, 118, 68, 255), width=2)

    # Broken snapped oars
    for _ in range(8):
        x = rnd.uniform(40, w - 40)
        y = rnd.uniform(30, h - 30)
        d.line([(x - 20, y - 6), (x + 20, y + 6)], fill=(108, 72, 40, 230), width=3)
        d.polygon([(x + 20, y + 6), (x + 36, y + 9), (x + 34, y + 16), (x + 18, y + 10)],
                  fill=(132, 92, 52, 230))

    # Floating shields & barrels
    for _ in range(6):
        x = rnd.uniform(30, w - 30)
        y = rnd.uniform(25, h - 25)
        d.ellipse([x - 10, y - 6, x + 10, y + 6], fill=(142, 92, 38, 220), outline=(208, 158, 58, 255))

    img = img.filter(ImageFilter.GaussianBlur(0.4))
    save_rgba(img, "splinters.png")


# ---------------- MIST ----------------
def paint_mist():
    w, h = DW, 240
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rnd = random.Random(33)
    for _ in range(42):
        x = rnd.uniform(-80, w + 80)
        y = h * rnd.uniform(0.2, 0.75)
        mw = rnd.uniform(220, 520)
        mh = rnd.uniform(24, 62)
        mist_blob(d, x, y, mw, mh, (246, 236, 218), int(rnd.uniform(14, 28)))
    img = img.filter(ImageFilter.GaussianBlur(16))
    save_rgba(img, "mist.png")


# ---------------- VIGNETTE ----------------
def paint_vignette():
    w, h = DW, DH
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for i in range(50):
        t = i / 49
        inset = t * 0.52
        a = int(12 * (1 - t) ** 2.2)
        d.rectangle([w * inset * 0.10, h * inset * 0.10,
                     w * (1 - inset * 0.10), h * (1 - inset * 0.10)],
                    outline=(8, 12, 16, a), width=int(min(w, h) * 0.02) or 1)
    img = img.filter(ImageFilter.GaussianBlur(32))
    save_rgba(img, "vignette.png")


if __name__ == "__main__":
    print("START PAINTING ALL ART PLATES...")
    paint_sky()
    paint_mountains_far()
    paint_mountains_near()
    paint_river()
    paint_reeds()
    paint_boat_viet()
    paint_boat_han()
    paint_boat_han_broken()
    paint_stakes()
    paint_splinters()
    paint_mist()
    paint_vignette()
    print("ALL 13 ART PLATES SUCCESSFULLY GENERATED!")
