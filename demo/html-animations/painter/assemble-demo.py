# -*- coding: utf-8 -*-
"""Assemble bach-dang-938-demo.html — UTF-8 throughout, no BOM surprises."""
import base64
import os
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
ART = os.path.join(ROOT, "..", "art")
OUT = os.path.join(ROOT, "..", "bach-dang-938-demo.html")
GSAP = os.path.join(os.environ.get("TEMP", ""), "anim-libs", "package", "dist", "gsap.min.js")
CSS = os.path.join(ROOT, "bach-dang-938-styles.css")
APP = os.path.join(ROOT, "bach-dang-938-app.js")

PLATES = {
    "sky": "sky-dawn.png",
    "mountains-far": "mountains-far.png",
    "mountains-near": "mountains-near.png",
    "river-high": "river-high.png",
    "river-surface": "river-surface.png",
    "boats-viet": "boats-viet.png",
    "boats-han": "boats-han.png",
    "stakes": "stakes.png",
    "mist": "mist.png",
    "vignette": "vignette.png",
}


def read(p):
    with open(p, "r", encoding="utf-8") as f:
        return f.read()


def main():
    gsap = read(GSAP)
    css = read(CSS)
    app = read(APP)

    for key, fname in PLATES.items():
        path = os.path.join(ART, fname)
        if not os.path.exists(path):
            raise SystemExit("missing plate " + path)
        with open(path, "rb") as f:
            b64 = base64.b64encode(f.read()).decode("ascii")
        app = app.replace("__IMG_" + key + "__", "data:image/png;base64," + b64)

    if "__IMG_" in app:
        raise SystemExit("unsubstituted image token remains")

    html = """<!doctype html>
<html lang="vi">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>Bạch Đằng 938 — demo hoạt họa</title>
<style>
{css}
</style>
</head>
<body>
<div id="dv-root">
  <canvas id="dv-stage"></canvas>

  <div class="dv-hud">
    <div id="dv-scene">Cảnh 1/5</div>
    <div id="dv-title">Bạch Đằng 938</div>
    <div id="dv-sub">Sông Bạch Đằng — bình minh, triều xuống</div>
  </div>

  <div class="dv-cap-wrap">
    <div id="dv-caption">Năm 938, Ngô Quyền chọn bãi sông Bạch Đằng làm trận địa.</div>
    <div id="dv-note"></div>
    <div id="dv-track"><div id="dv-bar"></div></div>
  </div>

  <div class="dv-ctl">
    <button id="dv-play"  type="button" aria-label="Phát / tạm dừng">▶</button>
    <button id="dv-replay" type="button" aria-label="Xem lại">↻</button>
  </div>

  <div id="dv-error" role="alert"></div>
</div>

<script>
{gsap}
</script>
<script>
{app}
</script>
</body>
</html>
""".format(css=css, gsap=gsap, app=app)

    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(html)
    print("wrote", os.path.getsize(OUT), "->", OUT)


if __name__ == "__main__":
    main()
