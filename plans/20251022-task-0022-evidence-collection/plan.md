---
title: "TASK-0022 — Historical Evidence Collection (GET /me/collection + Flutter UI)"
status: pending
priority: P1
created: 2026-10-22
---

# TASK-0022 — Historical Evidence Collection

## Context

`user_evidence` (V4) tồn tại nhưng chưa có writer/reader. Brief yêu cầu:
(1) ghi row khi `EVIDENCE_SELECT` submit `completed=true`,
(2) trả metadata snapshot ổn định ngay cả khi admin archive/edit evidence gốc,
(3) API list + detail phân trang, filter theo `type`/`eventId`,
(4) Flutter màn hình Bộ sưu tập + detail + dashboard entry.

## Review phân tích — đồng ý / phản đối

| Quyết định trong phân tích | Đánh giá | Ghi chú |
|---|---|---|
| (b) `snapshot_json` trong user_evidence | DONG Y | Cách duy nhất giữ metadata sau khi admin archive/edit `evidences`. Đọc từ pinned snapshot qua join attempt->version->json scan phức tạp và vẫn phải rebuild `evidence[]` shape. +1 cột rẻ. |
| `UNIQUE(user_id, evidence_id)` | DONG Y | Dedup cross-attempt. Bắt buộc kèm ON CONFLICT DO NOTHING. |
| Native upsert `INSERT ... ON CONFLICT` | DONG Y | Đơn giản, chạy trong tx hiện tại, idempotent tự nhiên. Không cần custom repo impl. |
| Trigger tại submit time khi `result.completed()==true` | DONG Y | "Accept" = handler completed + persist. Cùng tx với `activity_attempts.save` -> rollback gộp. Idempotent-Key replay không vào `doSubmit` lần 2 → không duplicate. |
| Không thêm `collected` vào `SubmitActivityResponse` | DONG Y | UI không toast; collection là read-side riêng. |
| Thêm cột `evidence_type` | DONG Y | Filter `?type=` hiệu quả, tránh jsonb path scan. |
| Optional EVIDENCE_SELECT vẫn collect | DONG Y | Brief không giới hạn required; optional submit vẫn đi qua `doSubmit`. |

### Điều chỉnh phân tích

1. `snapshot_json` shape: phân tích đề xuất `{"evidence":{...},"lessonId","lessonTitle","eventId"}` — DONG Y nhưng bỏ `eventTitle` (resolve qua `HistoricalEventRepository.findAllById` batch cho list page, tránh snapshot lưu thông tin có thể stale khi admin đổi event title).
2. `lessonVersionId` trong snapshot_json: nên giữ — debug + trace pinned version về sau nếu cần; đã có sẵn tại collect time.
3. ErrorCode: KHÔNG có code nào phù hợp (`NOT_FOUND` quá generic, `EVIDENCE_NOT_FOUND` sai ngữ nghĩa — đây là collection item, không phải evidence entity). Thêm `COLLECTION_ITEM_NOT_FOUND` vào `ErrorCode` + handler mới `CollectedEvidenceNotFoundException` → 404. Đặt trong package `learning.domain` theo convention `AttemptNotFoundException`.
4. `@Modifying` native query hoạt động tốt trong Spring Data JPA kèm `@Transactional` (service đã có tx). Cần `clearAutomatically = false` mặc định để không flush mọi pending entity sớm — KISS: dùng `@Modifying @Query(nativeQuery)` thường, tx ở service lo commit/rollback.

## Schema — V10 migration

```sql
ALTER TABLE user_evidence
    ADD COLUMN snapshot_json JSONB,
    ADD COLUMN evidence_type VARCHAR(48);
ALTER TABLE user_evidence
    ADD CONSTRAINT ux_user_evidence_user_evidence UNIQUE (user_id, evidence_id);
```

- `snapshot_json` nullable lúc add column (existing rows = 0 trong production vì feature mới); set `NOT NULL` khi insert từ code, không cần backfill.
- Index `idx_user_evidence_user(user_id, collected_at DESC)` đã có — list query dùng luôn.

## File list

### Backend — create

