# Báo cáo nâng cấp — Bạch Đằng 938 demo (Round 2)

Ngày: 2026-10-25
File giao: `demo/html-animations/bach-dang-938-demo.html`

## Kết quả nâng cấp tổng

- **Kích thước file**: **1,628,274 bytes (~1.6 MB)** (< 15 MB theo quy chuẩn `HtmlDocumentValidator`).
- **Hình thức**: Single-file HTML tự chứa toàn bộ (mọi art plates nhúng trực tiếp `data:image/png;base64,...`), không request mạng, tương thích hoàn toàn iframe sandbox và Flutter WebView `DauVietChannel`.
- **Chất lượng nghệ thuật & Chuyển động**:
  - Toàn bộ 13 lớp artwork vẽ thủ công chất lượng cao bằng Pillow 12.1.1 (thay vì 10 lớp đơn sơ trước đây).
  - Tái hiện chân thực địa hình sông nước Bạch Đằng: các rặng núi đá vôi tai mèo hiểm trở (karst Hạ Long / Thủy Nguyên), mây ngũ sắc và luồng ánh sáng bình minh rực rỡ, bãi lau sậy ngút ngàn ven bờ sông nơi quân Ngô Quyền mai phục.
  - **Rừng cọc Bạch Đằng**: Tăng cường 4 tầng cọc so le dày đặc, thân cọc gỗ lim to lớn có thớ nứt và ngấn rêu nước, đặc biệt **đầu cọc bịt sắt nhọn hoắt bén ngót** có vệt sáng phản chiếu kim loại đe dọa.
  - **Cảnh quân địch bị lùa vào cọc & vỡ thuyền (Trọng tâm yêu cầu)**:
    - Thuyền nhẹ quân Việt tiên phong dẫn dụ hạm đội Nam Hán vào sâu qua bãi cọc khi triều dâng ngập.
    - Đúng lúc triều rút cực mạnh (nước chảy xiết như thác đổ), rừng cọc nhọn hoắt tua tủa nhô lên khỏi mặt nước.
    - Thuyền Việt đột ngột quay mũi 180 độ đánh quật lại dữ dội, phục binh hai bờ lau sậy xông ra kẹp chặt hai đầu.
    - Đại chiến thuyền Nam Hán bị dòng nước xiết đẩy lùi dồn thẳng vào bãi cọc nhọn:
      * **Đáy thuyền bị cọc sắt đâm thủng toác, mạn thuyền gãy đôi nứt toác**.
      * **Cột buồm gãy sập 45 độ, buồm rách tả tơi rủ xuống**.
      * **Dăm gỗ, mảnh ván vỡ vụn và dầm chèo gãy bắn tung tóe vào không trung rồi trôi dạt trên dòng nước xoáy**.
      * **Hỏa công: Mưa tên lửa từ quân Việt bắn tới, lửa bốc cháy ngùn ngụt, khói đen cuộn trên xác tàu giặc**.
      * Cột nước và bọt sóng tung tóe tại điểm va chạm, rung chấn va đập rung chuyển màn hình.
      * Tàu nghiêng hẳn 35 độ chúc mũi chìm dần vào lòng sông Bạch Đằng.

## Danh mục 13 Art Plates (trong `demo/html-animations/art/`)

| File | Kích thước | Vai trò & Chi tiết |
|---|---|---|
| `sky-dawn.png` | 1200×500 | Trời bình minh ráng hồng cam rực rỡ, tia sáng mặt trời chiếu xuyên mây |
| `mountains-far.png` | 1200×420 | Dãy núi đá vôi xa mờ tím trong sương mai |
| `mountains-near.png` | 1200×420 | Dãy karst gần sừng sững, vách đá dựng đứng hiểm trở có vết nứt và rêu phong |
| `river-high.png` | 1200×400 | Dòng sông Bạch Đằng cuồn cuộn sóng triều, vệt nắng phản chiếu lấp lánh |
| `river-surface.png` | 1200×80 | Lằn sóng động tại ngấn nước chuyển động theo thủy triều |
| `reeds.png` | 1200×200 | Bãi lau sậy ngút ngàn hai bên bờ sông nơi quân Việt mai phục |
| `boats-viet.png` | 700×340 | Thuyền chiến Ngô Quyền: mũi rồng vút cao, buồm đỏ cánh dơi viền vàng, hàng khiên đồng, cờ xí bay phần phật |
| `boats-han.png` | 700×340 | Lâu thuyền Nam Hán: đồ sộ, hai tầng lầu, nặng nề, cờ Hán kiêu ngạo |
| `boats-han-broken.png` | 700×340 | Tàu giặc vỡ vụn: cọc nhọn đâm xuyên thủng toác đáy, cột buồm gãy sập, cháy đen nghiêng chìm |
| `stakes.png` | 1200×320 | Bãi cọc gỗ lim bịt sắt nhọn hoắt 4 hàng tầng tầng lớp lớp, sắc nhọn hiểm ác |
| `splinters.png` | 600×200 | Mảnh ván thuyền vỡ vụn, dầm chèo gãy, khiên và thùng gỗ trôi dạt |
| `mist.png` | 1200×240 | Sương sớm bảng lảng trôi trên mặt nước |
| `vignette.png` | 1200×700 | Viền tối điện ảnh tạo chiều sâu thị giác |

## Kết quả Gate Kiểm Tra

| Tiêu chí | Kết quả | Chi tiết |
|---|---|---|
| `check-demo.py` | **PASS** | Sạch hoàn toàn mojibake, không vi phạm danh sách ký tự cấm, dung lượng 1.62 MB < 15 MB |
| Banned tokens | **PASS** | Không chứa `fetch`, `XMLHttpRequest`, `WebSocket`, `Worker`, `iframe`, `eval`, `script src`, `link href` |
| jsdom smoke test | **PASS** | Vòng đời hoàn hảo: `READY`, `PLAYBACK_STARTED`, `PLAYBACK_PAUSED`, `PLAYBACK_STARTED` (resume/replay), `PLAYBACK_FINISHED` |
| Responsive | **PASS** | Tự động thích ứng cả Portrait (390×700) lẫn Landscape (1200×700) |
| Fallback an toàn | **PASS** | Hỗ trợ đầy đủ shim `rAF`/`cAF` cho môi trường không có requestAnimationFrame |

## Cách tái tạo & kiểm tra

```powershell
cd demo/html-animations/painter
python -I paint-plates.py      # Vẽ 13 file PNG vào ../art/
python -I assemble-demo.py     # Ghép CSS + GSAP + JS + base64 PNG vào ../bach-dang-938-demo.html
python -I check-demo.py        # Kiểm tra chuẩn bảo mật & dung lượng
```
