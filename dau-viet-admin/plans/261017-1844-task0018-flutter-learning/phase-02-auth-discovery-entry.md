# Phase 02 — Auth that + Discovery + Lesson Entry (start/resume)

## Context links

- Phase 01 outputs (auth repo, learning api client, providers)
- `design/MOBILE_SCREEN_DESIGN.md` M-02 (auth), M-03 (dashboard), M-07 (campaign detail)
- `lib/features/auth/presentation/{auth_screen,splash_screen}.dart`, `lib/app/router.dart`
- `lib/features/campaign/presentation/campaign_detail_screen.dart`, `lib/features/events/data/*`

## Overview

- Priority: P0
- Status: pending
- Journey: Splash (session restore) -> Auth (email/password real; Google/EduID marked unavailable; Guest = mock only) -> Timeline/Campaign -> Lesson list -> Start/Resume -> `/learning/attempt/:id`.

## Key insights

- `AuthScreen` hien la mock: ca 3 nut deu `context.go('/dashboard')`. Can form email/password + state dang nhap; Google/EduID giu nut nhung `onPressed` disabled + label "Sắp ra mắt" (KHONG fake navigate).
- Guest mode: `USE_MOCK=true` → cho phep "Vao Hoc Ngay (Che do Khach)" vao demo mock. `USE_MOCK=false` → nut guest an/disabled, bat buoc login (per brief; xac nhan Open Q2).
- Splash hien `Timer(2.5s) → /auth`. Thay bang: splash anim xong + `authRepository.restore()` → authed ? `/dashboard` : `/auth`.
- `CampaignDetailScreen` da fetch event that qua `eventDetailProvider`; phan lesson dang dung `MockBachDangData.lessonEpisode2` → thay bang `GET /events/{eventId}/lessons` + empty state "Chưa có bài học được xuất bản".
- `GET /events/{id}/lessons` + `/lessons/*` can auth → Campaign detail da co Bearer qua ApiClient.
- Start/resume: `POST /lessons/{lessonId}/attempts` (body `{}`) tra `resumed` + cursor → navigate `/learning/attempt/{attemptId}`; truyen kem `lessonId`/`lessonTitle` qua extra de player co context khong hard-code.

## Requirements

- Login form: email + password, validation toi thieu, hien thi loi tu `INVALID_CREDENTIALS` (401) va network; nut dang nhap disable khi pending.
- Register link/don gian (optional neu brief khong yeu cau — backend co `/auth/register`; them neu phi thap, nguoc lai chi login + note).
- Guest: chi khi `ApiConfig.useMock == true`.
- Session restore: splash -> restore -> route; logout tu dashboard (them entry nho trong dashboard/profile, giu don gian).
- Lesson list trong campaign detail (hoac man rieng `/learning/lesson/:lessonId` theo brief — chon 1: hien thi list trong campaign, tap → lesson entry screen goi `GET /lessons/{id}` metadata + nut "Bat dau/Tiep tuc").
- Start/resume: POST attempts → `/learning/attempt/{attemptId}` voi `resumed` banner nho khi true.
- Router moi: `/learning/lesson/:lessonId` (entry), `/learning/attempt/:attemptId` (player shell — phase 03 dat widget vao).

## Architecture

```
features/auth/presentation/auth_screen.dart    real form + guest/mock gates
features/auth/presentation/splash_screen.dart  restore-aware redirect
features/auth/data/auth_providers.dart         authStateProvider (unknown/authed/guest)
features/learning/presentation/lesson_entry_screen.dart   metadata + start/resume CTA
features/learning/presentation/lesson_list_section.dart   trong campaign detail
app/router.dart                                + 2 routes + redirect guard
```

Redirect guard (go_router `redirect`): `USE_MOCK=false` va !authed → `/auth` khi vao /dashboard,/learning/*,/timeline,/campaign; `/auth` khi authed → `/dashboard`. USE_MOCK=true: khong guard (demo).

## Related code files

Modify:
- `lib/app/router.dart` (routes + redirect)
- `lib/features/auth/presentation/auth_screen.dart`
- `lib/features/auth/presentation/splash_screen.dart`
- `lib/features/campaign/presentation/campaign_detail_screen.dart` (lesson list that)
- `lib/features/dashboard/presentation/learner_dashboard_screen.dart` (resume card → GET /me/progress neu authed; logout entry)

Create:
- `lib/features/auth/data/auth_providers.dart`
- `lib/features/learning/presentation/lesson_entry_screen.dart`
- `lib/features/learning/presentation/lesson_list_section.dart`
- `lib/features/learning/presentation/lesson_player_screen.dart` (shell rong cho phase 03 — route dat san)

## Implementation steps

1. `auth_providers.dart`: `authStateProvider` (AsyncValue<AuthState>), wrap repo login/logout/restore; guest state khi USE_MOCK.
2. Router: them 2 routes; redirect theo authState + useMock; giu mock `/learning/*` routes cu? — Quyet dinh: giu cho demo khi USE_MOCK, guard chung vao attempt route.
3. AuthScreen: ConsumerStatefulWidget; form + login provider; nut Google/EduID disabled "Sắp ra mắt"; guest chi khi useMock.
4. SplashScreen: doi ca restore xong roi moi navigate.
5. CampaignDetail: thay block mock lesson bang `lessonListProvider(eventId)` (`GET /events/{id}/lessons`); item → `/learning/lesson/{id}`; empty → AsyncStateView.empty("Chưa có bài học được xuất bản").
6. LessonEntryScreen: `GET /lessons/{id}` metadata (title/centralQuestion/versionNo) + POST attempts → `/learning/attempt/{attemptId}`; loi `LESSON_NOT_PUBLISHED` → friendly.
7. Dashboard: neu authed → `myProgressProvider` resume card dau tien → go `/learning/attempt/{attemptId}`; them logout icon nho tren top bar.
8. Giu tieng Viet co dau cho moi label moi.

## Todo list

- [ ] auth providers + session restore
- [ ] router redirect + 2 routes moi
- [ ] AuthScreen real form + unavailable buttons + guest gate
- [ ] Splash restore-aware
- [ ] Campaign lesson list that + empty state
- [ ] LessonEntryScreen start/resume → player route
- [ ] Dashboard resume card + logout
- [ ] `flutter analyze` sach

## Success criteria

- USE_MOCK=false: mo app → auth screen → login thanh cong (backend stub/test) → dashboard; reload app → auto-login qua refresh token.
- Campaign detail list lesson that; lesson chua publish → 404 friendly; event khong co lesson → empty state dung copy.
- Start → `resumed:false`; kill app vao lai → resume → `resumed:true` dung attempt.
- USE_MOCK=true: guest vao demo mock nguyen trang.

## Risk assessment

- Redirect loop khi authState dang `unknown` — chi redirect khi state resolved, splash giu cho toi khi restore xong.
- Route extra truyen object — dung `state.extra` co kieu, fallback fetch lai khi null (deep link).
- `/learning/attempt/:id` chua co player (phase 03) — dat shell AsyncStateView tam, khong de route chet.

## Security considerations

- Khong hien thi email/password trong log; mat khau `obscureText`.
- Logout: goi `/auth/logout` + clear TokenStorage + invalidate toan bo providers (ProviderContainer reset → `ref.invalidate(authStateProvider)` + context.go('/auth')).
- Token chi trong memory + secure storage.

## Next steps

Phase 03 lap LessonPlayer vao `/learning/attempt/:attemptId` route shell.
