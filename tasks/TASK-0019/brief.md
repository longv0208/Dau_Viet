# TASK-0019 — Bạch Đằng 938 Production Cinematic Slice

## Asset production contract (V17)

| key | filename | category | era | event | altText | source | confidence | license | review | dimensions | layer | anchor | format | use |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| bachdang-hero | d7a70000-…-001.jpg | EVT | ngoquyen | bach-dang-938 | "Ngô Quyền chỉ huy thủy quân trên sông Bạch Đằng, bãi cọc nhô phía trước" | Đại Việt Sử Ký Toàn Thư; Việt Sử Tiêu Án; Khâm Định Việt Sử | HIGH | Internal Project IP | REVIEW_REQUIRED — chưa verify provenance độc lập | 1200×896 | BACKGROUND (raster 1 lớp, không parallax) | center | jpg | hero/backdrop RIVER_TIDE |
| bachdang-map-base | d7a70000-…-002.jpg | MAP | ngoquyen | bach-dang-938 | "Cửa sông Bạch Đằng minh họa: sông uốn qua đồng bằng, núi đá vôi, làng chài ven bờ" | Đại Việt Sử Ký Toàn Thư; Khâm Định Việt Sử | HIGH | Internal Project IP | REVIEW_REQUIRED — chưa verify provenance độc lập | 1200×896 | OBJECT plate (fade-out beat 1) | center | jpg | terrain plate trước overlay |
| narration-bach-dang | d7a70000-…-003.wav | AUDIO | ngoquyen | bach-dang-938 | "Thuyết minh 8.5 giây tóm tắt trận Bạch Đằng 938" | studio narration | HIGH | Internal Project IP | REVIEW_REQUIRED — chưa verify provenance độc lập | 44100Hz 16bit mono 8.5s | AUDIO | n/a | wav | 1 ENTER cue @estuary (overview, không VO từng beat) |

Constraints: ≤10MB/file; JPG/WAV trong bundle; không PSD/KRA; không text baked-in.

Ghi chú trung thực:
- Thuyền (boat-decoy/boat-fleet) và cọc vẽ procedural — KHÔNG có sprite thật. Cần asset brief nếu muốn sprite.
- Background là raster 1 lớp — không parallax layer riêng.
- Audio: 1 clip overview 8.5s phát MỘT lần ở beat mở đầu (estuary), không lặp, không phải VO theo từng beat; text narration mang nội dung beats còn lại.

## Storyboard 8 beats
estuary → stake-prep → tide-rise → decoy → prediction → tide-fall → counterattack → evidence.

## Interaction whitelist theo bước (manifest v2 — parity admin preview)
- estuary: (không tương tác)
- stake-prep: (không tương tác)
- tide-rise: WATER_LEVEL_CONTROL
- decoy: (không tương tác)
- prediction: PREDICTION (checkpoint — AUTO dừng chờ reveal)
- tide-fall: WATER_LEVEL_CONTROL
- counterattack: (không tương tác)
- evidence: (không tương tác)