- `dau-viet-backend/src/main/resources/db/migration/V10__user_evidence_collection.sql`
- `dau-viet-backend/src/main/java/com/dauviet/learning/domain/UserEvidence.java` — JPA entity
- `dau-viet-backend/src/main/java/com/dauviet/learning/domain/CollectedEvidenceNotFoundException.java`
- `dau-viet-backend/src/main/java/com/dauviet/learning/infrastructure/persistence/UserEvidenceRepository.java` — JpaRepository + native upsert + list/detail queries
- `dau-viet-backend/src/main/java/com/dauviet/learning/application/EvidenceCollector.java` — nhỏ, nhận (userId, attemptId, model, selectedIds) → upsert
- `dau-viet-backend/src/main/java/com/dauviet/learning/application/CollectionService.java` — read-only list + detail + DTO mapping
- `dau-viet-backend/src/main/java/com/dauviet/learning/api/CollectionController.java` — `GET /api/v1/me/collection`, `GET /api/v1/me/collection/{evidenceId}`
- `dau-viet-backend/src/main/java/com/dauviet/learning/api/dto/CollectionItemDto.java` — record `{evidenceId, title, evidenceType, description, source{title,author,url,citation,publishedAt}, assetId, eventId, eventTitle, lessonId, lessonTitle, collectedAt}` (list trả subset cùng record, field không dùng = null)
- `dau-viet-backend/src/test/java/com/dauviet/learning/CollectionIT.java`

### Backend — modify

- `dau-viet-backend/src/main/java/com/dauviet/learning/application/LearnerAttemptService.java` — inject `EvidenceCollector`; trong `doSubmit` sau `activityAttempts.save` + `state.recordOutput`: nếu `type==EVIDENCE_SELECT && result.completed()` → collector.collect(userId, a.getId(), model, answer.get("selectedEvidenceIds"))
- `dau-viet-backend/src/main/java/com/dauviet/common/error/ErrorCode.java` — thêm `COLLECTION_ITEM_NOT_FOUND`
- `dau-viet-backend/src/main/java/com/dauviet/common/error/GlobalExceptionHandler.java` — map exception mới → 404
- `docs/API_SPEC.md` — cập nhật row `/me/collection` + response shape + `COLLECTION_ITEM_NOT_FOUND`

### Mobile — create

- `dau-viet-mobile/lib/features/collection/data/collection_dto.dart` — `CollectionItemDto`, `CollectionPageDto`
- `dau-viet-mobile/lib/features/collection/data/collection_repository.dart` — `Future<CollectionPageDto> list({String? type, String? eventId, int page, int size})`, `Future<CollectionItemDto> detail(String evidenceId)`
- `dau-viet-mobile/lib/features/collection/data/collection_api_client.dart`
- `dau-viet-mobile/lib/features/collection/data/api_collection_repository.dart`
- `dau-viet-mobile/lib/features/collection/data/mock_collection_repository.dart`
- `dau-viet-mobile/lib/features/collection/data/collection_providers.dart` — `collectionRepositoryProvider`, `collectionListProvider` (AsyncNotifier family theo filter, watch `authSessionProvider` giống `_mapSessionKey`), `collectionDetailProvider` family
- `dau-viet-mobile/lib/features/collection/presentation/collection_screen.dart` — filter chips + grid + RefreshIndicator + "Tải thêm" + empty/error state
- `dau-viet-mobile/lib/features/collection/presentation/collection_detail_screen.dart`
- `dau-viet-mobile/test/collection/collection_screen_test.dart`
- `dau-viet-mobile/test/collection/collection_detail_test.dart`

### Mobile — modify

- `dau-viet-mobile/lib/app/router.dart` — thêm `/collection`, `/collection/:evidenceId`; thêm `/collection` vào `_learningPrefixes`
- `dau-viet-mobile/lib/features/dashboard/presentation/learner_dashboard_screen.dart` — `_buildQuickShortcuts` thêm card thứ 4 `Bộ Sưu Tập` → `/collection`
- `dau-viet-mobile/lib/features/learning/presentation/lesson_player_screen.dart` — sau complete-ack invalidate `collectionListProvider`

## Implementation steps

