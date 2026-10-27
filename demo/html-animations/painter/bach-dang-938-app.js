/* ============================================================
   BẠCH ĐẰNG 938 — SIÊU PHẨM HOẠT HỌA THỦY CHIẾN LỊCH SỬ
   Renderer: Canvas 2D + GSAP Timeline (vendored)
   Single-file, self-contained, 60fps dynamic physics & particles.
   ============================================================ */
(function () {
  "use strict";

  /* ---------- 0. Cầu nối Host (DauVietChannel — Flutter WebView) ---------- */
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
    } catch (e) { /* Chạy ngoài WebView là bình thường */ }
  }
  function fatal(msg) {
    notifyHost("RUNTIME_ERROR");
    var el = document.getElementById("dv-error");
    if (el) { el.textContent = msg; el.style.display = "flex"; }
  }

  /* ---------- 1. Thiết lập & Biến trạng thái ---------- */
  var REDUCED = false;
  try {
    REDUCED = !!(window.matchMedia &&
      window.matchMedia("(prefers-reduced-motion: reduce)").matches);
  } catch (e) { /* Bỏ qua */ }

  var DUR = 25; // Tổng thời lượng 25 giây (5 cảnh sử thi)

  /* Tham số trạng thái hoạt họa */
  var P = {
    camX: 0, camY: 0, zoom: 1,
    water: 0.35,          // 1.0 = triều dâng ngập cọc; 0.0 = triều rút kiệt, cọc nhô cao
    tideSpeed: 1.0,       // Tốc độ dòng chảy cuộn xiết
    mistA: 0.75,          // Độ mờ sương sớm
    glow: 0,              // Hào quang chiến thắng
    hanT: 0,              // 0->1: Hạm đội Nam Hán tiến vào; 1->0.7: Dạt lui vì triều rút
    vietLead: 0,          // Tiến độ thuyền nhử địch
    vietTurn: 0,          // 0 = giả thua chạy; 1 = quay mũi quật lại phản công
    vietAmbush: 0,        // Phục binh hai bờ lau sậy xông ra
    impact: 0,            // Thời khắc va chạm cọc ngầm
    brokenShipA: 0,       // Độ hiển thị tàu giặc vỡ toác
    brokenShipY: 0,       // Tàu chìm dần xuống nước
    brokenShipTilt: 0,    // Độ nghiêng lật tàu (đâm cọc thủng đáy)
    splintersT: 0,        // Mảnh vỡ thuyền văng tung tóe trôi nổi
    fireA: 0,             // Khói lửa hỏa công thiêu rụi tàu địch
    arrowsT: 0,           // Mưa tên lửa từ quân Việt
    shake: 0,             // Rung chấn màn hình khi va chạm
    captionIdx: -1,
    done: false,
  };

  /* ---------- 2. Ảnh nguồn (Nhúng Base64 từ bộ art plates) ---------- */
  var IMG_SRC = {
    sky: "__IMG_sky__",
    mFar: "__IMG_mountains-far__",
    mNear: "__IMG_mountains-near__",
    river: "__IMG_river-high__",
    surface: "__IMG_river-surface__",
    reeds: "__IMG_reeds__",
    boatV: "__IMG_boats-viet__",
    boatH: "__IMG_boats-han__",
    boatHBroken: "__IMG_boats-han-broken__",
    stakes: "__IMG_stakes__",
    splinters: "__IMG_splinters__",
    mist: "__IMG_mist__",
    vignette: "__IMG_vignette__",
  };
  var IMG = {};
  var loaded = 0, totalImg = Object.keys(IMG_SRC).length;

  /* ---------- 3. DOM Elements ---------- */
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

  /* ---------- 4. Bố cục & Viewport ---------- */
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

  function lerp(a, b, t) {
    return a + (b - a) * t;
  }

  /* Hệ tọa độ thiết kế chuẩn 1200x700 */
  function view() {
    var dw = 1200, dh = 700;
    var s = Math.max(W / dw, H / dh);
    if (PORTRAIT) s = H / dh;
    var ox = (W - dw * s) / 2 - P.camX * s;
    var oy = (H - dh * s) / 2 - P.camY * s;
    return { s: s * P.zoom, ox: ox, oy: oy, dw: dw, dh: dh };
  }

  function imgDraw(img, v, x, y, w, h) {
    if (!img || !img.complete) return;
    ctx.drawImage(img, v.ox + x * v.s, v.oy + y * v.s, w * v.s, h * v.s);
  }

  /* ---------- 5. Kịch bản lời dẫn lịch sử (5 Cảnh) ---------- */
  var SCENES = [
    {
      t: 0.0,
      title: "Bạch Đằng 938 — Bãi sông hiểm yếu",
      sub: "Cửa sông Bạch Đằng — Bình minh rạng đông",
      cap: "Năm 938, trước họa xâm lăng của quân Nam Hán, Ngô Quyền nghiên cứu quy luật con nước triều, chọn cửa sông Bạch Đằng hiểm trở làm nơi quyết chiến.",
      note: "Sông Bạch Đằng cuồn cuộn sóng, núi non trùng điệp bao bọc cửa biển."
    },
    {
      t: 5.0,
      title: "Cắm cọc ngầm & Dụ địch",
      sub: "Triều dâng ngập trận địa — Thuyền nhẹ ra khiêu chiến",
      cap: "Hàng vạn thân gỗ lim bịt sắt nhọn được cắm nghiêng đón dòng nước. Thủy triều dâng cao nhấn chìm bãi cọc. Thuyền nhẹ quân Việt vượt biển ra khiêu chiến, giả thua nhử địch.",
      note: "Thủy triều lên cực đỉnh, bãi cọc ngầm ẩn mình hoàn toàn dưới lòng sông sâu."
    },
    {
      t: 10.0,
      title: "Hạm đội Nam Hán lọt bẫy",
      sub: "Lưu Hoằng Tháo đắc chí thúc đại quân đuổi sát",
      cap: "Thấy quân ta rút chạy, Lưu Hoằng Tháo đắc chí thúc hạm đội chiến thuyền đồ sộ ồ ạt vượt qua bãi cọc ngầm chìm sâu dưới nước mà không hề hay biết.",
      note: "Chiến hạm giặc kiêu ngạo vượt qua trận địa ngầm trong niềm vui chiến thắng ảo tưởng."
    },
    {
      t: 14.5,
      title: "Triều rút xiết — Thuyền giặc vỡ tan trên cọc",
      sub: "Quân Việt quật lại — Cọc nhọn đâm thủng nát hạm đội giặc",
      cap: "Triều rút mạnh như thác đổ, rừng cọc nhọn hoắt nhô lên! Thuyền Việt quay đầu đánh quật lại dữ dội, phục binh hai bờ lau sậy đổ ra hỏa công. Chiến thuyền địch va cọc vỡ nát, đắm chìm trong biển lửa!",
      note: "Cọc sắt nhọn hoắt xé toạc đáy tàu giặc; cột buồm gãy sập, thuyền vỡ vụn tan tành!"
    },
    {
      t: 20.0,
      title: "Đại thắng Bạch Đằng 938",
      sub: "Chấm dứt 1000 năm Bắc thuộc — Mở ra kỷ nguyên độc lập",
      cap: "Chủ tướng Lưu Hoằng Tháo đền tội, đạo quân xâm lược tan tành. Khúc ca khải hoàn vang dậy non sông, khẳng định nền độc lập tự chủ muôn đời của dân tộc!",
      note: "Trận thủy chiến lừng lẫy thiên thu — Mở ra kỷ nguyên độc lập tự chủ lâu dài."
    },
  ];

  function sceneAt(t) {
    var s = SCENES[0];
    for (var i = 0; i < SCENES.length; i++) {
      if (t >= SCENES[i].t) s = SCENES[i];
    }
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
      elNote.textContent = s.note;
    }
    elBar.style.width = Math.min(100, (t / DUR) * 100) + "%";
  }

  /* ---------- 6. Hệ thống Hạt & Mô phỏng Vật lý (Particles) ---------- */
  // 6.1 Mảnh vỡ gỗ văng ra khi thuyền vỡ (Wood Splinters Explosion)
  var splintersParticles = [];
  function initSplinters(x, y) {
    splintersParticles = [];
    for (var i = 0; i < 45; i++) {
      var angle = Math.random() * Math.PI * 2;
      var speed = 40 + Math.random() * 140;
      splintersParticles.push({
        x: x + (Math.random() - 0.5) * 40,
        y: y + (Math.random() - 0.5) * 20,
        vx: Math.cos(angle) * speed + 30, // Dòng nước xiết cuốn trôi sang phải
        vy: Math.sin(angle) * speed - 50, // Bắn tung lên cao
        rot: Math.random() * 6.28,
        vrot: (Math.random() - 0.5) * 12,
        len: 8 + Math.random() * 22,
        w: 2 + Math.random() * 4,
        life: 1.0,
      });
    }
  }

  // 6.2 Cột nước & bọt sóng tung tóe khi va cọc (Water Splashes)
  var splashParticles = [];
  function spawnSplash(x, y, count, power) {
    for (var i = 0; i < count; i++) {
      var angle = -Math.PI * 0.5 + (Math.random() - 0.5) * 1.2;
      var spd = power * (0.5 + Math.random() * 0.9);
      splashParticles.push({
        x: x + (Math.random() - 0.5) * 30,
        y: y,
        vx: Math.cos(angle) * spd,
        vy: Math.sin(angle) * spd,
        r: 3 + Math.random() * 7,
        alpha: 0.95,
        decay: 0.8 + Math.random() * 0.8,
      });
    }
  }

  // 6.3 Hỏa công: Lửa & khói cuộn trên thuyền giặc (Fire & Smoke)
  var fireParticles = [];
  function updateFire(x, y, intensity, dt) {
    if (intensity <= 0.05) return;
    var count = Math.round(intensity * 14);
    for (var i = 0; i < count; i++) {
      fireParticles.push({
        x: x + (Math.random() - 0.5) * 140,
        y: y + (Math.random() - 0.5) * 25,
        vx: -15 + Math.random() * 30,
        vy: -40 - Math.random() * 70,
        size: 8 + Math.random() * 18,
        life: 1.0,
        decay: 0.9 + Math.random() * 0.8,
        isSmoke: Math.random() < 0.45,
      });
    }
  }

  // 6.4 Mưa tên lửa (Fire Arrows)
  var arrows = [];
  function spawnArrowVolley(t) {
    if (arrows.length > 25) return;
    for (var i = 0; i < 6; i++) {
      arrows.push({
        x: 100 + Math.random() * 250,
        y: 520 + Math.random() * 100,
        targetX: 520 + Math.random() * 180,
        targetY: 460 + Math.random() * 40,
        progress: 0,
        speed: 0.8 + Math.random() * 0.4,
        arcH: 90 + Math.random() * 40,
      });
    }
  }

  /* ---------- 7. Hàm Vẽ Khung Hình (Draw Engine) ---------- */
  function draw(t) {
    var v = view();
    ctx.clearRect(0, 0, W, H);

    // 1. Bầu trời bình minh (Sky + Sunbeams) — Parallax chậm
    var skyPar = PORTRAIT ? 0.96 : 0.985;
    ctx.save();
    ctx.translate((1 - skyPar) * v.ox, 0);
    imgDraw(IMG.sky, v, -60, -40, 1320, 480);
    ctx.restore();

    // 2. Dãy núi đá vôi xa (Distant Karsts)
    imgDraw(IMG.mFar, v, -60, 100, 1320, 380);

    // 3. Sương mù thung lũng xa
    if (P.mistA > 0.01) {
      ctx.save();
      ctx.globalAlpha = P.mistA * 0.65;
      imgDraw(IMG.mist, v, -60 + Math.sin(t * 0.25) * 25, 230, 1320, 220);
      ctx.restore();
    }

    // 4. Dãy núi gần (Near Karsts) — Đỉnh ở y=170..280, chân núi hòa sương ở y=340..380
    imgDraw(IMG.mNear, v, -60, 160, 1320, 400);

    // 5. Mặt nước sông Bạch Đằng (Tidal River)
    // Sông bắt đầu từ y=340 nối liền chân núi trải dài tới y=720 đáy màn hình
    imgDraw(IMG.river, v, -60, 340, 1320, 380);

    // 5.1 Độ cao mặt nước theo thủy triều (Tidal Water Level)
    // Triều cao (P.water = 1.0) -> wLevel = 420 (nước dâng ngập cọc)
    // Triều rút kiệt (P.water = 0.0) -> wLevel = 530 (nước rút lộ cọc nhô cao 100px)
    var wLevel = 420 + (1 - P.water) * 110;

    // 5.2 Dòng nước triều rút chảy xiết cuồn cuộn (Dynamic current foam streaks)
    var currentSpeed = 50 + (1 - P.water) * 140; // Triều rút càng sâu nước chảy càng mạnh
    var streakOffset = (t * currentSpeed) % 300;
    ctx.fillStyle = "rgba(240, 252, 255, 0.26)";
    for (var rk = 0; rk < 28; rk++) {
      var strX = ((rk * 110 + streakOffset) % 1300) - 80;
      var strY = 360 + (rk * 27) % 310;
      var strLen = 60 + ((rk * 37) % 100);
      ctx.fillRect(v.ox + strX * v.s, v.oy + strY * v.s, strLen * v.s, 2.2 * v.s);
    }

    // 6. BÃI CỌC BẠCH ĐẰNG (Menacing Iron-Tipped Stakes)
    // Cọc đặt tại stakeImgY = 410. Đỉnh cọc cao nhất ở y = 430. Chân cọc ở y = 695.
    // NÚI KẾT THÚC Ở Y = 340. CỌC Ở Y = 430..695 -> CỌC HOÀN TOÀN Ở DƯỚI LÒNG SÔNG, KHÔNG CHÈN NÚI!
    var stakeImgY = 410;

    // 6.1 Phần cọc ngập dưới nước (Submerged stakes under river surface)
    ctx.save();
    ctx.globalAlpha = 0.35 + (1 - P.water) * 0.45; // Nước rút làm cọc dưới nước nhìn rõ hơn
    imgDraw(IMG.stakes, v, 0, stakeImgY, 1200, 300);
    ctx.restore();

    // 6.2 Phần cọc NHÔ LÊN KHỎI MẶT NƯỚC khi triều rút (Exposed lethal iron tips)
    // Khi wLevel > 430, phần từ đỉnh cọc (y=430) đến mặt nước wLevel nhô lên trên không khí!
    if (wLevel > 430) {
      ctx.save();
      ctx.beginPath();
      ctx.rect(0, v.oy + 400 * v.s, W, (wLevel - 400) * v.s);
      ctx.clip();
      imgDraw(IMG.stakes, v, 0, stakeImgY, 1200, 300);
      ctx.restore();

      // Bọt sóng xé dòng quanh chân cọc tại ngấn nước wLevel
      ctx.fillStyle = "rgba(255, 255, 255, 0.45)";
      for (var si = 0; si < 24; si++) {
        var skx = 70 + si * 46;
        var rAmp = 3 + Math.sin(t * 10 + si) * 2;
        ctx.beginPath();
        ctx.ellipse(v.ox + skx * v.s, v.oy + wLevel * v.s, (12 + rAmp) * v.s, 3.5 * v.s, 0, 0, Math.PI * 2);
        ctx.fill();
      }
    }

    // 6.3 Lằn sóng động tại ngấn nước (Wavelet waterline)
    imgDraw(IMG.surface, v, -60, wLevel - 8, 1320, 70);

    // 7. Mảnh vỡ thuyền chiến & Thùng gỗ, khiên trôi dạt (Splinters & Debris)
    if (P.splintersT > 0.05) {
      var dX = 520 + (t * 22) % 300;
      var dY = wLevel + 30 + Math.sin(t * 4) * 8;
      ctx.save();
      ctx.globalAlpha = Math.min(1.0, P.splintersT * 1.2);
      imgDraw(IMG.splinters, v, dX - 100, dY, 600, 200);
      ctx.restore();
    }

    // 8. TÀU CHIẾN NAM HÁN (Southern Han Fleet)
    // Tọa độ kỳ hạm:
    // t=10..14.5: Tiến sâu vào sông từ 980 về 600 (hào hùng truy kích)
    // t=14.5..17: Triều rút xiết, tàu bị quật lui đâm thẳng vào cọc ở x≈580, y≈480!
    var hX = 980 - P.hanT * 400;
    var hY = 475 + (1 - P.water) * 15; // Nước rút kéo thuyền hạ thấp

    // 8.1 Thuyền tiền tiêu phụ của giặc ở phía xa (Distant escort ship)
    var escX = hX + 160;
    var escY = hY - 45;
    var escTilt = P.brokenShipTilt * 0.6;
    drawBoat(IMG.boatH, v, escX, escY, 0.38, escTilt, 0.85);

    // 8.2 Kỳ hạm Lưu Hoằng Tháo:
    // Khi P.impact < 0.1: Thuyền nguyên vẹn kiêu ngạo
    // Khi P.impact >= 0.1: Thuyền VỠ VỤN, CỌC ĐÂM THỦNG TOÁC, CỘT BUỒM GÃY, NGHIÊNG ĐẮM!
    if (P.brokenShipA < 0.95) {
      var intactTilt = (1 - P.brokenShipA) * 0.04 * Math.sin(t * 6);
      drawBoat(IMG.boatH, v, hX, hY, 0.72, intactTilt, 1.0 - P.brokenShipA);
    }
    if (P.brokenShipA > 0.05) {
      // Tàu vỡ toác đâm cọc: Nghiêng lật, chúc mũi, chìm dần
      var brokeTilt = P.brokenShipTilt + 0.02 * Math.sin(t * 8);
      var brokeY = hY + P.brokenShipY;
      drawBoat(IMG.boatHBroken, v, hX, brokeY, 0.76, brokeTilt, P.brokenShipA);

      // Cột nước phun trào từ lỗ thủng đáy tàu
      if (P.impact > 0.3 && P.water < 0.5) {
        spawnSplash(hX + 10, hY + 25, 3, 75);
      }
    }

    // 9. THUYỀN CHIẾN NGÔ QUYỀN (Dai Viet Fleet)
    // 9.1 Thuyền nhẹ tiên phong nhử địch (Vanguard lure boat)
    // Lúc đầu giả thua chạy về bên trái; t=15s quay ngoắt 180 độ đánh quật lại!
    var vLeadX = 420 - (1 - P.vietLead) * 280;
    var vLeadY = 510 + Math.sin(t * 5.2) * 6;
    var vLeadFlip = P.vietTurn > 0.5; // quat lai phan cong: Mui huong sang phai!
    ctx.save();
    ctx.translate(v.ox + vLeadX * v.s, v.oy + vLeadY * v.s);
    if (!vLeadFlip) {
      ctx.scale(-1, 1); // Đang giả thua rút chạy về bên trái
    }
    var vLw = 700 * 0.52, vLh = 340 * 0.52;
    ctx.drawImage(IMG.boatV, -vLw / 2 * v.s, -vLh / 2 * v.s, vLw * v.s, vLh * v.s);
    ctx.restore();

    // 9.2 Đại đội thuyền chiến chủ lực mai phục hai bên bờ xông ra áp sát
    // Thuyền chiến bên trái xông ra kẹp sườn
    var amb1X = -120 + P.vietAmbush * 360;
    var amb1Y = 560 + Math.cos(t * 4.8) * 8;
    drawBoat(IMG.boatV, v, amb1X, amb1Y, 0.68, 0.02 * Math.sin(t * 5), 1.0);

    // Thuyền chiến thứ hai đón đầu cửa biển
    var amb2X = 1040 - P.vietAmbush * 300;
    var amb2Y = 600 + Math.sin(t * 4.5) * 8;
    ctx.save();
    ctx.translate(v.ox + amb2X * v.s, v.oy + amb2Y * v.s);
    ctx.scale(-1, 1); // Mũi quay sang trái bao vây
    var v2w = 700 * 0.72, v2h = 340 * 0.72;
    ctx.drawImage(IMG.boatV, -v2w / 2 * v.s, -v2h / 2 * v.s, v2w * v.s, v2h * v.s);
    ctx.restore();

    // 10. MƯA TÊN LỬA HỎA CÔNG (Flaming Arrows)
    if (P.arrowsT > 0.1) {
      if (Math.random() < 0.35) spawnArrowVolley(t);
      ctx.save();
      for (var ai = arrows.length - 1; ai >= 0; ai--) {
        var arr = arrows[ai];
        arr.progress += 0.028 * arr.speed;
        if (arr.progress >= 1.0) {
          // Bắn trúng tàu địch -> Tạo lửa bùng lên
          spawnSplash(arr.targetX, arr.targetY, 4, 35);
          arrows.splice(ai, 1);
          continue;
        }
        var currX = lerp(arr.x, arr.targetX, arr.progress);
        var currY = lerp(arr.y, arr.targetY, arr.progress) - Math.sin(arr.progress * Math.PI) * arr.arcH;

        // Vệt lửa đuôi tên
        ctx.strokeStyle = "rgba(255, 120, 20, 0.85)";
        ctx.lineWidth = 3.5 * v.s;
        ctx.beginPath();
        ctx.moveTo(v.ox + currX * v.s, v.oy + currY * v.s);
        ctx.lineTo(v.ox + (currX - 18) * v.s, v.oy + (currY + 8) * v.s);
        ctx.stroke();

        // Đầu lửa rực sáng
        ctx.fillStyle = "#fff2a0";
        ctx.beginPath();
        ctx.arc(v.ox + currX * v.s, v.oy + currY * v.s, 3.5 * v.s, 0, Math.PI * 2);
        ctx.fill();
      }
      ctx.restore();
    }

    // 11. HỎA CÔNG: LỬA & KHÓI THIÊU RỤI TÀU ĐỊCH (Fire & Smoke Simulation)
    if (P.fireA > 0.05) {
      updateFire(hX + 15, hY - 15, P.fireA, 0.016);
      ctx.save();
      for (var fi = fireParticles.length - 1; fi >= 0; fi--) {
        var fp = fireParticles[fi];
        fp.x += fp.vx * 0.016;
        fp.y += fp.vy * 0.016;
        fp.life -= fp.decay * 0.016;
        if (fp.life <= 0) {
          fireParticles.splice(fi, 1);
          continue;
        }
        if (fp.isSmoke) {
          // Khói đen bốc ngùn ngụt
          var sAlpha = fp.life * 0.45 * P.fireA;
          ctx.fillStyle = "rgba(35, 30, 28, " + sAlpha + ")";
          ctx.beginPath();
          ctx.arc(v.ox + fp.x * v.s, v.oy + fp.y * v.s, fp.size * (1.8 - fp.life) * v.s, 0, Math.PI * 2);
          ctx.fill();
        } else {
          // Ngọn lửa rực sáng vàng cam
          var fAlpha = fp.life * 0.85 * P.fireA;
          var fGrad = ctx.createRadialGradient(
            v.ox + fp.x * v.s, v.oy + fp.y * v.s, 0,
            v.ox + fp.x * v.s, v.oy + fp.y * v.s, fp.size * v.s
          );
          fGrad.addColorStop(0, "rgba(255, 250, 180, " + fAlpha + ")");
          fGrad.addColorStop(0.4, "rgba(255, 140, 20, " + (fAlpha * 0.8) + ")");
          fGrad.addColorStop(1, "rgba(200, 30, 10, 0)");
          ctx.fillStyle = fGrad;
          ctx.beginPath();
          ctx.arc(v.ox + fp.x * v.s, v.oy + fp.y * v.s, fp.size * v.s, 0, Math.PI * 2);
          ctx.fill();
        }
      }
      ctx.restore();
    }

    // 12. MẢNH VỠ GỖ BAY TUNG TÓE KHI ĐÂM CỌC (Splinters Physics)
    if (splintersParticles.length > 0) {
      ctx.save();
      for (var pi = splintersParticles.length - 1; pi >= 0; pi--) {
        var sp = splintersParticles[pi];
        sp.x += sp.vx * 0.016;
        sp.y += sp.vy * 0.016;
        sp.vy += 120 * 0.016; // Trọng lực rơi xuống nước
        sp.rot += sp.vrot * 0.016;
        sp.life -= 0.012;
        if (sp.life <= 0 || sp.y > 680) {
          splintersParticles.splice(pi, 1);
          continue;
        }
        ctx.save();
        ctx.translate(v.ox + sp.x * v.s, v.oy + sp.y * v.s);
        ctx.rotate(sp.rot);
        ctx.fillStyle = "rgba(145, 95, 45, " + (sp.life * 0.95) + ")";
        ctx.fillRect(-sp.len / 2 * v.s, -sp.w / 2 * v.s, sp.len * v.s, sp.w * v.s);
        ctx.restore();
      }
      ctx.restore();
    }

    // 13. BỌT NƯỚC BẮN TUNG TÓE (Water Splash Particles)
    if (splashParticles.length > 0) {
      ctx.save();
      ctx.fillStyle = "rgba(250, 254, 255, 0.8)";
      for (var si2 = splashParticles.length - 1; si2 >= 0; si2--) {
        var spl = splashParticles[si2];
        spl.x += spl.vx * 0.016;
        spl.y += spl.vy * 0.016;
        spl.vy += 140 * 0.016; // Rơi xuống
        spl.alpha -= spl.decay * 0.016;
        if (spl.alpha <= 0) {
          splashParticles.splice(si2, 1);
          continue;
        }
        ctx.beginPath();
        ctx.arc(v.ox + spl.x * v.s, v.oy + spl.y * v.s, spl.r * v.s, 0, Math.PI * 2);
        ctx.fill();
      }
      ctx.restore();
    }

    // 14. BÃI LAU SẬY MAI PHỤC VEN SÔNG (Foreground Reeds)
    imgDraw(IMG.reeds, v, -40, 500, 1280, 220);

    // 15. RUNG CHẤN MÀN HÌNH KHI VA CHẠM (Screen Shake)
    if (P.shake > 0.01 && !REDUCED) {
      ctx.save();
      var shkX = Math.sin(t * 50) * 8 * P.shake;
      var shkY = Math.cos(t * 42) * 6 * P.shake;
      ctx.translate(shkX, shkY);
      ctx.restore();
    }

    // 16. HÀO QUANG CHIẾN THẮNG & ÁNH BÌNH MINH KHẢI HOÀN
    if (P.glow > 0.05) {
      ctx.save();
      var glowGrad = ctx.createRadialGradient(
        v.ox + 900 * v.s, v.oy + 280 * v.s, 0,
        v.ox + 900 * v.s, v.oy + 280 * v.s, 800 * v.s
      );
      glowGrad.addColorStop(0, "rgba(255, 230, 140, " + (P.glow * 0.45) + ")");
      glowGrad.addColorStop(0.5, "rgba(255, 170, 60, " + (P.glow * 0.25) + ")");
      glowGrad.addColorStop(1, "rgba(255, 150, 40, 0)");
      ctx.fillStyle = glowGrad;
      ctx.fillRect(0, 0, W, H);
      ctx.restore();
    }

    // 17. VIỀN TỐI ĐIỆN ẢNH (Cinematic Vignette)
    imgDraw(IMG.vignette, v, 0, 0, 1200, 700);
  }

  function drawBoat(img, v, x, y, sc, tilt, alpha) {
    if (!img || !img.complete || alpha <= 0.01) return;
    ctx.save();
    ctx.globalAlpha = Math.max(0, Math.min(1, alpha));
    ctx.translate(v.ox + x * v.s, v.oy + y * v.s);
    ctx.rotate(tilt);
    var w = 700 * sc, h = 340 * sc;
    ctx.drawImage(img, -w / 2 * v.s, -h / 2 * v.s, w * v.s, h * v.s);
    ctx.restore();
  }

  /* ---------- 8. Vòng Lặp Hoạt Họa & GSAP Timeline ---------- */
  var rAF = typeof window !== "undefined" && window.requestAnimationFrame ?
    window.requestAnimationFrame.bind(window) : function (cb) { return setTimeout(cb, 16); };
  var cAF = typeof window !== "undefined" && window.cancelAnimationFrame ?
    window.cancelAnimationFrame.bind(window) : clearTimeout;

  var rafId = 0, paused = false, finished = false, destroyed = false, started = false;
  var tl = null, lastTs = 0;

  function buildTimeline() {
    if (!window.gsap) { fatal("GSAP chưa sẵn sàng."); return null; }
    var tl2 = gsap.timeline({ paused: true, onComplete: onDone });

    // CẢNH 1: BẠCH ĐẰNG 938 — BÃI SÔNG HIỂM YẾU (0 -> 5s)
    tl2.to(P, { camX: -30, camY: 0, zoom: 1.03, duration: 5, ease: "sine.inOut" }, 0);
    tl2.to(P, { water: 0.35, duration: 5 }, 0);
    tl2.to(P, { mistA: 0.85, duration: 5 }, 0);
    tl2.to(P, { vietLead: 0.3, duration: 5, ease: "none" }, 0);

    // CẢNH 2: CẮM CỌC NGẦM & DỤ ĐỊCH (5 -> 10s)
    // Thủy triều dâng ngập hoàn toàn bãi cọc (water: 0.85)
    tl2.to(P, { water: 0.85, duration: 5, ease: "power1.inOut" }, 5);
    tl2.to(P, { camX: 40, zoom: 1.06, duration: 5, ease: "sine.inOut" }, 5);
    tl2.to(P, { vietLead: 0.75, duration: 5, ease: "none" }, 5);

    // CẢNH 3: HẠM ĐỘI NAM HÁN LỌT BẪY (10 -> 14.5s)
    // Hạm đội giặc tiến sâu vào sông, đắc thắng vượt qua bãi cọc
    tl2.to(P, { hanT: 0.95, duration: 4.5, ease: "power1.out" }, 10);
    tl2.to(P, { camX: 80, zoom: 1.08, duration: 4.5, ease: "sine.inOut" }, 10);
    tl2.to(P, { vietLead: 1.0, duration: 4.5, ease: "none" }, 10);

    // CẢNH 4: THỦY TRIỀU RÚT XIẾT — THUYỀN GIẶC VỠ TAN TRÊN CỌC (14.5 -> 20s)
    // 14.5s: Triều rút cực mạnh (water: 0.85 -> 0.05), rừng cọc nhọn hoắt trồi lên!
    tl2.to(P, { water: 0.05, duration: 3.5, ease: "power2.inOut" }, 14.5);
    // Dòng nước rút cuộn xiết kéo lùi tàu giặc vào bãi cọc
    tl2.to(P, { hanT: 0.65, duration: 3.5, ease: "power1.inOut" }, 14.5);
    // Thuyền Việt quay mũi đánh quật lại!
    tl2.to(P, { vietTurn: 1.0, duration: 0.8, ease: "power2.out" }, 14.6);
    // Phục binh hai bờ lau sậy đổ ra kẹp chặt
    tl2.to(P, { vietAmbush: 1.0, duration: 4.0, ease: "power2.out" }, 14.8);

    // 15.2s: THỜI KHẮC VA CHẠM KINH HOÀNG — CỌC ĐÂM THỦNG TOÁC ĐÁY, THUYỀN VỠ VỤN!
    tl2.call(function () {
      initSplinters(580, 480);
      spawnSplash(580, 480, 30, 110);
    }, null, 15.2);

    tl2.to(P, { impact: 1.0, duration: 0.2 }, 15.2);
    tl2.to(P, { shake: 1.0, duration: 0.4, ease: "power4.out" }, 15.2);
    tl2.to(P, { shake: 0.0, duration: 2.8, ease: "power2.out" }, 15.6);

    // Chuyển sang hiển thị thuyền vỡ toác, nghiêng 30 độ, chìm dần
    tl2.to(P, { brokenShipA: 1.0, duration: 0.5, ease: "power2.in" }, 15.1);
    tl2.to(P, { brokenShipTilt: 0.42, duration: 2.5, ease: "power2.out" }, 15.2);
    tl2.to(P, { brokenShipY: 28, duration: 4.0, ease: "power1.inOut" }, 15.2);

    // Mảnh vỡ trôi lềnh bềnh trên mặt nước
    tl2.to(P, { splintersT: 1.0, duration: 2.0 }, 15.2);

    // Mưa tên lửa hỏa công
    tl2.to(P, { arrowsT: 1.0, duration: 1.0 }, 15.4);

    // Khói lửa bùng cháy dữ dội thiêu rụi thuyền giặc
    tl2.to(P, { fireA: 1.0, duration: 2.5, ease: "power2.out" }, 15.6);

    // Camera zoom cận cảnh vụ đắm tàu kinh hoàng
    tl2.to(P, { camX: 40, camY: -15, zoom: 1.15, duration: 3.5, ease: "power2.inOut" }, 15.2);

    // CẢNH 5: ĐẠI THẮNG BẠCH ĐẰNG 938 (20 -> 25s)
    tl2.to(P, { glow: 1.0, duration: 4.0, ease: "sine.inOut" }, 20.0);
    tl2.to(P, { camX: 0, camY: 0, zoom: 1.04, duration: 5.0, ease: "power2.inOut" }, 20.0);
    tl2.to(P, { mistA: 0.45, duration: 4.0 }, 20.0);
    tl2.to(P, { fireA: 0.65, duration: 5.0 }, 20.0);

    return tl2;
  }

  function loop(ts) {
    if (destroyed) return;
    if (paused) { rafId = rAF(loop); return; }
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
    rafId = rAF(loop);
  }

  function onDone() {
    finished = true;
    notifyHost("PLAYBACK_FINISHED");
    elNote.textContent = "Hoạt họa kết thúc — Bấm ↻ để xem lại.";
    btnPlay.textContent = "▶";
  }

  /* ---------- 9. Điều Khiển Phát & Vòng Đời ---------- */
  var tlBuilding = false;
  function ensureTimeline() {
    if (!tl && !tlBuilding) {
      tlBuilding = true;
      tl = buildTimeline();
      tlBuilding = false;
    }
  }

  function play() {
    if (destroyed) return;
    ensureTimeline();
    if (!tl) return;
    if (finished || P.done) { replay(); return; }
    paused = false; started = true;
    lastTs = 0;
    tl.play();
    btnPlay.textContent = "❚❚";
    notifyHost("PLAYBACK_STARTED");
    if (!rafId) rafId = rAF(loop);
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
    P.camX = 0; P.camY = 0; P.zoom = 1; P.water = 0.35;
    P.tideSpeed = 1.0; P.mistA = 0.75; P.glow = 0;
    P.hanT = 0; P.vietLead = 0; P.vietTurn = 0; P.vietAmbush = 0;
    P.impact = 0; P.brokenShipA = 0; P.brokenShipY = 0; P.brokenShipTilt = 0;
    P.splintersT = 0; P.fireA = 0; P.arrowsT = 0; P.shake = 0;
    finished = false; paused = false; P.done = false; started = true;
    lastScene = null; lastTs = 0;
    splintersParticles = [];
    splashParticles = [];
    fireParticles = [];
    arrows = [];
    tl.seek(0);
    btnPlay.textContent = "❚❚";
    notifyHost("PLAYBACK_STARTED");
    if (!rafId) rafId = rAF(loop);
  }

  function destroy() {
    if (destroyed) return;
    destroyed = true;
    if (rafId) { cAF(rafId); rafId = 0; }
    if (tl) { tl.kill(); tl = null; }
    if (window.gsap && gsap.globalTimeline) gsap.globalTimeline.clear();
    window.removeEventListener("resize", onResize);
    btnPlay.removeEventListener("click", onPlayClick);
    btnReplay.removeEventListener("click", replay);
  }

  function onPlayClick() {
    if (!started || paused || finished) play();
    else pause();
  }

  function onResize() {
    resize();
    if (!started && loaded >= totalImg) {
      draw(0);
    }
  }

  /* ---------- 10. Khởi Động ---------- */
  window.addEventListener("resize", onResize);
  btnPlay.addEventListener("click", onPlayClick);
  btnReplay.addEventListener("click", replay);
  canvas.addEventListener("click", onPlayClick);

  window.DauVietAnimation = {
    play: play, pause: pause, resume: play, replay: replay, destroy: destroy,
  };

  resize();
  elTitle.textContent = "Bạch Đằng 938";
  elSub.textContent = "Đang nạp hình nền sử thi…";

  var imgDone = false;
  function maybeReady() {
    if (imgDone || loaded < totalImg) return;
    imgDone = true;
    elSub.textContent = "Sẵn sàng — Bấm ▶ để theo dõi trận chiến!";
    notifyHost("READY");
    P.water = 0.35;
    syncText(0);
    draw(0);
  }

  for (var k in IMG_SRC) {
    (function (key) {
      var im = new Image();
      var settled = false;
      function ok() {
        if (settled) return;
        settled = true;
        loaded++;
        maybeReady();
      }
      im.onload = ok;
      im.onerror = function () {
        ok();
      };
      im.src = IMG_SRC[key];
      setTimeout(ok, 0);
      IMG[key] = im;
    })(k);
  }
})();
