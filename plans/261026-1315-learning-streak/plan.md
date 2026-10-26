---
title: "Learning Streak (Chuỗi Ngày Học)"
description: "Server-authoritative daily learning streak: schema, backend service + API, mobile dashboard/detail/result/profile UI"
status: complete
priority: P2
effort: 24h
branch: main
tags: [gamification, streak, backend, mobile, flyway]
created: 2026-10-26
---

# Learning Streak — Plan Overview

## Goal
Track consecutive learning days (Asia/Ho_Chi_Minh). A day "qualifies" when the learner completes ≥1 lesson (status=COMPLETED attempt, server-time `completed_at`). Server computes everything; client never sends dates.

## Hard Rules
- Server-authoritative: study_date derived from `learner_attempts.completed_at` in `Asia/Ho_Chi_Minh` — NEVER trust client timestamp.
- Idempotent: `UNIQUE(user_id, study_date)` + pessimistic lock on `user_learning_streaks`; 2 devices same-day = 1 day counted.
- No rewards: per POINT-03 — streak grants NO EXP/Điểm Sử Ký.
- No client-side increment endpoint.
- Same-tx atomicity with `doComplete()` — rollback completion rolls back streak too.
- Do NOT touch GAME-07/GAME-08 scope. Do NOT break TASK-0023 first-completion reward.

## Phases

| # | Phase | Scope | Est |
|---|-------|-------|-----|
| 01 | [Database Flyway V31](phase-01-database-flyway.md) | `user_learning_streaks` + `user_learning_streak_days` DDL + standalone backfill script w/ dry-run | 3h |
| 02 | [Backend Domain](phase-02-backend-domain.md) | `com.dauviet.streak` package: entities, repos, `StreakService.recordCompletion()` + `stateOf()` + `calendarOf()` | 4h |
| 03 | [Backend API](phase-03-backend-api.md) | `StreakController` (`GET /me/streak`, `GET /me/streak/calendar`), DTOs, hook into `LearnerAttemptService.doComplete()`, additive `streakIncreased`/`newStreak` on `CompleteAttemptResponse` | 3h |
| 04 | [Backend Tests](phase-04-backend-tests.md) | Unit + IT: idempotent same-day, missed-day reset, multi-device race, tz boundary 23:55→00:05, replay | 4h |
| 05 | [Mobile Data Layer](phase-05-mobile-data-layer.md) | `streak_api_client`, `streak_dto`, repo (Api/Mock), `streakProvider` (AsyncNotifier, session key, applySnapshot) | 2h |
| 06 | [Mobile UI Home](phase-06-mobile-ui-home.md) | Replace hardcoded '12' streak pill in dashboard header with real `streakProvider` data + tap→detail | 2h |
| 07 | [Mobile UI Detail](phase-07-mobile-ui-detail.md) | New `streak_detail_screen`: current/longest/month calendar/last-qualified/today status | 3h |
| 08 | [Mobile UI Result](phase-08-mobile-ui-result.md) | Flame N→N+1 animation in `lesson_result_screen` driven by `streakIncreased`, one-shot `_popupShown`-style flag | 1h |
| 09 | [Mobile Profile](phase-09-mobile-profile.md) | Add streak stats (current/longest) to `_StatsCard` in `profile_screen.dart`; fix hardcoded '12' in `lesson_player_screen.dart` | 1h |
| 10 | [Cleanup & Docs](phase-10-cleanup-and-docs.md) | Update `docs/DATABASE_DESIGN.md`, `docs/API_SPEC.md`, `docs/GAMIFICATION_BUSINESS_RULES.md` (STRK-01..N), `docs/development-roadmap.md`, `docs/project-changelog.md` | 1h |

## Key Decisions

- **Hook pattern**: direct `streakService.recordCompletion()` call inside `doComplete()` same tx — matches `rewardGrants`/`eventMilestones`/`itemUnlocks`. No event bus (contract §1).
- **Concurrency**: `findForUpdate` pessimistic lock on `user_learning_streaks` + `insertIgnore` lazy-create (mirrors `UserEnergyRepository`) — NOT `row_version` optimistic (avoids retry storms on 2-device race).
- **Idempotency**: `UNIQUE(user_id, study_date)` on `user_learning_streak_days` + `INSERT ... ON CONFLICT DO NOTHING` returns 0/1 → caller knows if this is a new qualifying day.
- **Timezone**: `study_date = (completed_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date` — computed in SQL or via `ZoneId` server-side.
- **Backfill**: standalone idempotent script `dau-viet-db/scripts/backfill_streak.sql` (NOT auto-Flyway — long set-based INSERT may lock); dry-run mode = wrap in `BEGIN; ... ROLLBACK;` or `psql -v dry_run=1`.
- **Flame trigger**: additive `streakIncreased`/`newStreak`/`previousStreak` fields on `CompleteAttemptResponse` (precedent: `newlyUnlockedDossiers` GAME-04). Atomic, no extra round-trip.
- **Package**: `com.dauviet.streak` (flat bounded context — mirrors `com.dauviet.energy`/`collection`/`reward`). NOT `com.dauviet.gamification.*` (umbrella doesn't exist).

## Dependencies
- Existing: `learner_attempts.completed_at`, `JwtSubjectExtractor`, `IdempotencyService`, pessimistic-lock repository pattern.
- Parallel: GAME-07 (wallet), GAME-08 (regression) — no overlap; this plan avoids item/exp/points/wallet tables.

## Open Questions
- None blocking. See phase files for details.
