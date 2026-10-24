# Phase 04 — Flutter Dossier UI + Event Progress

## Context Links

- Brief sections 14 (collection tabs), 15 (event progress), 16 (post-completion flow).
- Existing: `lib/features/collection/` (dto/providers/repository/api_client/screens), `lib/features/campaign/presentation/campaign_detail_screen.dart` (uses `eventDetailProvider`, `LessonListSection`), `lib/app/router.dart` (`/collection` + `/collection/:evidenceId` ordering), `lib/features/learning/` (result screen — completion exit point).
- Design: `design/MOBILE_SCREEN_DESIGN.md`, `design/UI_COMPONENT_SPEC.md` (paper/Dong Son palette).

## Overview

- Priority: P1.
- Status: pending.
- Extend collection feature with dossier list/detail; add event progress section to campaign detail; refresh providers after lesson completion.

## Key Insights

- Router: `/collection/dossiers/:dossierId` MUST be registered BEFORE `/collection/:evidenceId` in GoRoute list (GoRouter matches in order; `:evidenceId` would swallow `dossiers`).
- Providers: reuse session-key + `withAuth` + `_noRetry` + AsyncNotifier family pattern from `collection_providers.dart`; add parallel `dossierListProvider` family keyed by `DossierFilter` record {type, eventId?, unlocked?} — keep evidence family untouched.
- Tabs: top-level `TabBar`/segmented control in `collection_screen.dart` — "Dau" (existing evidence UI) + "Nhan vat" (PERSON) + "Dia diem" (LOCATION) + "Hien vat" (ARTIFACT); CONTEXT tab omitted until data exists (YAGNI).
- Campaign detail: new `EventProgressSection` widget under hero/metadata, before `LessonListSection`; watches `eventProgressProvider(eventId)`; states: NOT_CONFIGURED -> neutral text (khong gia lap hoan thanh); IN_PROGRESS -> "Hoan thanh x/y bai bat buoc" + LinearProgressIndicator; COMPLETED/MASTERED -> "Da hoan thanh su kien" + mastered chip + "Da mo khoa N ho so" + CTA "Xem bo suu tap" -> `/collection?tab=...`.
- Newly-unlocked cue: only when `CompleteAttemptResponse.newlyUnlockedDossiers` non-empty on THIS completion (field additive phase 3); after `lesson_result_screen` mount or completion navigation, show one SnackBar/banner "Da mo khoa N ho so lich su" -> tap opens collection. Never re-show on reopen (result replay returns empty list server-side).
- Refresh: after lesson completion (result screen init or pop), `ref.invalidate(eventProgressProvider(eventId))` + invalidate dossier list family — simplest hook: in `lesson_result_screen` when `newlyUnlockedDossiers.isNotEmpty || result.completed`, invalidate progress + dossier providers.

## Requirements

Data layer:
- `dossier_dto.dart` — `DossierSummaryDto`, `DossierDetailDto`, `DossierSourceDto`, `DossierPageDto` mirroring backend contract; `EventProgressDto` + `RequiredLessonProgressDto` in `event_progress_dto.dart`.
- `collection_api_client.dart` (edit): `listDossiers({type,eventId,unlocked,page,size})`, `dossierDetail(id)`; new `event_api_client` addition or reuse existing events client — check `features/events/data/` for client home; progress call `GET /me/events/{id}/progress` belongs near events or collection — put method in `collection_api_client` is wrong module-wise; create `event_progress` call inside existing events api client file if present, else add to `collection_api_client` pragmatically and note. (Verify events client file exists — `features/events/data/events_providers.dart` seen in imports; locate its client.)
- `collection_repository.dart` (edit): add abstract dossier methods; implement in `api_collection_repository.dart` and `mock_collection_repository.dart` (mock returns small deterministic set incl. locked + unlocked so UI states testable; mark clearly as demo data — brief forbids mock shown as real only when mock mode off).

Providers (`collection_providers.dart` edit or new `dossier_providers.dart` — prefer new file, keep files <200 lines):
- `dossierListProvider` AsyncNotifier family `DossierFilter` with same list-state shape (items/nextPage/hasMore/isLoadingMore/loadMoreError) — copy pattern, no abstraction overkill (DRY via shared state class `PagedListState<T>`? KISS: reuse `CollectionListState` generalized is a refactor of working code — instead create `DossierListState` mirroring it; acceptable duplication vs refactor risk. Alternative: generalize. Choose: extract tiny generic `PagedListState<T>` only if trivial; else duplicate — note decision in file comment.)
- `dossierDetailProvider` family by dossierId.
- `eventProgressProvider` family by eventId (FutureProvider.autoDispose, retry:_noRetry, session-aware).

