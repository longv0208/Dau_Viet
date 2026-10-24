---
title: "Bạch Đằng 938 — Production Cinematic Slice"
status: in_progress
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
- Quyền dùng artwork/audio chưa verify độc lập → REVIEW_REQUIRED (§7), không mark APPROVED; assets chưa duyệt không ship production lesson.

## Fix sau source audit (đợt này)
- **P0 V17 FK**: bỏ hard-code `00000000-…-001`; `evt_bachdang` resolve theo slug `bach-dang-938`, NULL fallback + late-link UPDATE (`event_id` NULL + `updated_by=sys_user` → idempotent, không đè link admin). Admin link tay qua `SceneUpdateRequest.eventId`.
- **P0 prediction checkpoint**: `allowedInteractions` trên step + `stepIndex` trên prediction; manifest v2 bind qua `PREDICTION` trong `allowedInteractions` (mobile parity với admin preview). AUTO dừng ở checkpoint chưa reveal; v1 pin stepIndex 2/3/3.
- **P1 audio**: `audio[]` còn 1 ENTER cue ở `estuary` (overview clip phát một lần, không lặp intro); VO per-beat cần clip riêng có license.
- **P1 asset delivery**: verify phần không-DB xong — file git-tracked, magic bytes đúng, endpoint serve FileSystemResource, Flutter authenticated fetch + no-crash fallback; caveat `dauviet.assets.dir` theo cwd (runbook: chạy từ `dau-viet-backend/`).
- **P1 visual**: không sprite thuyền/cọc thật → procedural giữ nguyên, PARTIALLY + cần asset brief; map-plate box vuông scale 1.0 crop ~40% chiều cao (engine behavior, giống admin preview).
- **P1 E2E**: `SnapshotBuilderTest` chứng minh pin→snapshot→`sceneVersionId` (unit); pin-publish-fetch thật chờ Docker.
- **§10 status**: `task.json` done→in_progress.

## Asset audit (kết quả)
| Tài nguyên | Kho | Kích thước | Đánh giá |
|---|---|---|---|
| `dv_EVT_ngoquyen_bachdang_hero_v01.jpg` | design + mobile (MD5 811D5F00 trùng) | 1200×896, 1.1MB | Artwork thật: Ngô Quyền + thuyền + bãi cọc nhô — hand-painted, không pixel. Phù hợp hero/background RIVER_TIDE. |
| `dv_MAP_ngoquyen_bachdang-base_v01.jpg` | design + mobile (MD5 3F2FA76B trùng) | 1200×896, 1.0MB | Artwork thật: cửa sông Bạch Đằng minh họa — OBJECT plate fade-out beat 1. |
| `bg_story_*.jpg` ×3 | mobile only | 1376×768, ~1MB mỗi | Illustration thật — story-card assets, chưa dùng. |
| `narration_bach_dang.wav` | mobile only | 44.1kHz 16-bit mono, 8.5s, 750KB | Audio thật (peak 14247) — 1 cue ENTER ở beat mở đầu. |
| backend `data/assets/*.jpg` ×3 | backend dev store | — | Admin uploads; UUID khác design filename. |
| backend `d7a60000-…-0001.wav` | backend dev store | 46 bytes | Silent placeholder V16 — không dùng trong scene production. |

## Phases

### P0 — verification (reuse)
- [x] SnapshotBuilderTest 4/4, admin 194/194, flutter — tái dùng evidence.
- [~] AnimationScenePublishIT: BLOCKED (Docker OFF).
- [x] `mvnw compile` sau khi thêm/sửa V17; `AnimationProductionSeedTest` validator-level.

### P1 — asset registration (V17)
- [x] `V17__bachdang_production_scene.sql` (idempotent ON CONFLICT):
  - 3 ACTIVE assets `d7a70000-…-001/002/003`, storage_key `assets/<uuid>.<ext>`, size khớp file thật.
  - Scene `d7a80000-…-001` RIVER_TIDE v2, `event_id` = slug-resolved (NULL + late-link), 8-beat storyboard, camera + tracks + effects + 1 audio ENTER cue + environment + prediction + sourceReferences (3 nguồn) + disclaimer.
  - Version 1 + `animation_scene_asset_refs` + current_version_id + PUBLISHED.
- [x] Bytes `dau-viet-backend/data/assets/d7a70000-…` ×3 git-tracked.
- [x] `AnimationProductionSeedTest` 2/2 (audio.size()==1, ENTER@estuary).

### P2 — asset production contract
- [x] `tasks/TASK-0019/task.json` + `brief.md` contract metadata; `design/assets/*.meta.json` khớp altText.

### P3 — layered composition (không code mới)
- [x] 100% manifest data — không `BạchĐằngOnlyRenderer`, không event-UUID trong generic code.

### P4 — 8-beat storyboard
- [x] estuary → stake-prep → tide-rise → decoy → prediction (`allowedInteractions:["PREDICTION"]`) → tide-fall → counterattack → evidence.

### P5 — admin no-code workflow
- [x] Pipeline sẵn: Animation Library → pin vào lesson builder → publish. Scene V17 PUBLISHED sẵn.

### P6 — Flutter responsive/perf
- [x] `flutter test` **346/346** sau khi thêm gating + sửa 5 test điều hướng tới checkpoint + 3 test mới (bind stepIndex, chỉ hiện ở checkpoint, AUTO không qua checkpoint chưa reveal).

### P7 — audio
- [x] 1 ENTER cue overview @estuary; controller handle pause/skip/dispose/generation-race. Per-beat VO = asset gap đã ghi.

## Evidence
- `mvnw compile` clean; `mvnw test` 250/0 fail/1 err (Docker-blocked `DauVietApplicationTests`). `AnimationProductionSeedTest` 2/2.
- `flutter analyze` clean; `flutter test` 346/346; `dart format` clean.
- Admin: typecheck + lint clean, vitest 194/194, `next build` OK. `git diff --check` clean.
- Files đợt này: `V17__bachdang_production_scene.sql`, `AnimationProductionSeedTest.java`, `historical_animation_definition.dart`, `animation_manifest_dto.dart`, `historical_animation_player.dart`, `bach_dang_938_tide_v1.dart`, `hai_ba_trung_40_uprising_v1.dart`, `ly_thai_to_1010_relocation_v1.dart`, `historical_animation_test.dart`, `animation_runtime_test.dart`, `tasks/TASK-0019/task.json` + `handoff.md`.
- Không sửa V15/V16; không commit/push.

## Blockers
- Docker daemon OFF → mọi Testcontainers IT (`DauVietApplicationTests`, `AnimationScenePublishIT`, `FlywayMigrationIT` — V17 trên clean DB, `EventSeedServiceIT` — late-link, asset content endpoint) **BLOCKED**. P0 FK fix đã code nhưng chưa chạy migration thật.
- Chưa verify visual trên device/emulator; chưa pin scene vào lesson thật qua admin UI.
- Provenance quyền dùng 2 JPG + WAV: REVIEW_REQUIRED.

## Next
- Bật Docker → `mvnw verify` (Flyway V17 clean DB, AnimationScenePublishIT, asset endpoint, EventSeedServiceIT).
- Admin: Animation Library → pin scene vào lesson + gán event nếu event_id NULL.
- Mobile: verify bằng mắt trên device/emulator.
