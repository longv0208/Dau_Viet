# TASK-0019 handoff — Bạch Đằng 938 Production Slice

## Đã làm
- `V17__bachdang_production_scene.sql` (mới, idempotent): 3 ACTIVE assets UUID cố định (`d7a70000-…-001/002/003` — hero jpg 1200×896, map-base jpg 1200×896, narration wav 44.1k/16bit/8.5s); scene `d7a80000-…-001` RIVER_TIDE v2 gắn `event_id` bach-dang-938; version 1 + asset refs + PUBLISHED.
- `dau-viet-backend/data/assets/d7a70000-…` ×3 bytes đã copy đúng tên contract.
- `AnimationProductionSeedTest` (mới): trích `m_bd_prod` → `AnimationManifestValidator` → 0 lỗi; assert 8 beats + audio wiring + prediction.
- Manifest 8 beats: estuary → stake-prep → tide-rise → decoy → prediction → tide-fall → counterattack → evidence; camera/tracks/effects/audio/environment đầy đủ; background hero + map-plate OBJECT fade + 2 boat procedural.

## Verify
- `mvnw compile` clean; `mvnw test` 250 run / 0 fail / 1 err (`DauVietApplicationTests`, Docker OFF — blocker đã ghi).

## Chưa làm / cần tiếp
- Docker OFF → chưa verify Flyway chạy V17 trên Postgres thật, chưa verify asset content endpoint serve đúng bytes, `AnimationScenePublishIT` vẫn blocked.
- Chưa verify visual trên device/emulator — cần chạy app, login, vào event bach-dang-938, pin scene vào lesson.
- `bg_story_*.jpg` ×3 chưa dùng trong scene (giữ cho story cards sau nếu cần).
- Không commit/push — chờ user.
