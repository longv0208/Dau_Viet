# Báo cáo rebuild — Bạch Đằng 938 demo

Ngày: 2026-10-24
Baseline commit: dc4d859424dcdcaf90d9cf4f01a0c3dbf2a56100

## Kết quả tổng

- File giao: `demo/html-animations/bach-dang-938-demo.html`
- Kích thước: **748,845 bytes** (< 15 MB, dưới ngưỡng validator 15 MB)
- Hình thức: single-file HTML, mọi tài nguyên inline (base64 PNG), không CDN/network

## Công cụ thực sự dùng

- **Pillow 12.1.1** (system Python 3.10.11): vẽ thủ công 10 lớp artwork vào `demo/html-animations/art/*.png` — sky, mountains-far, mountains-near, river-high, river-surface, boats-viet, boats-han, stakes, mist, vignette. Tất cả nhúng base64.
- **GSAP 3.15.0** (`gsap.min.js` vendored, 72,927 B): timeline điều khiển mực nước, camera, tiến độ tàu, shake, glow. Không PixiJS (mọi bundle UMD v4–v8 chứa token validator cấm).
- **Canvas 2D**: render parallax nhiều lớp bằng `drawImage` + clip + transform; không dùng engine nặng.

## Công cụ không xác thực / không dùng được

- `FIGMA_AUTH_REQUIRED` — MCP Figma không kết nối.
- `LOTTIE_CONNECTION_CLOSED` — MCP Lottie Creator không kết nối.
- `open-design` / `pencil` — CONNECTION_CLOSED (session không kết nối được).
- **AI image gen (Gemini / ai-multimodal)**: `GEMINI_API_KEY` trả về `403 PERMISSION_DENIED — API key was reported as leaked` → không dùng được. Vì vậy artwork là **thủ công bằng Pillow** (procedural painting, seeded deterministic), không phải AI.

## Tài nguyên thật được tạo

10 file PNG trong `demo/html-animations/art/`:

| file | kích thước | vai trò |
|---|---|---|
| sky-dawn.png | 1200×500 | trời bình minh + mặt trời + mây |
| mountains-far.png | 1200×420 | dãy núi xa, atmospheric fade |
| mountains-near.png | 1200×420 | dãy núi gần, tối hơn |
| river-high.png | 1200×400 | mặt sông, phản chiếu trời + glint |
| river-surface.png | 1200×80 | lằn sóng tại đường nước |
| boats-viet.png | 700×340 | thuyền chiến Ngô Quyền (buồm đỏ, có canopy) |
| boats-han.png | 700×340 | thuyền Nam Hán (buồm vàng, hull xám) |
| stakes.png | 900×300 | bãi cọc gỗ 3 hàng, ngọn nhọn, mốc nước |
| mist.png | 1200×240 | sương sớm trôi ngang |
| vignette.png | 1200×700 | viền tối khung hình |

Tất cả nhúng `data:image/png;base64,` — **không một request mạng**.

## Kết quả gate

| Mục | Kết quả |
|---|---|
| Unicode (không mojibake) | **PASS** — `check-demo.py` xác nhận sạch |
| Banned tokens (validator) | **PASS** — `check-demo.py` quét toàn bộ deny-list |
| Kích thước < 15 MB | **PASS** — 748 KB |
| `HtmlDocumentValidator` (JUnit thật) | **PASS** — `HtmlDemoFileValidationIT` (temp, đã xóa): `Tests run: 1, Failures: 0` |
| jsdom smoke (play/pause/resume/replay/destroy) | **PASS** — bridge gửi đúng `READY`, `PLAYBACK_STARTED`, `PLAYBACK_PAUSED`, `PLAYBACK_STARTED` (resume), `PLAYBACK_STARTED` (replay) |
| Portrait 390×700 + Landscape 1200×700 | **PASS** — layout switch `PORTRAIT = H > W`, canvas fill hết viewport, safe-area inset cho caption/nút |
| 4 cảnh khác nhau | **PASS** — 5 cảnh: bình minh → cắm cọc → địch vào → nổ trận → chiến thắng |
| Cọc nhô lên theo mực nước | **PASS** — `draw()` clip `ctx.rect(...)` chỉ hiện phần cọc TRÊN `wTop`; `wTop` là hàm của `P.water` (GSAP tween). Không phải opacity-only. |
| Lifecycle sạch | **PASS** — `destroy()` cancel rAF, kill timeline, gỡ listeners; `replay()` reset toàn bộ `P` + `finished=false`; `PLAYBACK_FINISHED` gửi đúng một lần từ `onComplete` |
| Không lỗi JS | **PASS** — `errors: none` trong jsdom |
| Không network | **PASS** — mọi asset inline, không `fetch`/`XMLHttpRequest`/`script src`/`link href` |
| HTML_WEBVIEW regression | **PASS** — chỉ đổi `demo/`, không động vào backend/admin/flutter |

## Hạn chế đã biết

- **Không có công cụ capture** (Playwright bị cấm theo spec; không có screenshot tool khác) → không thể tự nghiệm thu VISUAL_QUALITY bằng ảnh. **Visual quality: NEEDS_REVIEW**.
- Artwork là **procedural hand-painted** bằng Pillow, không phải AI-generated, chưa qua review nghệ thuật. Chất lượng cao hơn primitives vì có lớp, texture, ánh sáng; nhưng vẫn là procedural.
- `ai-multimodal` skill vẫn bị block bởi Gemini key-leak 403 — không dùng được cho bất kỳ lần tạo ảnh nào.

## Cách tái tạo

```powershell
cd demo/html-animations/painter
python -I paint-plates.py      # vẽ 10 PNG vào ../art/
python -I assemble-demo.py     # ghép CSS + GSAP + JS + base64 PNG vào ../bach-dang-938-demo.html
python -I check-demo.py        # gate: mojibake + banned tokens + size
```
