# Huong dan tao va dang tai hoat hoa HTML (HTML_WEBVIEW)

Tai lieu danh cho doi dung noi dung va admin — khong can biet lap trinh he thong.
Muc tieu: mot file `.html` duy nhat, tu chua toan bo, keo-tha vao Admin la xong.

## 1. Luong tong quat

```
Tao file .html tren may   →   Admin > Thu vien hoat hoa > "Tai hoat hoa HTML len"
        ↓
He thong tu tao scene loai HTML_WEBVIEW + kiem tra file
        ↓
Xem truoc ngay trong man hinh chinh sua (iframe sandbox — an toan)
        ↓
"Phat hanh" (Publish) → ban immutable → chon trong Lesson Builder
        ↓
Hoc vien mo bai hoc tren app → WebView hien thi dung file da phat hanh
```

Mot scene HTML co the dung lai o nhieu bai hoc. Khi can sua noi dung,
tai file moi vao scene va phat hanh version moi — bai hoc cu van giu
version cu (khong bi thay doi giua chung).

## 2. Quy tac cho file .html (QUAN TRONG)

File phai TU CHUA TOAN BO — mot file duy nhat:

- Dung dung: HTML + CSS + JS viet truc tiep trong file; hinh anh/audio/font
  nhu `data:` URI (base64) hoac SVG inline.
- Encoding UTF-8, dung luong toi da khoang 15 MB.
- Ten file nen viet thuong, khong dau, khong khoang trang
  (vd: `bach-dang-938.html`).

### Nhung gi se BI TU CHOI khi tai len

He thong tu dong quet va tu choi neu file co:

| Vi pham | Vi du bi chan |
|---|---|
| Tai script tu internet | `<script src="https://...">` |
| Tai CSS tu internet | `<link href="https://...">` |
| Tai anh/font/media tu internet hoac file roi | `<img src="https://...">`, `<img src="./img.png">`, `url(...)` ngoai `data:` |
| Goi mang tu JS | `fetch(...)`, `XMLHttpRequest`, `import(...)`, `axios`, `WebSocket`, `EventSource`, `navigator.sendBeacon` |
| Mo popup / dieu huong | `window.open`, `<form>` submit ra ngoai, `<meta http-equiv="refresh">` |
| Tai noi dung iframe ngoai | `<iframe src="https://...">` |

Khi bi tu choi, thong bao loi hien thi DONG loi va doan noi dung vi pham —
sua dung dong do roi tai lai.

### Vi du hop le / khong hop le

Hop le:

```html
<!doctype html>
<html lang="vi">
<head>
<meta charset="utf-8">
<style>
  body { margin:0; background:#f5ecd7; }
  canvas { width:100%; height:100%; display:block; }
</style>
</head>
<body>
<canvas id="scene"></canvas>
<script>
  // Toan bo logic nam trong file — khong fetch, khong CDN.
  const cv = document.getElementById('scene');
  // ... ve hoat hoa ...
</script>
</body>
</html>
```

Khong hop le (bi tu choi):

```html
<script src="https://cdn.jsdelivr.net/npm/gsap@3/dist/gsap.min.js"></script>
<img src="map.png">            <!-- file roi, khong phai data URI -->
<script>fetch('/api/x')</script>
```

### Gom thu vien vao file

Neu can GSAP/PixiJS/... tai file `.min.js` ve, mo bang trinh soan thao,
chep TOAN BO noi dung vao the `<script>` trong file HTML:

```html
<script>
/* ! gsap 3.12.5 — toan bo ma nguon dan vao day */
</script>
<script>
  // code cua ban, dung gsap nhu bien toan cuc
</script>
```

Anh PNG/JPG/WAV nho: chuyen sang base64 (`data:image/png;base64,...`)
bang cong cu nhu base64-image.de, hoac dung SVG inline cho do hoa.

## 3. Tuong tac voi app (TUY CHON — khong bat buoc)

File HTML van chay binh thuong neu khong cai gi them. Neu muon dong bo
voi player cua app, co hai co che:

### 3.1. App goi vao HTML — `window.DauVietAnimation`

Neu file dinh nghia doi tuong nay, app co the goi:

```js
window.DauVietAnimation = {
  play:    function(){ /* bat dau chay */ },
  pause:   function(){ /* tam dung */ },
  resume:  function(){ /* tiep tuc */ },
  replay:  function(){ /* chay lai tu dau */ },
  destroy: function(){ /* don dep khi roi man hinh */ }
};
```

Tat ca ham deu TUY CHON — cai ham nao app goi ham do, thieu cung khong sao.

