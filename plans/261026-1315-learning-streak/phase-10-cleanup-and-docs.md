# Phase 10 â€” Cleanup & Documentation

## Context Links
- `docs/DATABASE_DESIGN.md` â€” add `user_learning_streaks` + `user_learning_streak_days` sections (V31).
- `docs/API_SPEC.md` â€” add `GET /api/v1/me/streak` + `GET /api/v1/me/streak/calendar` + additive `CompleteAttemptResponse` fields.
- `docs/GAMIFICATION_BUSINESS_RULES.md` â€” add `STRK-01..NN` rules.
- `docs/GAMIFICATION_TECHNICAL_CONTRACT.md` â€” add `Learning â†’ Streak` edge to domain boundaries diagram.
- `docs/development-roadmap.md` â€” mark "Learning Streak" task complete.
- `docs/project-changelog.md` â€” changelog entry.

## Overview
- **Priority**: P2
- **Status**: complete
- **Est**: 1h

Update all canonical docs to reflect the new feature; run final regression checks; clean up any TODO/FIXME introduced during phases 01-09.

## Key Insights
- Documentation triggers per `docs-management` rules: feature complete â†’ roadmap update + changelog entry required.
- Business rules doc adds a new `STRK-` rule block â€” keeps numbering scheme (ENGY-, EVT-, ITEM-, POINT-, etc).
- Verify no stray hardcoded '12'/'3' references remain in code (`grep -rn` for sanity).

## Requirements
- All 4 docs updated; cross-references verified (links/dates/table names).
- `mvnw verify` green; `flutter analyze` + `flutter test` green.
- No AI-reference commit messages (project rule).
- No committed secrets/dotenv.

## Architecture

N/A â€” documentation only.

## Related Code Files

**Modify**:
- `docs/DATABASE_DESIGN.md` â€” V31 section, both tables.
- `docs/API_SPEC.md` â€” 2 new endpoints + `CompleteAttemptResponse` schema update.
- `docs/GAMIFICATION_BUSINESS_RULES.md` â€” append `STRK-01..NN` rules.
- `docs/GAMIFICATION_TECHNICAL_CONTRACT.md` â€” domain boundary update.
- `docs/development-roadmap.md` â€” streak row marked Complete with date.
- `docs/project-changelog.md` â€” new entry under `Unreleased` or current version.

**Delete**: any dead code/TODO comments left over from phases.

## Implementation Steps

### Step 1 â€” DATABASE_DESIGN.md

Append under the V21 entry (or wherever the latest migration section is):

```markdown
### V31 â€” Learning Streak

**user_learning_streaks** â€” 1 dĂ²ng/user, Ä‘Ăºng má»™t láº§n lazy-create khi complete Ä‘áº§u tiĂªn.
| Column | Type | Notes |
|---|---|---|
| user_id | UUID PK â†’ users.id | |
| current_streak | INTEGER â‰¥0 | reset vá» 1 náº¿u bá» 1 ngĂ y |
| longest_streak | INTEGER â‰¥ current | max má»i thá»i |
| last_qualified_date | DATE | ngĂ y VN gáº§n nháº¥t cĂ³ COMPLETED |
| created_at, updated_at | TIMESTAMPTZ | |
| row_version | BIGINT | optimistic phá»¥ |

**user_learning_streak_days** â€” append-only audit; PK (user_id, study_date).
| Column | Type | Notes |
|---|---|---|
| user_id | UUID â†’ users.id | |
| study_date | DATE | (completed_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date |
| lesson_id, learner_attempt_id | UUID | attempt Ä‘áº§u tiĂªn cá»§a ngĂ y |
| completed_at | TIMESTAMPTZ | server-time cá»§a attempt tháº¯ng race |
```

### Step 2 â€” API_SPEC.md

Add two endpoint blocks + `CompleteAttemptResponse` field additions:

```markdown
### GET /api/v1/me/streak
Tráº¡ng thĂ¡i chuá»—i ngĂ y há»c hiá»‡n táº¡i. Identity tá»« JWT.

Response 200:
{ "currentStreak": 5, "longestStreak": 12, "completedToday": true,
  "lastQualifiedDate": "2026-10-26", "today": "2026-10-26",
  "timezone": "Asia/Ho_Chi_Minh", "serverTime": "2026-10-26T15:30:00Z",
  "streakAlive": true }

### GET /api/v1/me/streak/calendar?from=YYYY-MM-DD&to=YYYY-MM-DD
Danh sĂ¡ch ngĂ y há»c (VN) trong range â€” max 1 nÄƒm. 400 náº¿u from>to hoáº·c range>1y.

Response 200: { "dates": ["2026-10-20", "2026-10-24", "2026-10-26"] }

### POST /api/v1/attempts/{id}/complete â€” additive fields
CompleteAttemptResponse giá» cĂ³ thĂªm (chá»‰ trong láº§n complete tháº­t â€” replay tráº£ default):
  streakIncreased: boolean
  newStreak: int
  previousStreak: int
  completedToday: boolean | null
  studyDate: "YYYY-MM-DD" | null
```

