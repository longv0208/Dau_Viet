# TASK-0019 handoff — Bạch Đằng 938 Production Slice

## Đã làm (fix sau source audit)

### P0 — V17 Flyway FK + post-Flyway link (FIX-01)
- `V17__bachdang_production_scene.sql`: `evt_bachdang` resolve theo slug `bach-dang-938` (không hard-code UUID); thiếu event → `event_id NULL`. UPDATE cuối file chỉ chạy **một lần lúc migrate** — link NGAY nếu event đã tồn tại (prod DB seeded trước deploy); KHÔNG phải "chạy lại lần migrate sau" (Flyway không re-run migration đã applied).
- `AnimationSceneEventLinker` (mới, `historicalevent/infrastructure/seed/`): local-only post-link chạy trong `EventSeedRunner` sau `upsertBachDang()` — dùng **event id thật** từ repository, chỉ fill khi scene `eventId NULL` + `updatedBy = sys_user` (untouched seed row); không đè link/unlink admin; idempotent; không tạo scene; không đụng published versions. Prod không auto-link — admin link tay qua `SceneUpdateRequest.eventId` (đã validate FK + `clearEvent`).
- Test: `AnimationSceneEventLinkerTest` 5/5 (real-id link, idempotent, admin-edit kept, missing-scene noop, null-event noop). V17 unapplied ngoài local-dev → không checksum drift trên DB đã migrate.

### P0 — prediction checkpoint theo step (FIX-02)
- `HistoricalAnimationStep.allowedInteractions` + `AnimationPrediction.stepIndex`; manifest v2 bind qua `PREDICTION` trong `allowedInteractions` (`_predictionStepIndex()` fallback giữa scene khi manifest thiếu binding).
- `HistoricalAnimationDefinition.manifestV2` (mới): `schemaVersion>=2` → `allowedInteractions` là **whitelist thuần** (rỗng = bước không tương tác, parity admin ScenePreview); `manifestV2=false` (v1/legacy hardcode + manifest v1) → rỗng = definition-level áp mọi bước (không regression). Phân biệt qua `manifestV2`, không nhìn eventId/slug.
- Player: `_interactionAllowedAtCurrentStep()` gate WaterLevelControl / LocationInfoPanel / MapMarkerOverlay; PredictionBlock chỉ ở checkpoint; AUTO (`_scheduleAdvance`) dừng `_playing=false` ở checkpoint chưa reveal. v1 pin stepIndex 2/3/3 (parity).
- V17 expected: slider chỉ ở tide-rise + tide-fall; PredictionBlock chỉ ở prediction; các beat khác không tương tác.

### P1 — audio storyboard (FIX-03)
- `audio[]` = 1 ENTER cue @estuary (clip overview 8.5s phát MỘT lần xuyên phần mở đầu các beat — option A). One-shot player tự chạy đến hết, không phát chồng, không phải VO từng beat; `onSkip`/`dispose`/`onStepExit` stop đúng, NEXT không replay, mute gate `_soundEnabled`. Không tạo narration giả, không silent WAV.
- `AnimationProductionSeedTest` assert `audio.size()==1` ENTER@estuary.

### P1 — documentation truthfulness (FIX-04)
- `task.json`: status `in_progress` (không done); AC-2 slug-resolution; AC-3 sửa "ENTER/LOOP/EXIT" → "single ENTER cue on estuary"; blockedReason/nextAction thật.
- `brief.md`: provenance REVIEW_REQUIRED (chưa verify độc lập); ghi rõ thuyền/cọc procedural (không sprite thật), background raster 1 lớp (không parallax), audio overview không phải VO từng beat, interaction whitelist từng bước.

## Verify đã chạy thật
- `mvnw compile` clean; `mvnw test` **255 run / 0 fail / 1 err** — err duy nhất `DauVietApplicationTests` (Testcontainers, Docker OFF — blocker đã ghi, không phải regression). `AnimationSceneEventLinkerTest` 5/5, `AnimationProductionSeedTest` 2/2.
- `flutter analyze` clean (5 info cũ `file_names` pre-existing); `flutter test` **350/350** (46 runtime tests incl. 4 mới: v2 whitelist slider, v1 legacy semantics, v2 map TAP_TO_EXPLORE gate, legacy animationKey interactive). `dart format` clean.
- Admin (đợt trước, code không đổi): typecheck + lint clean, vitest 194/194, `next build` OK.
- `git diff --check` clean.
- Asset delivery không-DB: 3 file `d7a70000-…` git-tracked, size khớp DB, magic bytes JPEG/WAV thật; `LearnerAssetController` serve `FileSystemResource` đúng mime; Flutter authenticated fetch + fallback không-crash; `dauviet.assets.dir=data/assets` theo cwd (runbook: chạy từ `dau-viet-backend/`).
- E2E pin→snapshot→`sceneVersionId`: `SnapshotBuilderTest` (unit, không DB).

## Chưa làm / blocker
- **Docker OFF** → `mvnw verify`: Flyway V17 trên clean Postgres (P0 fix đã code, chưa chạy migration thật), `AnimationScenePublishIT`, asset content endpoint end-to-end, `EventSeedServiceIT` (linker qua runner trên DB thật) — tất cả BLOCKED. Không chạy flyway repair.
- Chưa verify visual trên device/emulator; chưa pin scene vào lesson thật qua admin UI (pin-path chỉ cover bởi SnapshotBuilderTest).
- Provenance quyền dùng 2 JPG + WAV: REVIEW_REQUIRED.
- Không sprite thuyền/cọc thật (PARTIALLY); map-plate crop vuông ~40% chiều cao (engine `_positioned` dùng `diameter`, parity admin preview).
- `bg_story_*.jpg` ×3 chưa dùng.
- Không commit/push — chờ user.