1. **V10 migration** — add `snapshot_json`, `evidence_type`, `UNIQUE(user_id, evidence_id)`.
2. **UserEvidence entity** — `@Entity @Table(name="user_evidence")`, fields `id, userId, learnerAttemptId, evidenceId, snapshotJson(String via @JdbcTypeCode(JSON)), evidenceType, collectedAt`.
3. **UserEvidenceRepository** —
   - `Page<UserEvidence> findByUserIdOrderByCollectedAtDesc(UUID userId, Pageable)`
   - `Page<UserEvidence> findByUserIdAndEvidenceTypeOrderByCollectedAtDesc(UUID userId, String type, Pageable)`
   - `Optional<UserEvidence> findByUserIdAndEvidenceId(UUID userId, UUID evidenceId)`
   - `@Modifying @Query(value="INSERT INTO user_evidence (id,user_id,learner_attempt_id,evidence_id,evidence_type,snapshot_json,collected_at) VALUES (:id,:userId,:attemptId,:evidenceId,:type,CAST(:snapshotJson AS jsonb),now()) ON CONFLICT (user_id,evidence_id) DO NOTHING", nativeQuery=true) int upsert(...)`
4. **EvidenceCollector** — cho mỗi `selectedEvidenceIds` (đã được handler validate trong snapshot + visible set):
   - `JsonNode ev = model.evidenceById(id)` → build `ObjectNode {"evidence":ev.deepCopy(),"lessonId","lessonTitle","lessonVersionId","eventId"}` (lấy `lessonId`/`title` từ `model.root()`, `eventId` từ `ev.eventId`).
   - `evidenceType` = `ev.path("evidenceType").asText()`.
   - Gọi `userEvidenceRepository.upsert(...)`. `int` return không dùng — idempotent theo UNIQUE.
5. **Wire vào `doSubmit`** — sau `activityAttempts.save(...)`, trước `attempts.save(a)`:
   ```java
   if (type == ActivityType.EVIDENCE_SELECT && result.completed()) {
       evidenceCollector.collect(userId, a.getId(), model,
               answer == null ? null : answer.get("selectedEvidenceIds"));
   }
   ```
   Bọc try/catch `DataAccessException` → rethrow làm `SnapshotCorruptException`? KHÔNG — để propagate tự nhiên, tx rollback, submit retry sau. Không nuốt lỗi.
6. **CollectionService** —
   - `list(UUID userId, String type, String eventId, Pageable)` → `PageResponse<CollectionItemDto>`; parse `snapshot_json` → map record; batch fetch `eventTitle` cho page (collect `eventId` set → `historicalEventRepository.findAllById` → map).
   - `detail(UUID userId, UUID evidenceId)` → `findByUserIdAndEvidenceId` else `CollectedEvidenceNotFoundException`; trả đầy đủ (kể `description`, `source`, `lessonTitle`).
   - Filter `eventId` = field trong `snapshot_json` → query `WHERE ue.snapshot_json->>'eventId' = :eventId` (jsonb path) hoặc đơn giản hơn **đưa `event_id` thành cột riêng trong V10** nếu filter này được dùng thường xuyên. ĐỀ XUẤT: thêm `event_id UUID` vào V10 (rẻ, index được). Cập nhật migration: `ADD COLUMN event_id UUID REFERENCES historical_events(id)` + `CREATE INDEX idx_user_evidence_event ON user_evidence(user_id, event_id)` — sau đó filter `eventId` đơn giản.
7. **CollectionController** — theo `LearnerAttemptController` pattern (`JwtSubjectExtractor`, `PageRequest.of(page, min(size,50))`).
8. **ErrorCode + handler** — `COLLECTION_ITEM_NOT_FOUND` → 404.
9. **Flutter data layer** — theo `map_*` pattern: api client dùng `apiClientProvider` + `withAuth`, repo impl chọn mock/api qua `ApiConfig.useMock`.
10. **Flutter providers** — `collectionListProvider = AsyncNotifierProvider.autoDispose.family<CollectionListController, Filter, CollectionPageDto>`? KISS: dùng `FutureProvider.family` trả page đầu + `collectionDetailProvider.family`. Pagination "Tải thêm" → `StateNotifier<List<CollectionItemDto>>` hoặc `AsyncNotifier` accumulate. Chọn `AsyncNotifierProvider.autoDispose.family` với method `loadMore()` tích luỹ items; autoDispose cho session isolation gọn.
11. **UI** — `collection_screen.dart` grid 2 cột responsive; `collection_detail_screen.dart` với `LearningAssetImage`.
12. **Router + dashboard** — thêm routes, thêm `/collection` prefix auth guard, thêm shortcut card.
13. **Invalidate sau lesson complete** — `ref.invalidate(collectionListProvider)` trong `_complete()` ack path.
14. **Tests** — backend `CollectionIT` (xem Test plan); mobile widget tests.
15. **Docs** — update `docs/API_SPEC.md` row 60 + Notes đã chốt TASK-0022 + response shape; `docs/DATABASE_DESIGN.md` nếu schema section mô tả `user_evidence`.

