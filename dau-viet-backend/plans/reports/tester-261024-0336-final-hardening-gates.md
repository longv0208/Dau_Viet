# Tester report — Final hardening gates (§13)

Ngày: 2026-10-24. Phạm vi: toàn bộ gates §13 cho "Data-driven Animation
Engine + Cinematic 2.5D" hardening, repo `longv0208/Dau_Viet` @ main.

Ghi chú môi trường: Bash tool trên máy local bị lỗi startup file
(`unexpected EOF` line 184) — toàn bộ lệnh chạy qua PowerShell 5.1.
Kết quả bên dưới là output thật đã chạy, không mô phỏng.

## Kết quả tổng hợp

| Gate | Lệnh | Kết quả |
|---|---|---|
| Mobile format | `dart format` (đã áp dụng) | OK — file đã format, analyze không báo |
| Mobile analyze | `flutter analyze` | OK — chỉ 5 info `file_names` pre-existing (kebab-case `main-bottom-nav.dart`…), không liên quan diff |
| Mobile test | `flutter test` | PASS — 314/314 tests (gồm `read_renderer_manifest_test.dart` 4 tests mới, `historical_animation_test.dart` auto-advance pump 60s) |
| Admin typecheck | `npm run typecheck` (`tsc --noEmit`) | PASS — 0 lỗi |
| Admin lint | `npm run lint` (`next lint`) | PASS — 0 warning (đã dọn 4 warnings `scene-preview.tsx`: unused `globalTMs`, 3× exhaustive-deps) |
| Admin test | `npm test -- --run` (vitest) | PASS — 158/158 tests, 32 files (gồm `cinematic-eval.test.ts` 14 tests) |
| Admin build | `npm run build` (`next build`) | PASS — compile 7.8s, 25/25 static pages |
| Backend compile | `./mvnw compile` | PASS |
| Backend unit | `./mvnw test` | 244 run, 1 error — `DauVietApplicationTests` (xem mục Docker) |
| Backend animation unit | `./mvnw test -Dtest=com.dauviet.animation.**.*Test` | PASS — 59/59 (Validator 44, Controller 12, SeedManifest 3) |
| Backend IT | `AnimationScenePublishIT` (5 tests) | BLOCKED — Docker daemon không chạy |
| git diff --check | repo root | OK — chỉ CRLF warnings (windows line-ending), không whitespace error |

## Docker / ITs (blocked-by-environment, không phải code defect)

- `docker version`: client 29.8.2 hiện hữu; daemon trả
  `failed to connect to the docker API at npipe:////./pipe/dockerDesktopLinuxEngine`
  — Docker Desktop chưa chạy.
- `AbstractPostgresIT.<clinit>` gọi `POSTGRES.start()` (Testcontainers) khi
  load class → mọi `*IT` và `DauVietApplicationTests` (extends IT) fail
  `ExceptionInInitializer` ngay khi init. Đây là hành vi có sẵn của repo,
  không do hardening gây ra.
- `-Dtest='!*IT'` không loại được `DauVietApplicationTests` (tên không đuôi
  IT nhưng vẫn extends `AbstractPostgresIT`).
- `AnimationScenePublishIT.java` (§8, 5 tests: v1→1, v2→2, missing field→1,
  v1+v2 keys→422, versions endpoint) compile sạch — cần chạy lại khi Docker
  Desktop bật, hoặc trên CI có Docker.

## Coverage §12 (preservation)

- v1 scenes: `historical_animation_test.dart` group `ReadRenderer +
  animationKey` + 3 scene content tests.
- Manifest precedence + legacy fallback: `animation_runtime_test.dart`
  (`manifest takes precedence over a legacy animationKey`, `legacy
  animationKey still works without a manifest`).
- Version pinning: backend `SimpleActivityValidators` (sceneId↔versionId
  match) + `SnapshotBuilder.embedAnimationScenes` pin snapshot; IT
  `AnimationScenePublishIT.sceneVersionsEndpoint_listsPublishedSchemaVersion`.
- Archive: `AnimationScenePublishService` từ chối publish scene ARCHIVED.
- Answer-key: manifest path không chứa đáp án — không có leak vector mới.

## Post-code-review fixes + re-verify (2026-10-24)

Code-reviewer agent báo 1 BLOCKER + 4 MAJOR + nhiều MINOR. Đã fix và
chạy lại gates:

| Finding | Fix | Re-verify |
|---|---|---|
| BLOCKER `AnimationScenePublishIT.publishV2MissingSchemaVersionField_recordsOne` — test kỳ vọng missing `schemaVersion` → ghi 1, nhưng validator reject MISSING_FIELD → 422 ngay tại publish | Đổi thành `publishMissingSchemaVersionField_returns422` assert `isUnprocessableEntity` | `mvnw -Dtest=com.dauviet.animation.**.*Test` → 59/59 pass |
| MINOR `AnimationScenePublishService:117` `asInt(1)` dead-default | `asInt()` không default (validator bảo đảm field) | cùng run 59/59 |
| MAJOR admin `cameraStyle` sai thứ tự transform (`translate(d)·scale(z)` ≠ Flutter `O+z·(p−C)`) | Đổi `scale(z) translate(O−C)` — translate chạy trong không gian unscaled trước scale về origin 50% | `tsc --noEmit` 0 lỗi, vitest 158/158, lint sạch |
| MAJOR AUTO-advance `_applyStep` thiếu `previousIndex` → `onStepExit` không fire, LOOP kéo dài sang step kế | capture `prev` rồi truyền `previousIndex: prev` | `flutter test` 314/314 |
| MAJOR `hasTween` chỉ đếm targetState/camera-steps → step tracks/effects-only không forward controller | `hasTween = step.target != null \|\| _hasCinematic` | cùng run 314/314 |
| MAJOR edge stale `_tweenFrom` khi `step.target == null` trên cinematic-only | `_tweenFrom = null` trong nhánh else | cùng run 314/314 |
| MAJOR `_startLoop` race — interleave giữa các await có thể overwrite `_loopPlayer` | truyền `gen` vào, check `gen != _generation \|\| _disposed` sau mỗi await | cùng run 314/314 |
| MINOR paused-LOOP never started → `resume()` no-op | `_loopPendingBytes` + `_loopStarted`; `onResume` `play()` nếu chưa start | cùng run 314/314 |
| MINOR `_rampVolume` tick=0 khi fadeMs<8 | `clamp(16, …)` sàn 16ms/tick | cùng run 314/314 |
| MINOR `_label` TEXT/LABEL đảo | render `?` cho cả hai (glyph placeholder) | cùng run 314/314 |

Chưa fix (ghi nhận, không block): EnvironmentOverlay trong camera
transform (scene-space vs screen-space — cần product confirm); object
preview width hardcode 640px trong admin (preview-only); `_playOnce`
key `assetRef:cue` share giữa các step (giữ nguyên, comment thêm);
thiếu tests cho §10 hold-floor và §7 generation-abort (đề xuất follow-up).

## Unresolved

- `AnimationScenePublishIT` chưa chạy thật — cần Docker daemon hoặc CI.
- `docs/development-roadmap.md` / `project-changelog.md` không tồn tại trong
  repo — đánh dấu N/A (YAGNI) thay vì tạo mới.
- Bash tool trên máy local lỗi startup file (~/.bashrc line 184 quote
  chưa đóng) — subagent không chạy được shell; mọi lệnh gates trên chạy
  qua PowerShell 5.1.
