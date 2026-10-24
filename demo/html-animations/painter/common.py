# -*- coding: utf-8 -*-
"""Shared painterly helpers for the Bạch Đằng demo plates.

Pure-Pillow procedural painting: layered gradients, seeded noise fields
and many soft brush strokes so the output reads as hand-painted 2D,
not flat vector fills. Deterministic (fixed seed) so re-runs reproduce
identical plates.
"""
import math
import random
from PIL import Image, ImageDraw, ImageFilter


def clamp(v, lo=0, hi=255):
    return lo if v < lo else hi if v > hi else int(v)


def lerp(a, b, t):
    return a + (b - a) * t


def mix(c1, c2, t):
    return tuple(clamp(lerp(c1[i], c2[i], t)) for i in range(3))


# ---------- gradients ----------

def vertical_gradient(size, stops):
    """stops: [(y0-1, (r,g,b)), ...] -> RGB image with smooth gradient."""
    w, h = size
    img = Image.new("RGB", (1, h))
    px = img.load()
    for y in range(h):
        t = y / max(1, h - 1)
        c = stops[-1][1]
        for i in range(len(stops) - 1):
            p0, c0 = stops[i]
            p1, c1 = stops[i + 1]
            if p0 <= t <= p1:
                c = mix(c0, c1, (t - p0) / max(1e-6, p1 - p0))
                break
        px[0, y] = c
    return img.resize((w, h), Image.BILINEAR)


# ---------- noise / texture ----------

def noise_layer(size, scale=64, amp=24, seed=0, blur=None):
    """Random gray noise resized up -> soft cloudy variation. amp=±deviation."""
    rnd = random.Random(seed)
    sw, sh = max(2, size[0] // scale), max(2, size[1] // scale)
    n = Image.new("L", (sw, sh))
    np_ = n.load()
    for y in range(sh):
        for x in range(sw):
            np_[x, y] = rnd.randint(128 - amp, 128 + amp)
    n = n.resize(size, Image.BILINEAR)
    if blur:
        n = n.filter(ImageFilter.GaussianBlur(blur))
    return n


def apply_noise(img, noise, strength=0.5):
    """Modulate img luminance by noise: returns new RGB image."""
    img = img.convert("RGB")
    out = Image.new("RGB", img.size)
    ip, np_, op = img.load(), noise.load(), out.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            d = (np_[x, y] - 128) * strength
            p = ip[x, y]
            op[x, y] = (clamp(p[0] + d), clamp(p[1] + d), clamp(p[2] + d))
    return out


# ---------- brush work ----------

def stroke(draw, x, y, length, angle, width, color, alpha=255, taper=True):
    """Single painterly stroke: series of overlapping ellipses along angle."""
    steps = max(2, int(length / max(2, width * 0.55)))
    dx, dy = math.cos(angle), math.sin(angle)
    for i in range(steps):
        t = i / steps
        r = width * (0.5 + 0.5 * (1 - t)) if taper else width * 0.5
        sx = x + dx * length * t
        sy = y + dy * length * t
        a = int(alpha * (0.35 + 0.65 * (1 - t * 0.6)))
        draw.ellipse([sx - r, sy - r * 0.55, sx + r, sy + r * 0.55],
                     fill=color + (a,))


def wash(draw, box, color, alpha, strokes=40, seed=0, angle_jitter=0.4):
    """Soft watercolor wash inside box: many low-alpha strokes."""
    rnd = random.Random(seed)
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    for _ in range(strokes):
        x = x0 + rnd.random() * w
        y = y0 + rnd.random() * h
        ang = (rnd.random() - 0.5) * angle_jitter
        ln = w * (0.2 + rnd.random() * 0.5)
        wd = h * (0.1 + rnd.random() * 0.3)
        stroke(draw, x, y, ln, ang, wd, color, alpha)


def grain(img, seed=7, strength=8):
    """Fine paper-grain noise, cheap and subtle."""
    n = noise_layer(img.size, scale=4, amp=strength, seed=seed)
    return apply_noise(img, n, 1.0)


# ---------- shapes ----------

def ridge_silhouette(draw, w, h, base_y, amp, seed, color, alpha=255):
    """Mountain ridge polygon with soft secondary peaks."""
    rnd = random.Random(seed)
    pts = [(0, h)]
    n = 14
    for i in range(n + 1):
        x = w * i / n
        y = (base_y
             - abs(math.sin(i * 1.7 + seed)) * amp
             - math.sin(i * 0.9 + seed * 2.3) * amp * 0.35
             - rnd.random() * amp * 0.12)
        pts.append((x, y))
    pts.append((w, h))
    draw.polygon(pts, fill=color + (alpha,))


def mist_blob(draw, x, y, w, h, color, alpha):
    draw.ellipse([x - w / 2, y - h / 2, x + w / 2, y + h / 2],
                 fill=color + (alpha,))


def save(img, path):
    img.convert("RGB").save(path, "PNG", optimize=True)
    return path
