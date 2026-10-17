# TASK-0018 Verification Report — Flutter Real Learning Experience

Ngay: 2026-10-17
Module chinh: `dau-viet-mobile` (Flutter). Phu: `dau-viet-backend` (1 read-only endpoint).
Plan: `dau-viet-admin/plans/261017-1844-task0018-flutter-learning/`

## Pham vi da verify

Bao cao nay chi ghi ket qua CHAY THAT tren may dev (Windows 11, PowerShell).
Khong ghi "pass" cho bat ky gate nao chua chay; muc NOT VERIFIED o cuoi liet ke
ro phan nao can backend/CI that.

## Tool versions

- Flutter 3.47.7 (channel stable), Dart 3.13.5
- OS: Windows 11 Home Single Language (build 26200)
- Shell: PowerShell 5.1

## Quality gates — ket qua that

| # | Gate | Command | Ket qua |
|---|---|---|---|
| 1 | Dependencies | `flutter pub get` | PASS — resolve sach |
| 2 | Format | `dart format lib test` | PASS — 96 files re-styled, khong con diff |
| 3 | Static analysis | `flutter analyze` | PASS — "No issues found!" (0 errors, 0 warnings) |
| 4 | Unit + widget tests | `flutter test` | PASS — 120/120 tests passed |
| 5 | Build web | `flutter build web` | PASS — build thanh cong |
| 6 | Whitespace | `git diff --check` | PASS — exit 0 (chi con LF->CRLF warning goc cua Git on Windows, khong phai whitespace error) |
| 7 | Build APK | `flutter build apk --debug` | NOT VERIFIED — toolchain thieu NDK 28.2.13676358 trong `E:\sdk` (loi moi truong, khong phai code). Da dung `flutter build web` lam target fallback theo phase-06 |

