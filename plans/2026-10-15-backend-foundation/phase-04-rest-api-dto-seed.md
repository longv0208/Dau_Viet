# Phase 04 — REST API + DTO/mapper + pagination + dev seed

## Context links
- Plan: [plan.md](plan.md)
- Coding rules: `docs/CODING_RULES.md` §3 (no business logic in controller, DTO ≠ entity, constructor injection)
- API rules: `docs/CODING_RULES.md` §6 (`/api/v1` prefix, camelCase, page/size)
- Flutter contract: `dau-viet-mobile/lib/mock/models/timeline_models.dart`, `lib/mock/models/lesson_models.dart` (`HistoricalEventModel`), `lib/mock/data/mock_bach_dang_data.dart`

## Overview
- **Priority:** P1
- **Status:** completed
- **Effort:** 2.5h
- Expose `GET /api/v1/events` (paginated, PUBLISHED only) and `GET /api/v1/events/{id}` (PUBLISHED only) returning DTOs shaped for the Flutter timeline/detail mock. Ship an idempotent dev seed for Bạch Đằng 938.

## Key insights
- Flutter mock uses `id` as string `'evt_bach_dang_938'`; backend uses UUID — bridge this by including both:
  - `id` = UUID (canonical)
  - `slug` = `bach-dang-938` (URL-friendly, unique; add to schema? — **decision**: add `slug VARCHAR(150) UNIQUE` to V1 since it's needed for routing parity; OR keep slug in `tags`. Recommendation: add `slug` column — cheap, useful for stable URLs and seeding)
  - **Revised V1 addition:** `slug VARCHAR(150) NOT NULL UNIQUE` — update phase-03 migration before applying.
- Flutter needs `yearLabel` (e.g., `"Mùa Đông 938 SCN"`) — backend provides `startYear` (int) + `period` (string label) and lets client format. Detail needs `title`, `era`, `summary`, `description`, `coverAssetKey` → hero URL resolution is a future `asset` service concern; for now `coverAssetKey` is the raw storage key and the Flutter adapter resolves it to a CDN/local asset path.
- Seed only when `app.seed.enabled=true` AND profile `local` (or explicit) — never auto in `test`/`prod`. Idempotent: `findBySlug` → if exists, update; else insert with fixed UUID `00000000-0000-0000-0000-000000000001` so devs can hard-reference it in `.http` scratch files.

## Requirements
- `GET /api/v1/events?page=0&size=20&sort=startYear,asc`
  - Returns `PageResponse<HistoricalEventSummaryDto>`: `{content,page,size,totalElements,totalPages}`
  - `size` max 100 (validate via `@Max` + `@Min(1)`); out-of-range → `VALIDATION_ERROR`.
  - Only `status=PUBLISHED` rows; sorted by `startYear ASC` default.
- `GET /api/v1/events/{id}`
  - `id` must be UUID; non-UUID → 400 `MALFORMED_ID`.
  - Published row missing → 404 `EVENT_NOT_FOUND`.
  - DRAFT/ARCHIVED row → 404 `EVENT_NOT_FOUND` (do not leak existence).
- DTOs (Java records):
  ```java
  public record HistoricalEventSummaryDto(
      UUID id, String slug, String title, String era, String period,
      Integer startYear, String summary, String coverAssetKey,
      List<String> tags
  ) {}
  public record HistoricalEventDetailDto(
      UUID id, String slug, String title, String era, String period,
      Integer startYear, String summary, String description,
      String location, String coverAssetKey, List<String> tags,
      Instant publishedAt   // optional — skip to keep payload minimal
  ) {}
  ```
- `HistoricalEventMapper` — `@Component` with `toSummaryDto(HistoricalEvent)` and `toDetailDto(HistoricalEvent)`. Plain Java mapping (no MapStruct — YAGNI for two methods).
- `HistoricalEventService` — `@Service`, `@Transactional(readOnly=true)` on read methods; methods `Page<HistoricalEventSummaryDto> listPublished(Pageable)` and `HistoricalEventDetailDto getPublishedById(UUID)`.
- `HistoricalEventController` — `@RestController @RequestMapping("/api/v1/events")`; constructor-injected service; `@Validated` at class level; parameters `@Min(0) int page`, `@Min(1) @Max(100) int size`, `@RequestParam(defaultValue="startYear,asc") String sort` parsed via `Sort.Order` parser allowing only `startYear|title` fields (whitelist to prevent SQLi).
- `EventSeedRunner` — `ApplicationRunner` bean:
  - `@Profile("local")` + `@ConditionalOnProperty("app.seed.enabled", havingValue="true")`
  - Calls `seedService.upsertBachDang()` inside `@Transactional`
  - Logs `seeded event slug=bach-dang-938 id=...` once.

## Seed data — Bạch Đằng 938

```java
HistoricalEvent e = new HistoricalEvent();
e.setId(UUID.fromString("00000000-0000-0000-0000-000000000001"));
e.setSlug("bach-dang-938");
e.setTitle("Đại Chiến Bạch Đằng 938");
e.setEra("Thời Ngô - Đinh - Tiền Lê (938 - 1009)");
e.setPeriod("Mùa Đông 938 SCN");
e.setStartYear(938);
e.setSummary("Trận thủy chiến kinh điển cắm cọc gỗ lim bịt sắt lợi dụng con nước triều, tiêu diệt hoàn toàn thủy quân Nam Hán của Lưu Hoằng Tháo, chính thức chấm dứt hơn 1.000 năm Bắc thuộc.");
e.setDescription("Năm 938, Ngô Quyền lợi dụng địa thế cửa sông Bạch Đằng và quy luật thủy triều để bố trí trận địa cọc ngầm bịt sắt, nhử hạm đội Nam Hán vào trận địa rồi tiêu diệt khi nước rút. Chiến thắng mở ra kỷ nguyên độc lập lâu dài cho Việt Nam.");
e.setLocation("Cửa sông Bạch Đằng, Quảng Ninh - Hải Phòng");
e.setCoverAssetKey("events/bach-dang-938/hero.jpg");
e.setTags(List.of("ngo-quyen","thuy-chien","bac-thuoc","bach-dang"));
e.setStatus(EventStatus.PUBLISHED);
```

## Architecture

```
com.dauviet.historicalevent/
├── api/
│   ├── HistoricalEventController.java
│   ├── dto/HistoricalEventSummaryDto.java
│   ├── dto/HistoricalEventDetailDto.java
│   └── mapper/HistoricalEventMapper.java
├── application/
│   ├── HistoricalEventService.java
│   └── EventSeedService.java           # @Service, does upsert
└── infrastructure/
    └── seed/EventSeedRunner.java        # ApplicationRunner @Profile("local")
```

## Related code files
- Create: `src/main/java/com/dauviet/historicalevent/api/HistoricalEventController.java`
- Create: `src/main/java/com/dauviet/historicalevent/api/dto/HistoricalEventSummaryDto.java`
- Create: `src/main/java/com/dauviet/historicalevent/api/dto/HistoricalEventDetailDto.java`
- Create: `src/main/java/com/dauviet/historicalevent/api/mapper/HistoricalEventMapper.java`
- Create: `src/main/java/com/dauviet/historicalevent/application/HistoricalEventService.java`
- Create: `src/main/java/com/dauviet/historicalevent/application/EventSeedService.java`
- Create: `src/main/java/com/dauviet/historicalevent/infrastructure/seed/EventSeedRunner.java`
- Modify: `src/main/resources/db/migration/V1__create_historical_events.sql` — add `slug VARCHAR(150) NOT NULL UNIQUE` + index
- Modify: `src/main/java/com/dauviet/historicalevent/domain/HistoricalEvent.java` — add `slug` field

## Implementation steps
1. Update `V1__create_historical_events.sql` to include `slug VARCHAR(150) NOT NULL UNIQUE` + `CREATE UNIQUE INDEX ux_historical_events_slug`. (If V1 was already applied locally, `docker compose down -v` to wipe the volume and re-run.)
2. Add `slug` field + getter/setter to `HistoricalEvent` entity.
3. Write the two DTO records.
4. Write `HistoricalEventMapper` — pure functions entity → DTO.
5. Write `HistoricalEventService`: `listPublished(Pageable)` delegates to repo `findByStatus(PUBLISHED, pageable)`; `getPublishedById` returns `Optional` → `orElseThrow(() -> new ResourceNotFoundException("Historical event not found"))`.
6. Write `HistoricalEventController`:
   - `GET /` accepts `page`, `size`, `sort` (default `startYear,asc`); whitelists sort fields; builds `PageRequest`.
   - `GET /{id}` accepts `UUID id` — Spring auto-converts; `MethodArgumentTypeMismatchException` is already mapped to `MALFORMED_ID` in phase-02's handler (add explicit branch).
7. Write `EventSeedService.upsertBachDang()`: `repository.findBySlug("bach-dang-938").ifPresentOrElse(update fields, insert new)` inside `@Transactional`.
8. Write `EventSeedRunner` implementing `ApplicationRunner`, `@Profile("local")`, `@ConditionalOnProperty("app.seed.enabled")`.
9. Boot under `local` profile; verify `GET http://localhost:8080/api/v1/events` returns the Bach Dang event; `GET /api/v1/events/00000000-0000-0000-0000-000000000001` returns detail; `GET /api/v1/events/99999999-9999-9999-9999-999999999999` returns 404 JSON.

## Todo checklist
- [ ] `slug` column + unique index in V1
- [ ] `GET /api/v1/events` returns only PUBLISHED, pageable
- [ ] `GET /api/v1/events/{id}` returns detail, 404 on non-published or missing
- [ ] `GET /api/v1/events/not-a-uuid` returns 400 `MALFORMED_ID`
- [ ] Sort whitelist rejects `?sort=;drop table` (validation error)
- [ ] `size>100` rejected with `VALIDATION_ERROR`
- [ ] Dev seed upserts Bach Dang idempotently under `local` profile only
- [ ] No event-specific `if` in controller/service — seed lives in dedicated seed service

## Success criteria
- `curl http://localhost:8080/api/v1/events` → `200 {content:[{id,slug:"bach-dang-938",...}],page:0,...}`
- `curl http://localhost:8080/api/v1/events/00000000-0000-0000-0000-000000000001` → detail JSON
- Second run of `EventSeedRunner` does NOT produce a duplicate row (`SELECT count(*) WHERE slug='bach-dang-938'` = 1)

## Risk assessment
- Adding `slug` after V1 applied → wipe volume & re-migrate (dev only).
- Sort whitelist — implement `Set<String> ALLOWED_SORT_FIELDS = {"startYear","title"}` and reject others with `VALIDATION_ERROR`.

## Security considerations
- Sort field whitelist prevents JPA path-injection / SQL errors.
- `size` capped at 100 to prevent memory/DoS.
- Seed runs only under `local` profile — production never auto-seeds.

## Next steps
- Phase 05 — tests + Flutter contract note.