### 3.2. HTML bao cho app — `DauVietChannel.postMessage`

HTML co the gui tin cho app qua kenh `DauVietChannel`. CHI cac ten sau
duoc chap nhan (ten khac bi bo qua):

- `READY` — file da san sang hien thi
- `PLAYBACK_STARTED` — hoat hoa bat dau chay
- `PLAYBACK_PAUSED` — hoat hoa tam dung
- `PLAYBACK_FINISHED` — hoat hoa chay xong (app co the danh dau da xem)
- `RUNTIME_ERROR` — file tu bao loi luc chay

```js
// Dang chuoi don gian
DauVietChannel.postMessage('PLAYBACK_FINISHED');

// hoac dang object — chi truong "type" duoc doc
DauVietChannel.postMessage(JSON.stringify({ type: 'READY' }));
```

### 3.3. Nhung gi HTML KHONG duoc / khong can lam

- KHONG gui diem, EXP, ket qua, hay danh dau hoan thanh bai hoc —
  server tu quyet dinh, message ngoai whitelist bi bo qua.
- KHONG doc thong tin tai khoan, token, cookie — file chay trong
  sandbox khong co quyen truy cap.
- KHONG dieu huong sang trang khac — moi link/redirect deu bi chan.

## 4. Quy trinh tren Admin

1. Vao `Thu vien hoat hoa` (Animation Library).
2. Bam `Tai hoat hoa HTML len`, keo file `.html` vao vung tha (hoac bam
   de chon file). Dat ten scene neu can.
3. Neu file hop le → he thong tao scene `Hoat hoa HTML` va mo man hinh
   chinh sua. Cot phai la khung xem truoc: chon kich thuoc khung
   (dien thoai / tablet / desktop) de kiem tra bo cuc.
4. Muon thay file khac: keo file moi vao vung "Tep HTML" → xem truoc
   cap nhat ngay (ban nhap, chua anh huong hoc vien).
5. Bam `Phat hanh` de tao version bat bien. Sau phat hanh, file cua
   version do KHONG the sua — muon doi phai phat hanh version moi.
6. Vao Lesson Builder, them activity dang animation va chon scene vua
   phat hanh (hien nhan "Hoat hoa HTML").

## 5. Cau hoi thuong gap

- File to qua 15 MB? Giam anh (webp/png nen lai), bo font thua,
  hoac chia thanh 2 scene.
- Loi "external reference" nhung minh khong thay? Tim `http`, `src=`,
  `url(`, `fetch`, `import(` trong file — ke ca trong binh luan JS.
- Xem truoc trang tron? Thu mo truc tiep file trong Chrome — neu cung
  trang thi loi nam trong file (sai data URI, JS exception luc khoi dong).
- Hoc vien can mang khong? Chi can mang luc TAI noi dung bai hoc lan
  dau; ban than file HTML khong goi mang trong luc chay.
- Do phan giai? File chay trong khung ti le ~16:10; nen thiet ke
  responsive theo chieu ngang (media query hoac canvas scale theo
  `clientWidth`).

## 6. Tham chieu ky thuat (cho dev)

- Renderer code: `HTML_WEBVIEW`, template: `html-webview`.
- Draft manifest: `html{filename,sizeBytes,sha256}` — metadata do SERVER
  so huu, derive tu `animation_scene_html`; PATCH draft_json khong the
  gia checksum (re-derive), publish re-hash bytes va tu choi mismatch.
- Sandbox: `HtmlSandbox.apply()` chen `<meta http-equiv="Content-
  Security-Policy">` vao chinh stored bytes (response header khong ton
  tai qua `loadHtmlString`/blob URL) — CSP: `default-src 'none'`,
  `script/style 'unsafe-inline'`, `img/media/font data:`,
  `connect-src 'none'`, `frame-src/object-src 'none'`.
- Publish: copy sang `animation_scene_version_html` (immutable, trigger);
  sha256/sizeBytes pin vao manifest phai khop stored bytes.
- Learner endpoint: `GET /api/v1/animation-versions/{versionId}/html`.
- Admin upload: `POST /api/upload/html-scene` (BFF multipart, cap 18 MB),
  `PUT /api/upload/html-scene/{id}` (replace draft).
- Flutter: `HtmlAnimationPlayer` — fetch Bearer qua `withAuth`
  (refresh 1 lan) → verify sha256 → `loadHtmlString(baseUrl:
  about:blank)`, prevent moi navigation, JS channel whitelist 5 message
  o muc 3.2, generation guard chong stale response.