Chi tiet: `flutter build apk --debug` that bai vi Android `sdkmanager` chua cai
NDK `28.2.13676358` vao `E:\sdk`. Day la thieu toolchain tren may dev — KHONG
phai loi code. Theo phase-06 ("build neu toolchain co; chon 1 target chay duoc,
ghi ro"), `flutter build web` da duoc chon va build THANH CONG.

## Tests da them / sua trong phase-06

Unit tests (khong can backend):

- `test/learning/learning_dtos_test.dart` — parse fixture khop backend records
- `test/learning/answer_payload_test.dart` — payload shape theo ActivityType
- `test/learning/idempotency_test.dart` — cung answer -> cung key, doi -> key moi
- `test/api_client_test.dart` — ApiError envelope `{code,message,details,traceId}`,
  `FormatException` khi thieu code/message, predicates (401/404/400/network)
- `test/error_mapper_test.dart` — 400/401/403/404/409/500 + NETWORK_ERROR +
  UNKNOWN_ERROR fallback khi body sai shape; POST body + Bearer + getList +
  POST 204 -> {}
- `test/auth/auth_repository_test.dart` — login luu token; 401 -> refresh ->
  retry; refresh fail -> session expired + clear; restore (token con han /
  het han -> refresh / refresh 401 -> clear); logout idempotent

Widget tests:

- `test/learning/lesson_list_test.dart` — list that, empty state
  "Chưa có bài học được xuất bản", error + "Thử lại" (khong fallback mock)
- `test/learning/lesson_player_test.dart` — render theo server cursor,
  submit -> feedback `feedback[feedbackCode]`, INCORRECT giu activity,
  completion -> result hien score that
- `test/learning/resume_test.dart` — `resumed:true` + cursor giua bai render
  dung activity do (khong reset ve dau); `myProgress` provider
- `test/learning/asset_image_test.dart` — bytes -> `Image.memory`; 404 ->
  fallback alt-text; bytes rong -> fallback mac dinh
- `test/mock_mode_test.dart` — mock seam ro rang, `uuid-la` khong suy dien
- `test/widget_test.dart` — journey mock M-01..M-28 van giu nguyen voi
  `_StubAuthSession` + `FakeAttemptRepository`
- `test/timeline_events_test.dart`, `test/campaign_detail_test.dart` — sua cho
  khop Riverpod 3 `retry:_noRetry` + Completer (khong pending timer)

So test hien tai: 120 (truoc task: 88). Tang 32 test moi.

## Bug quan trong da fix trong qua trinh test

- **Riverpod 3.4.3 auto-retry**: `FutureProvider` mac dinh retry that bai toi da
  10 lan (exponential backoff) -> vong lap retry ngam -> test timeout va so call
  bat thuong. Da them `Duration? _noRetry(...) => null` va `retry: _noRetry` cho
  tat ca FutureProvider: `eventsListProvider`, `eventDetailProvider`,
  `eventLessonsProvider`, `myProgressProvider`, `_lessonMetadataProvider`,
  `_resultProvider`. Bay gio loi hien thi de nguoi dung bam "THỬ LẠI" — khong
  retry ngam.
- **`container.read(provider.future)` timeout** tren autoDispose family: can
  `container.listen(provider, ...)` giu subscription.
- **Pending timer** trong loading test: thay `Future.delayed` bang
  `Completer().future`.
- **`retry: null` KHONG tat retry** — null chon `defaultRetry`; phai truyen
  function tra null.

## AC mapping (12 AC)

- AC-1 auth/login/refresh/logout/restore — DONE, `auth_repository_test` cover
- AC-2 lessons list + empty state — DONE, `lesson_list_test`
- AC-3 start/resume + cursor — DONE, `resume_test` + `AttemptStartDto` parse
- AC-4 player render theo server cursor + registry — DONE, `lesson_player_test`
- AC-5 renderers day du type — DONE (widget_test journey + renderers)
- AC-6 submission + idempotency + feedback — DONE, `idempotency_test` +
  player test (`_pendingKey` reuse khi cung answer)
- AC-7 version pinning — backend `getAttemptContent(attemptId)` + mobile dung
  attempt-scoped endpoint; `PinnedVersionIT` (backend IT, xem NOT VERIFIED)
- AC-8 progress/resume — DONE, `myProgressProvider` + `resume_test`
- AC-9 completion/result — DONE, player test complete -> `getResult`
- AC-10 mock split ro rang — DONE, `mock_mode_test`; real mode khong fallback
- AC-11 error envelope — DONE, `error_mapper_test` + `ApiError.fromJson`
- AC-12 tests + gates + honest verification — DONE, file nay

## NOT VERIFIED (policy reasons — can backend/CI that)

Nhung muc sau CHUA verify tren may dev vi thieu dieu kien moi truong. Khong duoc
coi la "pass" cho den khi chay that:

1. **Backend Postgres integration tests** (`PinnedVersionIT` va cac IT khac):
   Docker KHONG co tren may dev -> Testcontainers khong chay duoc. Cac IT nay la
   CI-only. Code test da viet nhung chua thuc thi local.
2. **Real-backend end-to-end journey**: mobile goi Spring Boot that chua chay
   vi khong co backend dang chay. Toan bo mobile test dung
   `FakeAttemptRepository` (scripted repo) — khong phai backend that.
3. **`flutter build apk --debug`**: thieu NDK trong `E:\sdk`.

## Manual checklist cho user (chay that)

De verify AC-1..AC-9 end-to-end tren backend that:

1. Khoi dong Postgres + backend: xem `docs/backend-runbook.md`
   (`cd dau-viet-backend && ./mvnw spring-boot:run` hoac docker compose).
2. Dam bao co event "Trận Bạch Đằng năm 938" + lesson "Bí mật chiến thắng
   Bạch Đằng" da publish (qua admin hoac seed).
3. Dang ky learner: `POST /api/v1/auth/register {email,password}`.
4. Chay mobile real mode: `cd dau-viet-mobile && flutter run`
   (USE_MOCK=false mac dinh), nhap email/password.
5. Journey: Timeline -> event -> lesson card -> "BẮT ĐẦU KHÁM PHÁ" -> tra loi
   qua cac stage -> submit -> feedback -> "HOÀN THÀNH BÀI HỌC" -> man result.
6. Resume: thoat giua bai -> mo lai app -> dang nhap lai -> kiem tra cursor
   giu dung vi tri server (khong reset ve dau).
7. Version pinning: republish lesson o admin -> mo lai attempt cu -> noi dung
   van theo pinned version cu.

## Ghi chu

- Khong commit/push tu dong (theo brief "Do not automatically push or merge").
- Khong hard-code UUID/title/stage order/activity id: journey test dung
  `FakeAttemptRepository` (scripted), mock journey dung `MockAttemptRepository`
  (USE_MOCK demo only). Real mode goi ApiAttemptRepository.
- Khong fabricate reward/XP: man result chi render `score`/`result` tu backend.