## Test plan

### Backend `CollectionIT` extends `AbstractPostgresIT` + `AttemptItFixture`

1. `submitEvidenceSelectCollectsRows` — publish draft `draftWithOptional` (es-opt optional), start attempt, submit es-opt với `selectedEvidenceIds:[evId]` + `Idempotency-Key` → `user_evidence` có 1 row với đúng `snapshot_json.evidence.id`, `evidence_type`, `event_id`.
2. `submitReplayDoesNotDuplicate` — cùng `Idempotency-Key` → vẫn 1 row.
3. `submitInvalidEvidenceIdRejected400` — id không trong snapshot → 400 (handler sẵn), `user_evidence` trống.
4. `listOnlyOwnCollection` — learner A collect; learner B `GET /me/collection` → `content` empty.
5. `repeatedAttemptDoesNotDuplicate` — submit es-opt, complete attempt, attempt mới (republish) cùng evidence → `GET /me/collection` size = 1.
6. `detailSurvivesSourceArchive` — collect → `jdbc.update("update evidences set status='ARCHIVED', title='X' where id=?", evId)` → `GET /me/collection/{evId}` → 200, `title` = giá trị gốc trong snapshot_json.
7. `paginationAndTypeFilter` — seed ≥2 evidence types, collect 3+ → `?type=DOC` lọc đúng, `?size=1&page=1` page 2.
8. `detailNotFoundWhenNotCollected` — `GET /me/collection/{randomId}` → 404 `COLLECTION_ITEM_NOT_FOUND`.
9. `unauthenticated401` — no JWT → 401.

### Mobile widget tests

- `collection_screen_test.dart` — ProviderScope override `collectionRepositoryProvider` fake → render cards, filter chips, empty state "Chưa có bằng chứng", error + retry, load-more hiện khi `totalPages>1`.
- `collection_detail_test.dart` — detail render title/description/source; 404 → error state.

## Risks

1. **`snapshot_json` nullable trên rows cũ** — feature mới, không có rows cũ trong production; không cần backfill nhưng code parse phải chịu `null` (defensive return `objectNode()`).
2. **`evidence_id` trong `user_evidence` trỏ `evidences(id)`** — admin KHÔNG được hard-delete evidence (đã chặn bởi EVIDENCE_IN_USE) nên FK an toàn; archive vẫn giữ row → FK ổn.
3. **Submit es-opt optional sau khi cursor đã qua stage** — `doSubmit` vẫn vào nhánh `optionalInStage` → collector chạy được (đúng mong đợi).
4. **`ON CONFLICT` + `@Modifying` trong JPA** — hoạt động tốt vì service tx bao ngoài; KHÔNG dùng `clearAutomatically=true` (flush sớm entities khác).
5. **`event_id` filter** — nếu giữ jsonb path query sẽ chậm khi collection lớn → plan đã đổi thành cột riêng trong V10.
6. **UX "Đã lưu vào bộ sưu tập"** — không implement toast/badge (submit response không mang info) — nếu BA muốn hiển thị, cần mở rộng `SubmitActivityResponse` (out of scope).
7. **Attempt ở version khác cùng lesson** — upsert đảm bảo chỉ 1 row per (user, evidence); `learner_attempt_id` trỏ attempt gần nhất trigger — chấp nhận vì `ON CONFLICT DO NOTHING` giữ attempt_id đầu tiên (không update). Đây là trade-off: detail vẫn đúng, chỉ "first collected in attempt X" là semantics.
8. **Mock repo drift** — `MockCollectionRepository` phải hỗ trợ `page`/`size`/`type` filter để test pagination path; không fallback mock khi real lỗi.

## Open questions

- `eventId` filter param cho `/me/collection` — brief liệt kê `type?` và `eventId?`; nếu BA chỉ cần `type`, có thể bỏ cột `event_id` khỏi V10. Giữ lại trong plan vì filter event là use case hợp lý cho Collection screen.
- `lessonTitle`/`eventTitle` có cần trong LIST response không — plan đưa vào detail chỉ; list item chỉ có `eventTitle` (để hiển thị chip sự kiện trên card), `lessonTitle` ẩn.
