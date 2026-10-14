# Backend — Flutter contract notes

> **Consumed by TASK-0006** (`dau-viet-mobile`): §1 payload →
> `HistoricalEvent{Summary,Detail}Dto`, §2 delta → `EventModelAdapter`,
> §3 decisions → `ApiClient`/`EventsApiClient`/`AssetResolver`/`USE_MOCK`.
> Written during TASK-0005. Compares the real `GET /api/v1/events` payload with
> the current `dau-viet-mobile/lib/mock` models. **No Flutter refactor in this
> task** — this document is the input for the next mobile-integration task.

## 1. Verified API shape

`GET http://localhost:8080/api/v1/events` (200, paginated):

```json
{
  "content": [
    {
      "id": "00000000-0000-0000-0000-000000000001",
      "slug": "bach-dang-938",
      "title": "Đại Chiến Bạch Đằng 938",
      "era": "Thời Ngô - Đinh - Tiền Lê (938 - 1009)",
      "period": "Mùa Đông 938 SCN",
      "startYear": 938,
      "summary": "Trận thủy chiến kinh điển ...",
      "coverAssetKey": "events/bach-dang-938/hero.jpg",
      "tags": ["ngo-quyen","thuy-chien","bac-thuoc","bach-dang"]
    }
  ],
  "page": 0,
  "size": 20,
  "totalElements": 1,
  "totalPages": 1
}
```

`GET /api/v1/events/{id}` adds `description`, `location`, `publishedAt`.

Errors use `{code, message, details, traceId}` with HTTP 400/401/404/405/500.

## 2. Field-by-field delta vs Flutter mocks

| Backend field | Flutter `TimelineMilestoneModel` | Flutter `HistoricalEventModel` | Action for next task |
|---|---|---|---|
| `id` (UUID) | `id` (string like `'ms_bach_dang_938'`) | `id` (`'evt_bach_dang_938'`) | Replace synthetic ids with backend UUID string; keep `slug` as fallback display id. |
| `slug` | — | — | New field; use for route/deep-link segments. |
| `title` | `title` | `title` | Direct map. |
| `era` | `era` | `era` | Direct map. |
| `period` | `yearLabel` | — | Direct map (rename semantic: backend `period` = UI `yearLabel`). |
| `startYear` | `yearValue` | `year` | Direct map. |
| `summary` | `description` | `summary` | Map backend `summary` → timeline `description` AND detail `summary`. |
| `description` | — | — | Long-form text for future detail screen; not used by Timeline today. |
| `location` | — | — | New; reserve for detail screen / maps. |
| `coverAssetKey` | — | `heroBannerUrl` | Client resolves `coverAssetKey` → asset path/URL via adapter (e.g. `assets/images/${slug}/hero.jpg` or future asset service). |
| `tags` | `badgeText` (loosely) | — | No direct match — derive badge label from tags or keep UI-only string. |
| `status` (implicit) | `isActive` | — | Backend only returns `PUBLISHED`; `isActive` can be `id != null` on client. |
| — | `subtitle` | — | No backend equivalent; derive from `title`/`period` client-side, or extend DTO in a future task. |
| — | `eventId` | `eventId` | Equals backend `id` once the app switches to real data. |
| — | — | `lessonIds` | Out of scope — will be served by `lessons` endpoint in a later task. |

## 3. Decisions for the Flutter integration task

1. Introduce a `EventsApiClient` (Dio) reading base URL from `--dart-define=API_BASE_URL`.
2. Map `HistoricalEventSummaryDto` → `TimelineMilestoneModel` inside a dedicated adapter; keep Timeline UI unchanged.
3. Keep `lib/mock` usable behind a `USE_MOCK` flag so offline/dev runs still work.
4. `coverAssetKey` → resolved via `AssetResolver` so the storage backend can change later without touching UI.
5. Add `slug` to route parameters for human-readable deep links (`/event/bach-dang-938`).
6. Error model maps to a Flutter `ApiException` with `code` switch for UX-specific copy.

## 4. Dev seed reference

- Seed row id: `00000000-0000-0000-0000-000000000001`, slug `bach-dang-938` — safe to hard-code in local Flutter `.env` while mocking.
- Seed only runs under `spring.profiles.active=local` + `app.seed.enabled=true`.