UI:
- `collection_screen.dart` edit: wrap existing body in `DefaultTabController` (4 tabs); tab 1 = existing evidence content; tabs 2-4 = new `DossierTabView(dossierType)` widget.
- `presentation/dossier_card.dart` — locked (lock icon + preview text + "Hoan thanh su kien X de mo") / unlocked (title + type chip + granted date) states.
- `presentation/dossier_detail_screen.dart` — title, type chip, detail description, source citation block, asset image placeholder only when assetId non-null, grantedAt + unlock event; locked preview variant shows preview + requirement text + no detail.
- `presentation/dossier_tab_view.dart` — paged list + load-more + states: loading spinner, error banner+retry, empty ("Chua co ho so", "Su kien chua cau hinh bo suu tap" when eventId filter set and zero, "Chua hoan thanh su kien" when all locked).
- `campaign_detail_screen.dart` edit: add `EventProgressSection` widget (new file `presentation/widgets/event_progress_section.dart`).
- `router.dart` edit: insert `GoRoute('/collection/dossiers/:dossierId', ...)` BEFORE `/collection/:evidenceId` route; builder -> `DossierDetailScreen(dossierId:)`.
- `lesson_result_screen.dart` edit: after load, invalidate `eventProgressProvider` + dossier providers; SnackBar cue when `newlyUnlockedDossiers` non-empty — requires `LessonResultDto` gains the additive field (edit its fromJson; null-safe).

States must distinguish: empty catalog vs event-unconfigured vs locked-only vs filter-empty vs error vs loading (brief 14.3/15).

## Architecture

Mirror evidence feature structure; no new architecture. Mock/real switch preserved.

## Related Code Files

Create:
- `lib/features/collection/data/dossier_dto.dart`
- `lib/features/collection/data/event_progress_dto.dart`
- `lib/features/collection/data/dossier_providers.dart`
- `lib/features/collection/presentation/dossier_card.dart`
- `lib/features/collection/presentation/dossier_tab_view.dart`
- `lib/features/collection/presentation/dossier_detail_screen.dart`
- `lib/features/campaign/presentation/widgets/event_progress_section.dart`

Modify:
- `lib/features/collection/data/collection_api_client.dart` (+dossier methods; progress method placement — verify events client first)
- `lib/features/collection/data/collection_repository.dart`, `api_collection_repository.dart`, `mock_collection_repository.dart`
- `lib/features/collection/presentation/collection_screen.dart` (tabs)
- `lib/features/campaign/presentation/campaign_detail_screen.dart` (progress section)
- `lib/features/learning/.../lesson_result_screen.dart` + result dto (verify exact path at impl time)
- `lib/app/router.dart` (route ordering)

## Implementation Steps

1. DTOs from API contract (phase 3 shapes); null-safe parse; unit-testable.
2. Api client methods; repository interface + both impls.
3. Providers (dossier list family + detail + progress).
4. `collection_screen` tabs restructure — keep evidence tab body byte-similar.
5. Card + tab view + detail screen.
6. Campaign detail progress section.
7. Router insert + result-screen refresh/cue wiring.
8. `dart format lib test && flutter analyze` clean.

## Todo List

- [ ] Dossier + progress DTOs
- [ ] Api client + repository (real + mock)
- [ ] dossier_providers.dart (list family, detail, progress)
- [ ] collection_screen 4-tab restructure
- [ ] dossier_card / dossier_tab_view / dossier_detail_screen
- [ ] event_progress_section in campaign detail
- [ ] router ordering fix
- [ ] result screen refresh + newly-unlocked cue
- [ ] format + analyze clean

## Success Criteria

- Tabs render; evidence tab unchanged; dossier tabs paginate.
- Locked dossier shows preview/lock; unlocked opens detail with citation.
- Campaign detail shows real counts (e.g., "Hoan thanh 2/3 bai bat buoc"); NOT_CONFIGURED neutral.
- After completing final lesson, collection invalidates; cue appears once.
- `/collection/dossiers/x` opens dossier, `/collection/y` still opens evidence.

## Risk Assessment

- GoRoute ordering regression — test navigation both routes.
- Provider family filter record equality — use `record` type or equatable-simple class; ensure stable hashCode.
- Mock repo divergence — keep mock minimal; never default to mock.
- Invalidating whole dossier family: `ref.invalidate(dossierListProvider)` without args invalidates all family instances — acceptable breadth.

## Security Considerations

- No client-side unlock; all state from API.
- Session-key providers prevent cross-account leak on logout/login.

## Next Steps

- Phase 5 widget tests; phase 6 docs.
