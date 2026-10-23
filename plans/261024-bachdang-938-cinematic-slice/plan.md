---
title: "Bạch Đằng 938 — Production Cinematic Slice"
status: complete
priority: P0
created: 2026-10-24
baseline: cd896cc
---

# Bạch Đằng 938 — Production Cinematic Slice

Dùng engine animation hiện có (V14–V16 + FIX-* đã merge). Không viết lại runtime. Deliverable: scene production v2 RIVER_TIDE gắn event `bach-dang-938` + assets thật (ảnh nền + object sprites + narration) thay cho placeholder silent-WAV của V16.

## Constraints
- Không commit/push. Không Playwright. Không báo cáo hậu triển khai độc lập.
- Không hard-code eventId/slug trong generic renderer — scene là DATA manifest.
- Không sửa V15/V16/published snapshots cũ — V17 là migration mới, idempotent.
- Docker OFF → Testcontainers ITs BLOCKED, ghi thật; unit/MockMvc/validator cover.
- Không claim "production artwork" khi thiếu artwork; hero + map-base là artwork thật đã kiểm chứng.

## Asset audit (kết quả)
| Tài nguyên | Kho | Kích thước | Đánh giá |
|---|---|---|---|
| `dv_EVT_ngoquyen_bachdang_hero_v01.jpg` | design + mobile (MD5 811D5F00 trùng) | 1200×896, 1.1MB | Artwork thật: Ngô Quyền + thuyền + bãi cọc nhô — hand-painted, không pixel. Phù hợp hero/background RIVER_TIDE. |
| `dv_MAP_ngoquyen_bachdang-base_v01.jpg` | design + mobile (MD5 3F2FA76B trùng) | 1200×896, 1.0MB | Artwork thật: cửa sông Bạch Đằng minh họa — phù hợp map-base JOURNEY_MAP nếu cần. |
| `bg_story_*.jpg` ×3 | mobile only | 1376×768, ~1MB mỗi | Illustration thật (trận địa/doanh trại/thư phòng) — story-card assets. |
| `narration_bach_dang.wav` | mobile only | 44.1kHz 16-bit mono, 8.5s, 750KB, peak 14247 | Audio thật, không phải silence (peak khác 0, duration 8.5s). |
| backend `data/assets/*.jpg` ×3 | backend dev store | 2048×1152 / 1000×1414 / 2048×1378 | Đã upload qua admin — UUID không khớp design filename; cần đăng ký lại với UUID cố định + tên file đúng contract. |
| backend `d7a60000-…-0001.wav` | backend dev store | 46 bytes | Silent placeholder của V16 — sẽ thay bằng narration thật trong scene mới. |

## Phases

### P0 — verification (reuse)
- [x] SnapshotBuilderTest 4/4, `mvnw test` 248/0fail/1err (Docker blocker), admin 194/194, flutter 230/230 — tái dùng evidence ở `plans/261024-0132-animation-engine-fix-harden/plan.md`.
- [~] AnimationScenePublishIT: BLOCKED (Docker daemon OFF `//./pipe/dockerDesktopLinuxEngine`).
- [ ] `mvnw compile` sau khi thêm V17; validator unit test cho manifest mới.

### P1 — asset registration (V17)
- [x] `V17__bachdang_production_scene.sql` (mới, idempotent ON CONFLICT):
  - 3 ACTIVE assets: `d7a70000-…-001` hero jpg / `…-002` map jpg / `…-003` narration wav — mime/size/alt_text thật, storage_key `assets/<uuid>.<ext>`.
  - Scene `d7a80000-…-001` RIVER_TIDE v2, event_id `00000000-…-001` (EventSeedService.BACH_DANG_ID), 8-beat storyboard, camera + tracks (boat-decoy/boat-fleet/map-plate opacity) + effects + audio ENTER/EXIT cues + environment mist/glow + prediction + sourceReferences (3 nguồn) + disclaimer.
  - Version 1 + `animation_scene_asset_refs` + current_version_id + status PUBLISHED.
