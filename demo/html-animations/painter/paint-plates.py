# -*- coding: utf-8 -*-
"""Paint the layered art plates for the Bạch Đằng 938 demo.

Outputs transparent PNGs sized for the 1200x700 design space:
  sky-dawn.png        1200x500  opaque — sky + sun glow + clouds
  mountains-far.png   1200x360  alpha — distant ridge w/ atmospheric fade
  mountains-near.png  1200x420  alpha — closer ridge, darker
  river-high.png      1200x400  alpha — water body at high-tide level
  river-surface.png   1200x80   alpha — wavelet strip for the waterline
  boats-viet.png      700x320   alpha — Ngô Quyền war boat (right-facing)
  boats-han.png       700x320   alpha — Nam Hán war boat (left-facing)
  stakes.png          900x300   alpha — field of sharpened stakes
  mist.png            1200x240  alpha — drifting mist banks
  vignette.png        1200x700  alpha — soft dark edges

Run: python paint-plates.py  (outputs into ../art/)
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw, ImageFilter
from common import (vertical_gradient, noise_layer, apply_noise, stroke,
                    wash, grain, ridge_silhouette, mist_blob, mix, clamp,
                    lerp)

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art")
os.makedirs(OUT, exist_ok=True)
DW, DH = 1200, 700


def save_rgba(img, name):
    img.convert("RGBA").save(os.path.join(OUT, name), "PNG", optimize=True)
    print("wrote", name, img.size)


# ---------------- SKY ----------------
def paint_sky():
    w, h = DW, 500
    sky = vertical_gradient((w, h), [
        (0.00, (44, 78, 104)),    # deep teal-blue zenith
        (0.38, (98, 118, 124)),
        (0.62, (196, 150, 104)),  # warm band
        (0.82, (238, 200, 138)),
        (1.00, (250, 224, 170)),  # horizon gold
    ])
    # cloud bands: soft horizontal washes
    ov = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    rnd = random.Random(11)
    for i in range(26):
        y = h * (0.10 + rnd.random() * 0.5)
        x = rnd.random() * w
        cw = 160 + rnd.random() * 420
        ch = 14 + rnd.random() * 30
        warm = y > h * 0.45
        col = (250, 214, 160) if warm else (170, 190, 200)
        d.ellipse([x - cw / 2, y - ch / 2, x + cw / 2, y + ch / 2],
                  fill=col + (int(22 + rnd.random() * 30),))
    ov = ov.filter(ImageFilter.GaussianBlur(18))
    sky = Image.alpha_composite(sky.convert("RGBA"), ov)

    # sun + halo low on the right
    sun = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sun)
    sx, sy = w * 0.72, h * 0.62
    for r, a in ((300, 26), (210, 40), (140, 70), (86, 120)):
        sd.ellipse([sx - r, sy - r, sx + r, sy + r], fill=(255, 224, 160, a))
    sun = sun.filter(ImageFilter.GaussianBlur(30))
    sd = ImageDraw.Draw(sun)
    sd.ellipse([sx - 44, sy - 44, sx + 44, sy + 44], fill=(255, 236, 190, 235))
    sky = Image.alpha_composite(sky, sun.filter(ImageFilter.GaussianBlur(4)))

    # grain
    rgb = apply_noise(sky.convert("RGB"), noise_layer((w, h), 90, 18, seed=3), 0.6)
    save_rgba(rgb, "sky-dawn.png")


# ---------------- MOUNTAINS ----------------
def smooth_ridge_pts(w, h, base_y_frac, amp, seed):
    """Organic ridgeline: few broad peaks + soft noise, smooth curves."""
    rnd = random.Random(seed)
    n = 7
    peaks = []
    for i in range(n + 1):
        x = w * i / n
        peak = (h * base_y_frac
                - amp * (0.35 + 0.65 * abs(math.sin(i * 1.15 + seed)))
                - rnd.random() * amp * 0.18)
        peaks.append((x, peak))
    # densify + smooth with quadratic interpolation
    pts = [(-60, peaks[0][1] + 30)]
    for i in range(n):
        x0, y0 = peaks[i]
        x1, y1 = peaks[i + 1]
        mx = (x0 + x1) / 2
        my = min(y0, y1) - amp * 0.10
        # sample the quad curve at midpoints for a smooth polyline
        for t in (0.25, 0.5, 0.75):
            xt = (1 - t) * (1 - t) * x0 + 2 * (1 - t) * t * mx + t * t * x1
            yt = (1 - t) * (1 - t) * y0 + 2 * (1 - t) * t * my + t * t * y1
            pts.append((xt, yt))
        pts.append((x1, y1))
    pts.append((w + 60, peaks[-1][1] + 30))
    return pts


def paint_ridge(name, base_y_frac, amp, color_far, color_near, seed, alpha):
    w, h = DW, 420
    pts = smooth_ridge_pts(w, h, base_y_frac, amp, seed)
    # silhouette mask
    sil = Image.new("L", (w, h), 0)
    sd = ImageDraw.Draw(sil)
    sd.polygon(pts + [(w + 60, h), (-60, h)], fill=int(alpha))
    sil = sil.filter(ImageFilter.GaussianBlur(2.5))

    # atmospheric tint: ridge top slightly darker, base melts into haze
    tint = vertical_gradient((w, h), [
        (0.0, color_far),
        (0.7, color_near),
        (1.0, mix(color_near, (240, 212, 162), 0.6)),
    ]).convert("RGBA")
    img = Image.composite(tint, Image.new("RGBA", (w, h), (0, 0, 0, 0)), sil)

    # soft slope shading: faint darker wash under ridge crest
    sh = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sd2 = ImageDraw.Draw(sh)
    for i, (x, y) in enumerate(pts[:-1]):
        sd2.polygon([(x, y), (x + 70, y + 90), (x - 30, y + 120)],
                    fill=mix(color_near, (16, 26, 34), 0.35) + (46,))
    sh = sh.filter(ImageFilter.GaussianBlur(20))
    img = Image.alpha_composite(img, Image.composite(sh, Image.new("RGBA", (w, h), (0, 0, 0, 0)), sil))
    save_rgba(img, name)


# ---------------- RIVER ----------------
def paint_river():
    w, h = DW, 400
    img = vertical_gradient((w, h), [
        (0.0, (176, 214, 222)),   # reflecting sky at top
        (0.18, (110, 168, 188)),
        (0.5, (56, 142, 180)),    # sea.blue token
        (1.0, (24, 72, 96)),      # deep channel
    ]).convert("RGBA")

    # horizontal current streaks
    ov = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    rnd = random.Random(21)
    for _ in range(160):
        y = rnd.random() * h
        x = rnd.random() * w
        ln = 60 + rnd.random() * 220
        light = rnd.random() < 0.55
        c = (230, 244, 244) if light else (18, 60, 84)
        stroke(d, x, y, ln, (rnd.random() - 0.5) * 0.06,
               2 + rnd.random() * 5, c, alpha=int(14 + rnd.random() * 26))
    # sun-glint lane on the right
    for _ in range(60):
        y = rnd.random() * h * 0.5
        x = w * 0.62 + rnd.random() * w * 0.28
        ln = 20 + rnd.random() * 80
        stroke(d, x, y, ln, (rnd.random() - 0.5) * 0.05,
               2 + rnd.random() * 4, (255, 226, 160),
               alpha=int(30 + rnd.random() * 50))
    ov = ov.filter(ImageFilter.GaussianBlur(1.5))
    img = Image.alpha_composite(img, ov)
    img = apply_noise(img, noise_layer((w, h), 60, 12, seed=8), 0.5)
    save_rgba(img, "river-high.png")

    # wavelet strip for the waterline edge
    wv = Image.new("RGBA", (DW, 80), (0, 0, 0, 0))
    dd = ImageDraw.Draw(wv)
    rnd = random.Random(31)
    for i in range(9):
        y = 10 + i * 8 + rnd.random() * 3
        amp = 2.5 + rnd.random() * 3
        period = 90 + rnd.random() * 140
        phase = rnd.random() * 6.28
        pts = []
        for x in range(0, DW + 8, 8):
            pts.append((x, y + math.sin(x / period * 6.28 + phase) * amp))
        a = int(60 - i * 5)
        dd.line(pts, fill=(235, 248, 248, max(18, a)), width=2)
    wv = wv.filter(ImageFilter.GaussianBlur(0.8))
    save_rgba(wv, "river-surface.png")


# ---------------- BOATS ----------------
def _bez(p0, p1, p2, t):
    x = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0]
    y = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]
    return (x, y)


def _bezier_path(p0, p1, p2, steps=24):
    return [_bez(p0, p1, p2, i / steps) for i in range(steps + 1)]


def paint_boat(name, flip, hull_c, sail_c, sig_c, canopy=False):
    """Hand-painted river war junk: curved hull, bellied lug sail."""
    w, h = 700, 340
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    cx, cy, s = w / 2, h * 0.66, 1.2
    wind = -1 if flip else 1

    def T(x, y):
        return (cx + x, cy + y)

    d = ImageDraw.Draw(img)

    # ---- hull: smooth curve via beziers ----
    keel = _bezier_path(T(-150 * s * wind, -4 * s), T(0, 34 * s),
                        T(150 * s * wind, -4 * s), 30)
    gunwale = _bezier_path(T(-152 * s * wind, -14 * s), T(0, -2 * s),
                           T(148 * s * wind, -22 * s), 30)
    hull = gunwale + list(reversed(keel))
    d.polygon(hull, fill=hull_c + (255,))
    # bow + stern tips sweep up
    bowtip = [gunwale[-1], T(152 * s * wind, -34 * s), keel[-1]]
    sterntip = [gunwale[0], T(-156 * s * wind, -26 * s), keel[0]]
    d.polygon(bowtip, fill=mix(hull_c, (0, 0, 0), 0.15) + (255,))
    d.polygon(sterntip, fill=mix(hull_c, (0, 0, 0), 0.18) + (255,))
    # gunwale trim
    d.line([(p[0], p[1]) for p in gunwale],
           fill=mix(hull_c, (255, 214, 150), 0.4) + (220,),
           width=max(2, int(3.5 * s)))
    # plank lines
    for i in range(1, 4):
        off = i * 9 * s
        pl = [(p[0], p[1] + off * 0.9) for p in
              _bezier_path(T(-140 * s * wind, -6 * s), T(0, 26 * s),
                           T(140 * s * wind, -8 * s), 24)]
        d.line(pl, fill=mix(hull_c, (10, 8, 6), 0.35) + (140,),
               width=max(1, int(1.6 * s)))

    # ---- mast ----
    mast_x = -14 * s * wind
    mast_top, mast_bot = cy - 128 * s, cy - 20 * s
    d.line([(cx + mast_x, mast_bot), (cx + mast_x + 2 * s * wind, mast_top)],
           fill=(58, 36, 21, 255), width=max(3, int(4 * s)))

    # ---- lug sail: bellying quadrilateral built from bezier edges ----
    s_top_y, s_bot_y = -124 * s, -30 * s
    x_mast = mast_x + 2 * s * wind
    x_boom = mast_x + 74 * s * wind
    top_edge = _bezier_path(T(x_mast, s_top_y),
                            T((x_mast + x_boom) / 2, s_top_y + 10 * s),
                            T(x_boom, s_top_y + 14 * s), 18)
    right_edge = _bezier_path(T(x_boom, s_top_y + 14 * s),
                              T(x_boom + 14 * s * wind, (s_top_y + s_bot_y) / 2),
                              T(x_boom, s_bot_y + 8 * s), 18)
    bot_edge = _bezier_path(T(x_boom, s_bot_y + 8 * s),
                            T((x_mast + x_boom) / 2, s_bot_y + 22 * s),
                            T(x_mast, s_bot_y), 18)
    left_edge = _bezier_path(T(x_mast, s_bot_y), T(x_mast - 4 * s * wind, (s_top_y + s_bot_y) / 2),
                             T(x_mast, s_top_y), 18)
    sail = top_edge + right_edge + bot_edge + left_edge
    # sail shading: darker at edges, warm light mid
    sail_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sail_img)
    sd.polygon(sail, fill=sail_c + (255,))
    # inner lighter belly
    belly = [(lerp(p[0], cx + (x_mast + x_boom) / 2, 0.3),
              lerp(p[1], cy + (s_top_y + s_bot_y) / 2, 0.3)) for p in sail]
    sd.polygon(belly, fill=mix(sail_c, (255, 214, 160), 0.18) + (90,))
    sail_img = sail_img.filter(ImageFilter.GaussianBlur(1.2))
    img = Image.alpha_composite(img, sail_img)
    # battens — clipped so they never poke past the sail edge
    d = ImageDraw.Draw(img)
    sail_mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(sail_mask).polygon(sail, fill=255)
    bat = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    bd = ImageDraw.Draw(bat)
    for i in range(1, 5):
        t = i / 5
        y = lerp(s_top_y, s_bot_y, t)
        x0 = x_mast + 3 * s * wind
        x1 = lerp(x_boom, x_mast, 0.10) + lerp(70, 52, t) * s * wind
        seg = _bezier_path(T(x0, y), T((x0 + x1) / 2, y + 5 * s), T(x1, y + 3 * s), 12)
        bd.line(seg, fill=mix(sail_c, (30, 14, 8), 0.4) + (170,),
                width=max(1, int(2.2 * s)))
    img = Image.alpha_composite(img,
        Image.composite(bat, Image.new("RGBA", (w, h), (0, 0, 0, 0)),
                        sail_mask.filter(ImageFilter.GaussianBlur(0.6))))
    # outline
    d.line(sail + [sail[0]], fill=mix(sail_c, (20, 10, 6), 0.45) + (200,),
           width=max(1, int(1.8 * s)))

    # pennant streaming aft
    fl = _bezier_path(T(mast_x + 2 * s * wind, mast_top - cy - 2 * s + 2 * s),
                      T(mast_x + 20 * s * wind, mast_top - cy + 4 * s),
                      T(mast_x + 34 * s * wind, mast_top - cy - 2 * s), 10)
    d.line(fl, fill=sig_c + (240,), width=max(2, int(4 * s)))

    # stern canopy (Viet flagship only)
    if canopy:
        ax = -104 * s * wind
        canopy_pts = [T(ax - 26 * s, -4 * s), T(ax - 20 * s, -24 * s),
                      T(ax, -30 * s), T(ax + 20 * s, -24 * s), T(ax + 26 * s, -4 * s)]
        d.polygon(canopy_pts, fill=mix(hull_c, (46, 26, 14), 0.4) + (255,))
        d.line(canopy_pts, fill=mix(hull_c, (255, 220, 150), 0.3) + (160,),
               width=max(1, int(1.6 * s)))

    # weathering brush strokes on hull
    rnd = random.Random(4)
    for _ in range(52):
        x = (rnd.random() - 0.5) * 270 * s
        y = (rnd.random() - 0.35) * 30 * s
        c = mix(hull_c, (255, 235, 200), 0.16) if rnd.random() < 0.45 \
            else mix(hull_c, (10, 8, 6), 0.4)
        stroke(d, cx + x, cy + y, 10 + rnd.random() * 26,
               (rnd.random() - 0.5) * 0.25, 2 + rnd.random() * 3.4,
               c, alpha=int(46 + rnd.random() * 40))

    # soft waterline shadow under hull
    sh = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    shd = ImageDraw.Draw(sh)
    shd.ellipse([cx - 130 * s, cy + 24 * s, cx + 130 * s, cy + 36 * s],
                fill=(10, 20, 26, 70))
    img = Image.alpha_composite(sh.filter(ImageFilter.GaussianBlur(10)), img)

    img = img.filter(ImageFilter.GaussianBlur(0.5))
    save_rgba(img, name)


# ---------------- STAKES ----------------
def paint_stakes():
    w, h = 900, 300
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rnd = random.Random(9)
    rows = [(0.42, 0.62, 7, 0.75), (0.55, 0.80, 6, 0.9), (0.72, 1.0, 5, 1.0)]
    for yf, sf, n, al in rows:
        for i in range(n):
            x = w * (0.08 + 0.84 * (i / max(1, n - 1))) + (rnd.random() - 0.5) * 40
            top = h * yf - 170 * sf
            base = h * yf + 60 * sf
            sw = 10 * sf
            lean = (rnd.random() - 0.5) * 0.34      # stakes lean randomly
            wood = mix((96, 60, 34), (52, 32, 18), rnd.random())
            tip_x = x + lean * 46
            # body — slight taper
            d.polygon([(x - sw, base), (x + sw, base),
                       (tip_x + sw * 0.5, top + 30 * sf),
                       (tip_x - sw * 0.5, top + 30 * sf)],
                      fill=wood + (int(255 * al),))
            # sharpened point
            d.polygon([(tip_x - sw * 0.66, top + 30 * sf),
                       (tip_x + lean * 8, top - 10 * sf),
                       (tip_x + sw * 0.66, top + 30 * sf)],
                      fill=mix(wood, (18, 10, 5), 0.45) + (int(255 * al),))
            # lit edge on one side
            d.line([(x + sw * 0.7, base), (tip_x + sw * 0.5, top + 30 * sf)],
                   fill=mix(wood, (240, 200, 140), 0.4) + (int(160 * al),),
                   width=max(1, int(1.6 * sf)))
            # grain strokes
            for _ in range(5):
                yy = top + 34 * sf + rnd.random() * (base - top - 44 * sf)
                stroke(d, tip_x + (rnd.random() - 0.5) * sw * 0.8,
                       yy, 14 * sf, math.pi / 2 + lean * 0.3, 1.6 * sf,
                       mix(wood, (0, 0, 0), 0.55), alpha=int(90 * al))
            # algae/waterline tint near base
            stroke(d, x + lean * 8, base - 6, sw * 1.8, 0,
                   sw, (34, 56, 48), alpha=int(90 * al))
    img = img.filter(ImageFilter.GaussianBlur(0.5))
    save_rgba(img, "stakes.png")


# ---------------- MIST ----------------
def paint_mist():
    w, h = DW, 240
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rnd = random.Random(15)
    for _ in range(30):
        x = rnd.random() * w
        y = h * (0.3 + rnd.random() * 0.5)
        mw = 180 + rnd.random() * 380
        mh = 20 + rnd.random() * 44
        mist_blob(d, x, y, mw, mh, (246, 237, 218), int(16 + rnd.random() * 26))
    img = img.filter(ImageFilter.GaussianBlur(14))
    save_rgba(img, "mist.png")


# ---------------- VIGNETTE ----------------
def paint_vignette():
    w, h = DW, DH
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for i in range(46):
        t = i / 45
        inset = t * 0.5
        a = int(10 * (1 - t) ** 2)
        d.rectangle([w * inset * 0.10, h * inset * 0.10,
                     w * (1 - inset * 0.10), h * (1 - inset * 0.10)],
                    outline=(12, 16, 20, a), width=int(min(w, h) * 0.02) or 1)
    img = img.filter(ImageFilter.GaussianBlur(30))
    save_rgba(img, "vignette.png")


if __name__ == "__main__":
    paint_sky()
    paint_ridge("mountains-far.png", 0.62, 130, (126, 151, 166), (96, 120, 132), 0.3, 220)
    paint_ridge("mountains-near.png", 0.55, 170, (76, 100, 112), (52, 74, 88), 1.9, 255)
    paint_river()
    paint_boat("boats-viet.png", flip=False,
               hull_c=(106, 62, 36), sail_c=(179, 31, 31), sig_c=(165, 31, 24), canopy=True)
    paint_boat("boats-han.png", flip=True,
               hull_c=(70, 70, 82), sail_c=(216, 207, 168), sig_c=(138, 143, 152), canopy=False)
    paint_stakes()
    paint_mist()
    paint_vignette()
    print("ALL PLATES DONE")
