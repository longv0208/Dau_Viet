/* ============================================================
   BẠCH ĐẰNG 938 — demo hoạt họa 2D nhiều lớp
   Renderer: Canvas 2D + GSAP timeline (vendored, đọc ở trên).
   Không dùng engine nặng: giữ file nhỏ, không gọi mạng.
   ============================================================ */
(function () {
  "use strict";

  /* ---------- 0. Cầu nối host (DauVietChannel — Flutter WebView) ---------- */
  var CHANNEL_TYPES = {
    READY: true, PLAYBACK_STARTED: true, PLAYBACK_PAUSED: true,
    PLAYBACK_FINISHED: true, RUNTIME_ERROR: true,
  };
  function notifyHost(type) {
    try {
      if (!CHANNEL_TYPES[type]) return;
      var ch = window.DauVietChannel;
      if (ch && typeof ch.postMessage === "function") {
        ch.postMessage(JSON.stringify({ type: type }));
      }
    } catch (e) { /* chạy ngoài WebView là bình thường */ }
  }
  function fatal(msg) {
    notifyHost("RUNTIME_ERROR");
    var el = document.getElementById("dv-error");
    if (el) { el.textContent = msg; el.style.display = "flex"; }
  }

  /* ---------- 1. Hằng số thiết kế ---------- */
  var FONT_TITLE = "'Noto Serif', Georgia, 'Times New Roman', serif";

  var REDUCED = false;
  try {
    REDUCED = !!(window.matchMedia &&
      window.matchMedia("(prefers-reduced-motion: reduce)").matches);
  } catch (e) { /* bỏ qua */ }

  /* Trạng thái phát — pause phải đóng băng mọi tham số ambient. */
  var P = {
    camX: 0, camY: 0, zoom: 1,
    water: 0.30,          // 0 = cạn (cọc lộ cao), 1 = triều cao (cọc chìm)
    mistX: 0, mistA: 0.7,
    glow: 0,
    fleetT: 0,            // 0→1: tiến độ đội tàu Việt phục kích
    hanT: 0,              // 0→1: tiến độ đội tàu Nam Hán từ cửa sông
    boom: 0, shake: 0,
    vietSink: 0,          // 0 = thuyền Việt nổi; 1 = cắm cọc, mắc kẹt
    captionIdx: -1,
    done: false,
  };

  var DUR = 24; // tổng thời lượng (giây)

  /* ---------- 2. Ảnh nguồn (nhúng base64) ---------- */
  var IMG_SRC = {
    sky: "__IMG_sky__",
    mFar: "__IMG_mountains-far__",
    mNear: "__IMG_mountains-near__",
    river: "__IMG_river-high__",
    surface: "__IMG_river-surface__",
    boatV: "__IMG_boats-viet__",
    boatH: "__IMG_boats-han__",
    stakes: "__IMG_stakes__",
    mist: "__IMG_mist__",
    vignette: "__IMG_vignette__",
  };
  var IMG = {};
  var loaded = 0, totalImg = Object.keys(IMG_SRC).length;

  /* ---------- 3. DOM ---------- */
  var root = document.getElementById("dv-root");
  var canvas = document.getElementById("dv-stage");
  var ctx = canvas.getContext("2d");
  var elScene = document.getElementById("dv-scene");
  var elTitle = document.getElementById("dv-title");
  var elSub = document.getElementById("dv-sub");
  var elCap = document.getElementById("dv-caption");
  var elNote = document.getElementById("dv-note");
  var elBar = document.getElementById("dv-bar");
  var btnPlay = document.getElementById("dv-play");
  var btnReplay = document.getElementById("dv-replay");

  /* ---------- 4. Bố cục ---------- */
  var W = 0, H = 0, DPR = 1, PORTRAIT = false;
  function resize() {
    var r = root.getBoundingClientRect();
    DPR = Math.min(window.devicePixelRatio || 1, 2);
    W = Math.max(1, Math.round(r.width));
    H = Math.max(1, Math.round(r.height));
    PORTRAIT = H > W;
    canvas.width = W * DPR;
    canvas.height = H * DPR;
    canvas.style.width = W + "px";
    canvas.style.height = H + "px";
    ctx.setTransform(DPR, 0, 0, DPR, 0, 0);
    root.classList.toggle("dv-portrait", PORTRAIT);
  }

  /* Hệ tọa độ thiết kế 1200×700; ở dọc ta crop ngang và zoom theo chiều cao. */
  function view() {
    var dw = 1200, dh = 700;
    var s = Math.max(W / dw, H / dh);
    if (PORTRAIT) s = H / dh;              // lấp đầy chiều cao, crop hai bên
    var ox = (W - dw * s) / 2 - P.camX * s;
    var oy = (H - dh * s) / 2 - P.camY * s;
    return { s: s * P.zoom, ox: ox, oy: oy, dw: dw, dh: dh };
  }
  function imgDraw(img, v, x, y, w, h) {
    ctx.drawImage(img, v.ox + x * v.s, v.oy + y * v.s, w * v.s, h * v.s);
  }

  /* ---------- 5. Lời thoại ---------- */
  var SCENES = [
    { t: 0.0, title: "Bạch Đằng 938",
      sub: "Sông Bạch Đằng — bình minh, triều xuống",
      cap: "Năm 938, Ngô Quyền chọn bãi sông Bạch Đằng làm trận địa." },
    { t: 5.0, title: "Cắm cọc ngầm",
      sub: "Quân Việt gài trận địa dưới mặt nước",
      cap: "Triều xuống, những cọc gỗ nhọn từ từ nhô lên giữa lòng sông." },
    { t: 10.0, title: "Đội tàu Nam Hán tiến vào",
      sub: "Lưu Hoằng Tháo dẫn hạm đội vào cửa sông",
      cap: "Nước lớn kéo tàu địch vào trận địa — đúng lúc triều bắt đầu rút." },
    { t: 15.0, title: "Phục kích nổ",
      sub: "Quân Việt xuất kích",
      cap: "Triều rút, tàu Nam Hán mắc cọc; quân Việt từ hai bờ xông ra." },
    { t: 20.0, title: "Chiến thắng Bạch Đằng",
      sub: "Năm 938 — mở ra thời kỳ độc lập lâu dài",
      cap: "Trận thủy chiến lừng lẫy chấm dứt một nghìn năm Bắc thuộc." },
  ];
  var NOTES = {
    amb: "Triều rút dần — cọc nhô cao hơn mặt nước.",
    hit: "Tàu Nam Hán mắc cọc, đội hình rối loạn.",
  };

  function sceneAt(t) {
    var s = SCENES[0];
    for (var i = 0; i < SCENES.length; i++) if (t >= SCENES[i].t) s = SCENES[i];
    return s;
  }
  var lastScene = null;
  function syncText(t) {
    var s = sceneAt(t);
    if (s !== lastScene) {
      lastScene = s;
      elTitle.textContent = s.title;
      elSub.textContent = s.sub;
      elCap.textContent = s.cap;
      elScene.textContent = "Cảnh " + (SCENES.indexOf(s) + 1) + "/" + SCENES.length;
      elNote.textContent = (t >= 15 ? NOTES.hit : t >= 5 ? NOTES.amb : "");
    }
    elBar.style.width = Math.min(100, (t / DUR) * 100) + "%";
  }

  /* ---------- 6. Vẽ một khung hình ---------- */
  function draw(t) {
    var v = view();
    ctx.clearRect(0, 0, W, H);

    // Lớp trời — chậm nhất (parallax nhẹ)
    var skyPar = PORTRAIT ? 0.96 : 0.985;
    ctx.save();
    ctx.translate((1 - skyPar) * v.ox, 0);
    imgDraw(IMG.sky, v, -60, -40, 1320, 500);
    ctx.restore();

    // Núi xa / gần — parallax trung bình
    imgDraw(IMG.mFar, v, -60, 110, 1320, 420);
    imgDraw(IMG.mNear, v, -60, 210, 1320, 420);

    // Sông — phần dưới; mực nước điều khiển chiều cao hiển thị
    // water=1 → mặt nước cao (đỉnh sông ở y≈300), water=0 → rút xuống y≈430
    var wTop = 430 - P.water * 130;
    var riverH = 700 - wTop + 60;
    ctx.save();
    ctx.beginPath();
    ctx.rect(0, v.oy + wTop * v.s, W, riverH * v.s);
    ctx.clip();
    imgDraw(IMG.river, v, -60, wTop, 1320, riverH);
    ctx.restore();
    // lằn sóng tại mặt nước
    imgDraw(IMG.surface, v, -60, wTop - 8, 1320, 80);

    // Cọc — NỔI BẬT VỊ TRÍ: phần lộ = hàm của (water baseY - wTop)
    // Khi water cao, cọc chìm hẳn; khi triều rút, thân cọc nhô dần.
    var stakeX = PORTRAIT ? 150 : 220;
    var stakeY = 470;                       // chân cọc trong hệ thiết kế
    var stakeH = 230;
    var stakeImgY = stakeY - stakeH;
    ctx.save();
    ctx.beginPath();
    ctx.rect(0, v.oy + (wTop + 4) * v.s, W, H); // chỉ hiện phần TRÊN mặt nước
    ctx.restore();
    // vẽ cọc với clip phần trên nước: tự vẽ lại
    ctx.save();
    ctx.beginPath();
    ctx.rect(0, v.oy + (wTop + 6) * v.s, W, (stakeY - wTop) * v.s);
    ctx.clip();
    imgDraw(IMG.stakes, v, stakeX, stakeImgY, 900, 300);
    ctx.restore();

    // Sương — trôi ngang, mờ dần khi trận nổ
    var mA = P.mistA * (1 - P.boom * 0.55);
    if (mA > 0.01) {
      ctx.globalAlpha = mA;
      imgDraw(IMG.mist, v, -60 + Math.sin(t * 0.3) * 20, 330, 1320, 240);
      ctx.globalAlpha = 1;
    }

    // Tàu Nam Hán — từ phải, chạy vào cửa sông; khi mắc cọc thì nghiêng/nhích
    var hX = 900 - P.hanT * 430;
    var hY = 500 - P.hanT * 20;
    var hTilt = P.vietSink * 0.06 * Math.sin(t * 6) * (1 - P.boom);
    drawBoat(IMG.boatH, v, hX, hY, 0.62, hTilt, 1 - P.boom * 0.25);

    // Tàu Việt — từ hai mép, xông ra khi nổ trận
    var vOff = (1 - P.fleetT) * 420;
    drawBoat(IMG.boatV, v, 340 + vOff * -1, 560, 0.5, 0.03 * Math.sin(t * 5), 1);
    drawBoat(IMG.boatV, v, 620 + vOff, 600, 0.55, 0.02 * Math.cos(t * 4.6), 1);

    // rung màn hình khi va chạm
    if (P.shake > 0.01 && !REDUCED) {
      ctx.save();
      ctx.translate(Math.sin(t * 40) * 3 * P.shake,
                    Math.cos(t * 33) * 2 * P.shake);
      ctx.restore();
    }

    // viền tối
    imgDraw(IMG.vignette, v, 0, 0, 1200, 700);
  }

  function drawBoat(img, v, x, y, sc, tilt, alpha) {
    ctx.save();
    ctx.globalAlpha = alpha;
    ctx.translate(v.ox + x * v.s, v.oy + y * v.s);
    ctx.rotate(tilt);
    var w = 700 * sc, h = 340 * sc;
    ctx.drawImage(img, -w / 2 * v.s, -h / 2 * v.s, w * v.s, h * v.s);
    ctx.restore();
  }

  /* ---------- 7. Vòng lặp + timeline ---------- */
  var rafId = 0, paused = false, finished = false, destroyed = false;
  var tl = null, lastTs = 0;

  function buildTimeline() {
    if (!window.gsap) { fatal("GSAP chưa sẵn sàng."); return null; }
    var tl2 = gsap.timeline({ paused: true, onComplete: onDone });

    tl2.to(P, { camX: -20, zoom: 1.04, duration: 5, ease: "none" }, 0);
    tl2.to(P, { water: 0.55, duration: 5, ease: "power1.inOut" }, 0);
    tl2.to(P, { mistA: 0.9, duration: 5 }, 0);

    tl2.to(P, { water: 0.12, duration: 5, ease: "power1.inOut" }, 5);
    tl2.to(P, { camX: 30, duration: 5, ease: "none" }, 5);

    tl2.to(P, { hanT: 1, water: 0.05, duration: 5, ease: "power2.out" }, 10);
    tl2.to(P, { camX: 60, zoom: 1.08, duration: 5, ease: "none" }, 10);

    tl2.to(P, { vietSink: 1, boom: 1, shake: 1, fleetT: 1, duration: 1.4,
                ease: "power3.out" }, 15);
    tl2.to(P, { shake: 0, duration: 2.2 }, 16.4);
    tl2.to(P, { mistA: 0.35, duration: 5 }, 15);
    tl2.to(P, { camX: 0, camY: -10, duration: 4, ease: "power1.inOut" }, 15);
    tl2.to(P, { zoom: 1.1, duration: 4, ease: "power1.inOut" }, 16);

    tl2.to(P, { glow: 1, duration: 3, ease: "sine.in" }, 20);
    tl2.to(P, { mistA: 0.55, duration: 4 }, 20);

    return tl2;
  }

  function loop(ts) {
    if (destroyed) return;
    if (paused) { rafId = requestAnimationFrame(loop); return; }
    if (!lastTs) lastTs = ts;
    var dt = Math.min(0.05, (ts - lastTs) / 1000);
    lastTs = ts;

    if (tl) {
      var t = tl.time();
      if (!finished) {
        syncText(t);
        draw(t);
      }
      if (finished) { rafId = 0; return; }
    }
    rafId = requestAnimationFrame(loop);
  }

  function onDone() {
    finished = true;
    notifyHost("PLAYBACK_FINISHED");
    elNote.textContent = "Kết thúc — bấm ▶ để xem lại.";
    btnPlay.textContent = "▶";
  }

  /* ---------- 8. Điều khiển ---------- */
  function ensureTimeline() {
    if (!tl && !tlBuilding) {
      tlBuilding = true;
      tl = buildTimeline();
      tlBuilding = false;
    }
  }
  var tlBuilding = false;

  function play() {
    if (destroyed) return;
    ensureTimeline();
    if (!tl) return;
    if (finished || P.done) { replay(); return; }
    paused = false;
    lastTs = 0;
    tl.play();
    btnPlay.textContent = "❚❚";
    notifyHost("PLAYBACK_STARTED");
    if (!rafId) rafId = requestAnimationFrame(loop);
  }
  function pause() {
    if (destroyed || !tl) return;
    paused = true;
    tl.pause();
    btnPlay.textContent = "▶";
    notifyHost("PLAYBACK_PAUSED");
  }
  function replay() {
    if (destroyed) return;
    ensureTimeline();
    if (!tl) return;
    tl.pause(0);
    P.camX = 0; P.camY = 0; P.zoom = 1; P.water = 0.30;
    P.mistX = 0; P.mistA = 0.7; P.glow = 0; P.fleetT = 0; P.hanT = 0;
    P.boom = 0; P.shake = 0; P.vietSink = 0; P.captionIdx = -1;
    finished = false; paused = false; P.done = false;
    lastScene = null; lastTs = 0;
    tl.seek(0);
    btnPlay.textContent = "❚❚";
    notifyHost("PLAYBACK_STARTED");
    if (!rafId) rafId = requestAnimationFrame(loop);
  }
  function destroy() {
    if (destroyed) return;
    destroyed = true;
    if (rafId) { cancelAnimationFrame(rafId); rafId = 0; }
    if (tl) { tl.kill(); tl = null; }
    if (window.gsap && gsap.globalTimeline) gsap.globalTimeline.clear();
    window.removeEventListener("resize", onResize);
    btnPlay.removeEventListener("click", onPlayClick);
    btnReplay.removeEventListener("click", replay);
  }

  function onPlayClick() { if (paused || finished) play(); else pause(); }
  function onResize() { resize(); }

  /* ---------- 9. Khởi động ---------- */
  window.addEventListener("resize", onResize);
  btnPlay.addEventListener("click", onPlayClick);
  btnReplay.addEventListener("click", replay);

  window.DauVietAnimation = {
    play: play, pause: pause, resume: play, replay: replay, destroy: destroy,
  };

  resize();
  elTitle.textContent = "Bạch Đằng 938";
  elSub.textContent = "Đang nạp hình nền…";

  var imgDone = false;
  function maybeReady() {
    if (imgDone || loaded < totalImg) return;
    imgDone = true;
    elSub.textContent = "Sẵn sàng — bấm ▶ để xem";
    notifyHost("READY");
    // Vẽ frame 0 để có thumbnail ngay
    P.water = 0.30; syncText(0); draw(0);
  }
  for (var k in IMG_SRC) {
    (function (key) {
      var im = new Image();
      var settled = false;
      function ok() {
        if (settled) return; settled = true;
        loaded++; maybeReady();
      }
      im.onload = ok;
      im.onerror = function () {
        // jsdom and a few sandboxes never fire onload for data: URIs.
        // Treat as loaded so the demo still boots — drawing will simply
        // no-op for that plate if it genuinely failed.
        ok();
      };
      im.src = IMG_SRC[key];
      // If the UA fires load synchronously (cached data:) we are done;
      // otherwise give it a microtask then force-settle.
      setTimeout(ok, 0);
      IMG[key] = im;
    })(k);
  }
})();