### Step 3 â€” GAMIFICATION_BUSINESS_RULES.md

Append rule block:

```markdown
### Learning Streak (STRK)

- **STRK-01**: Streak = sá»‘ ngĂ y VN liĂªn tiáº¿p cĂ³ â‰¥1 attempt COMPLETED. Chá»‰
  COMPLETED má»›i Ä‘áº¿m â€” IN_PROGRESS/ABANDONED/startOrResume khĂ´ng.
- **STRK-02**: Timezone `Asia/Ho_Chi_Minh`. `study_date` = `(completed_at AT
  TIME ZONE 'Asia/Ho_Chi_Minh')::date` â€” server tĂ­nh, KHĂ”NG bao giá» tin client.
- **STRK-03**: Nhiá»u láº§n complete trong cĂ¹ng `study_date` â†’ 1 ngĂ y duy nháº¥t.
- **STRK-04**: Bá» 1 ngĂ y VN khĂ´ng há»c â†’ `current_streak` reset vá» 1 láº§n
  complete káº¿ tiáº¿p. `longest_streak` khĂ´ng Ä‘á»•i.
- **STRK-05**: KHĂ”NG thÆ°á»Ÿng EXP/Äiá»ƒm Sá»­ KĂ½ cho streak (POINT-03). Streak lĂ 
  Ä‘á»™ng lá»±c tá»± thĂ¢n.
- **STRK-06**: Idempotent + concurrency-safe: 2 thiáº¿t bá»‹ complete cĂ¹ng ngĂ y =
  1 ngĂ y (UNIQUE(user_id, study_date) + pessimistic lock).
- **STRK-07**: `streakAlive` = `lastQualifiedDate >= today - 1`. Cho phĂ©p UI
  phĂ¢n biá»‡t "Ä‘Ă£ há»c hĂ´m nay" vs "cĂ²n cá»­a giá»¯ chuá»—i" vs "Ä‘Ă£ Ä‘á»©t".
- **STRK-08**: Backfill má»™t láº§n tá»« `learner_attempts` COMPLETED â€” script
  riĂªng `dau-viet-db/scripts/backfill_streak.sql`, khĂ´ng auto-migration.
```

### Step 4 â€” GAMIFICATION_TECHNICAL_CONTRACT.md

Update domain boundary section: add `Learning Runtime â†’ Streak` to the one-way call list (same physical tx as `doComplete`); document `user_learning_streaks` lock-order (acquired AFTER `learner_attempts`, leaf).

### Step 5 â€” development-roadmap.md + project-changelog.md

- Add row `LEARN-STREAK` (or new task ID) | Backend + Mobile | Complete (2026-10-26) â€” under Gamification section or new Learning section.
- Changelog entry: brief bullet list (schema + backend + mobile + tests count).

### Step 6 â€” Final regression

- `./mvnw verify` â†’ all tests green (existing + new).
- `cd dau-viet-mobile && flutter analyze && flutter test` â†’ green.
- `grep -rn "streak.*12\|flame.*12" dau-viet-mobile/lib/` â†’ no stray hardcodes.
- Verify no files outside the planned create/modify lists were touched (`git status`).

### Step 7 â€” Cleanup

- Remove any TODO/FIXME comments introduced.
- Verify file size <200 lines per dev-rules â€” split if needed.
- Run code-reviewer agent on the diff before commit.

## Todo List
- [ ] Update `DATABASE_DESIGN.md` V31 entry.
- [ ] Update `API_SPEC.md` with 2 endpoints + CompleteAttemptResponse additions.
- [ ] Append `STRK-01..08` to `GAMIFICATION_BUSINESS_RULES.md`.
- [ ] Update `GAMIFICATION_TECHNICAL_CONTRACT.md` domain boundary.
- [ ] Add roadmap row + changelog entry.
- [ ] Run `./mvnw verify` â€” green.
- [ ] Run `flutter analyze` + `flutter test` â€” green.
- [ ] Final grep for stray hardcodes/TODOs.
- [ ] `git status` review â€” only expected files changed.
- [ ] Delegate to `code-reviewer` agent for final review.
- [ ] Commit (no AI references, conventional `feat:` message).

## Success Criteria
- All docs consistent with implementation.
- Zero TODO/FIXME in new code.
- All tests green; analyzer clean.
- `code-reviewer` agent signs off.

## Risk Assessment
| Risk | Mitigation |
|------|------------|
| Docs drift from impl (e.g., forgot a STRK rule) | Cross-check phase-02/03 files vs docs during write |
| Regression in unrelated area (GAME-07/08 in flight) | Verify `git status` only contains expected files; don't touch shared reward/collection code paths beyond the additive `doComplete` line |

## Security Considerations
- No secrets in docs; no PII examples.
- Changelog doesn't leak internal details beyond what's in code already.

## Next Steps
- Future: wallet/level integration (GAME-07) may add "X-day-streak bonus" â€” out of scope here (POINT-03 forbids streak rewards in V1).
