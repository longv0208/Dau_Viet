# TASK-0018 — Dau Viet Flutter Mobile: Real Learning Experience

> Module: `dau-viet-mobile` (chinh); `dau-viet-backend` (1 endpoint read-only neu duyet gap G1). Khong sua `dau-viet-admin`.
> Risk: high (auth + attempt/ownership + version pinning + idempotency).
> Research report: `../reports/research-261017-1844-task0018-flutter-contracts.md`

## Muc tieu

Journey that: Login (email/password) -> Timeline/Event -> lesson list (published) -> start/resume attempt -> Lesson Player render theo server cursor -> submit + feedback server -> complete -> result. Khong hard-code UUID/title/event. Backend la source of truth; mock mode giu nguyen qua USE_MOCK (demo only, khong gia save progress).

## Phases

| # | File | Noi dung | Status |
|---|---|---|---|
| 01 | [phase-01-contracts-data-layer.md](phase-01-contracts-data-layer.md) | DTOs + ApiClient POST/auth + token storage + auth repository + attempt-scoped content endpoint (backend, neu duyet) | done |
| 02 | [phase-02-auth-discovery-entry.md](phase-02-auth-discovery-entry.md) | Real login screen + session restore + lesson list + start/resume routing | done |
| 03 | [phase-03-lesson-player-renderers.md](phase-03-lesson-player-renderers.md) | LessonPlayer shell + renderer registry + renderers cho 12 activity types | done |
| 04 | [phase-04-submission-progression.md](phase-04-submission-progression.md) | Submit + idempotency + feedback + cursor advance + complete + result | done |
| 05 | [phase-05-media-error-mock.md](phase-05-media-error-mock.md) | Asset image fetch co auth + error mapping + mock-mode split + polish | done |
| 06 | [phase-06-tests-verification.md](phase-06-tests-verification.md) | Unit/widget tests + gates (format/analyze/test/build) + report | done |

## Dependencies

- Phase 02 can 01 (auth repo, DTOs). Phase 03 can 01 (attempt/content DTOs) + 02 (route entry). Phase 04 can 03. Phase 05 can 04. Phase 06 cuoi.
- Gap G1: version-pinned content endpoint — quyet dinh trong phase 01 (xem Open questions).

## Open questions (can xac nhan user)

1. **G1 version pinning**: `GET /lessons/{id}/content` luon tra current version; attempt pin version luc start. De xuat them `GET /api/v1/attempts/{attemptId}/content` (owner-only, read-only) + regression test. Neu khong duyet: renderer EVIDENCE_SELECT/VERIFICATION thieu evidence metadata khi attempt pin version cu.
2. **Guest mode**: USE_MOCK=false => bat buoc login, khong guest? (brief: guest = mock only)
3. **EXPLORE_MAP**: render danh sach marker don gian (khong map image) chap nhan duoc cho MVP? Neu khong -> unsupported state ro rang.

## Moi truong da verify

- Flutter 3.47.7 + Dart 3.13.5 da cai — `flutter pub get`, `dart format`, `flutter analyze`, `flutter test` chay duoc.
- Docker KHONG co tren may => Postgres + Testcontainers IT khong chay local; real-backend e2e verify ghi "NOT VERIFIED" tru khi user chay backend ngoai.
- Learner account: khong co seed — tao qua POST /auth/register khi can.
