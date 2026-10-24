# TASK-0019 handoff — Bạch Đằng 938 Production Slice

## Đã làm (fix sau source audit)
- **P0 — V17 Flyway FK**: `V17__bachdang_production_scene.sql` không còn hard-code `00000000-…-001`. `evt_bachdang` resolve `SELECT id … WHERE slug='bach-dang-938'`; thiếu event → `event_id NULL` (schema cho phép, precedent V15/V16). UPDATE cuối file "late-link": `event_id=e.id` chỉ khi scene đang `NULL` + `updated_by=sys_user` → idempotent, không ghi đè link admin đã chỉnh; admin link tay qua `SceneUpdateRequest.eventId` (đã validate FK).
- **P0 — prediction checkpoint theo step**: `HistoricalAnimationStep.allowedInteractions` (Set, default {} = v1 always-on) + `AnimationPrediction.stepIndex`. Manifest v2 bind qua `steps[].allowedInteractions` chứa `PREDICTION` (`_predictionStepIndex()` trong `animation_manifest_dto.dart`); v1 pin `stepIndex` 2/3/3 (bạch-đằng/hai-bà-trưng/lý-thái-tổ) để giữ parity. Player: PredictionBlock chỉ render ở checkpoint; `WaterLevelControl`, `LocationInfoPanel`, marker overlay gate theo step (rỗng = luôn hiện như cũ). AUTO (`_scheduleAdvance`) dừng `_playing=false` ở checkpoint chưa reveal — không auto-reveal, không chạy qua tide-fall khi chưa chọn; skip/back vẫn được, skip ≠ đáp án; replay reset trạng thái.
- **P1 — audio storyboard**: 1 clip overview 8.5s trước đây là ENTER cue của 6 beat → shared one-shot player restart mỗi step = lặp intro. Giờ `audio[]` chỉ còn ENTER ở `estuary` (phát một lần), bỏ EXIT (clip ngắn hơn step, tự kết). VO theo từng beat cần clip riêng có license — text narration mang nội dung beat; `AnimationProductionSeedTest` assert `audio.size()==1`.
- `tasks/TASK-0019/task.json` status done→in_progress; AC-2 cập nhật slug-resolution; nextAction/blockedReason mới.

## Verify đã chạy thật
- `mvnw compile` clean; `mvnw test` 250 run / 0 fail / 1 err (`DauVietApplicationTests` — Docker OFF, expected). `AnimationProductionSeedTest` 2/2.
- `flutter analyze` clean; `flutter test` **346/346**; `dart format --set-exit-if-changed` sạch sau khi format lại 2 file.
- Admin: `typecheck` clean, `lint` clean (0 warning), vitest 194/194, `next build` OK.
- `git diff --check` clean.
- Asset delivery (phần không cần DB): 3 file `data/assets/d7a70000-…` git-tracked, size khớp `size_bytes` trong V17; magic bytes JPEG/WAV thật; `LearnerAssetController` serve `FileSystemResource` đúng mime; Flutter fetch authenticated qua `/api/v1/assets/{id}/content` với fallback không-crash (ảnh lỗi → `_Fallback` + retry; audio bytes rỗng/lỗi → bỏ cue). `dauviet.assets.dir=data/assets` resolve theo cwd — runbook yêu cầu chạy từ `dau-viet-backend/` (đúng); chạy từ repo-root sẽ không thấy file — caveat đã ghi, không có Dockerfile nên chưa phát sinh deploy khác cwd.
- E2E pin scene → lesson snapshot: `SnapshotBuilderTest` chứng minh embed manifest + `sceneVersionId` (unit, không DB); pin-publish-mobile fetch thật cần Docker.
- Visual audit: không có sprite thuyền/cọc thật trong repo (chỉ hero + map artwork) → procedural BOAT/STAKE giữ nguyên; cần asset brief nếu muốn sprite thật (PARTIALLY). map-plate: object bounding là **vuông** (`diameter = width × scale`, `_positioned`), ảnh 1200×896 `BoxFit.cover` ở scale 1.0 → crop ~40% chiều cao, phủ gần hết canvas ở beat 1 rồi fade 2.2s — đúng ý đồ "terrain trước overlay" nhưng crop vuông là đặc tính engine hiện tại (giống admin preview), chưa verify bằng mắt trên device.
- §7 provenance: `sourceReferences` = nguồn lịch sử (sử liệu), KHÔNG phải provenance artwork; quyền dùng 2 JPG + WAV chưa verify độc lập → REVIEW_REQUIRED, không mark APPROVED; assets chưa duyệt không ship production lesson.

## Chưa làm / cần tiếp (blocked)
- Docker OFF → `mvnw verify`: Flyway chạy V17 trên clean Postgres (P0 FK fix đã code nhưng chưa chạy migration thật), `AnimationScenePublishIT`, asset content endpoint end-to-end, `EventSeedServiceIT` (late-link) — tất cả BLOCKED.
- Chưa verify visual trên device/emulator; chưa pin scene vào lesson thật qua admin.
- `bg_story_*.jpg` ×3 chưa dùng (giữ cho story cards).
- Không commit/push — chờ user.