- [x] Bytes copied: `dau-viet-backend/data/assets/d7a70000-…-001.jpg` (1.16MB), `…-002.jpg` (1.08MB), `…-003.wav` (750KB).
- [x] `AnimationProductionSeedTest` — trích `m_bd_prod` từ V17, `AnimationManifestValidator` → 0 errors; 2/2 pass (8 steps, 3 assets, audio cues đều trỏ `voice`, prediction wired).

### P2 — asset production contract
- [x] `tasks/TASK-0019/task.json` + `brief.md` — full contract metadata (key/filename/category/era/event/altText/source/confidence/license/review/dimensions/layer/anchor/format/use).
- [x] `design/assets/*.meta.json` khớp altText với V17 rows.

### P3 — layered composition (không code mới)
- [x] Engine đã hỗ trợ đầy đủ — không `BạchĐằngOnlyRenderer`. `bg-hero` BACKGROUND + `map-plate` OBJECT assetRef (fades out beat 1) + `boat-decoy`/`boat-fleet` procedural + camera + tracks + effects + audio + env — 100% manifest data.

### P4 — 8-beat storyboard (trong manifest V17)
- [x] estuary → stake-prep → tide-rise → decoy → prediction (PREDICTION allowedInteractions) → tide-fall → counterattack → evidence. Mỗi beat có narration/hint/durationMs/easing/targetState; camera pose riêng; audio ENTER cue riêng; EXIT ở beat cuối.

### P5 — admin no-code workflow
- [x] Pipeline hiện có đủ dùng: upload → Asset Library → scene editor (picker → sections → preview → validate → publish) → lesson builder pin version → publish lesson. Scene V17 PUBLISHED sẵn — admin chỉ mở Animation Library để xem/pin, không cần authoring tay.

### P6 — Flutter responsive/perf
- [x] `ManifestAssetLayers`/`HistoricalAnimationPlayer` responsive theo `canvas.aspectRatio` + dispose/idle-safe. Scene mới thừa hưởng — không code mới. Widget tests 230/230 (reuse).

### P7 — audio
- [x] narration 8.5s thật (peak 14247, không silence) gắn ENTER cue mỗi beat + EXIT ở `evidence`. Controller đã handle mute/pause/skip/dispose/generation-race. Không `silence.wav` trong scene production.

## Evidence
- `mvnw compile` — clean.
- `mvnw test` — **250 run / 0 fail / 1 err** (chỉ `DauVietApplicationTests` — Testcontainers, Docker OFF; mọi `*IT` cùng blocked). `AnimationProductionSeedTest` 2/2.
- Files: `V17__bachdang_production_scene.sql` (mới), `AnimationProductionSeedTest.java` (mới), `data/assets/d7a70000-…` ×3 (mới), `tasks/TASK-0019/`, plan này.
- Không sửa V15/V16; không commit/push.

## Blockers
- Docker daemon OFF (`//./pipe/dockerDesktopLinuxEngine`) → mọi Testcontainers IT (`DauVietApplicationTests`, `AnimationScenePublishIT`, `ActuatorHealthIT`, `EventSeedServiceIT`, `FlywayMigrationIT`…) **BLOCKED**, không đánh dấu PASS. V17 manifest được cover bằng `AnimationProductionSeedTest` (validator-level, không cần DB); chưa có IT chạy migration thật trên Postgres — cần Docker để verify Flyway + serve asset bytes end-to-end.

## Next
- Bật Docker → `mvnw verify` cho `*IT` (đặc biệt `AnimationScenePublishIT` + asset content endpoint).
- Admin: mở Animation Library → scene "Trận Bạch Đằng năm 938 — Production" đã PUBLISHED → pin vào lesson qua lesson builder.
- Mobile: verify hiển thị thực tế của layered scene (bg jpg + objects + camera + audio) trên thiết bị/emulator — unit/widget tests đã cover logic, chưa verify bằng mắt.
