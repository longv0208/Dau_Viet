---
title: "GAME-06 Admin Gamification CMS"
description: "Admin CMS cho event completion policies, historical dossiers, item rule builder v2 va reconcile UI."
status: completed
priority: P1
effort: 30h
branch: main
tags: [gamification, admin, spring-boot, nextjs, flyway, game-06]
created: 2026-10-25
---

# GAME-06 — Admin Gamification CMS

Them Admin CMS (Spring Boot + Next.js admin) cho gamification rules. Backend authoritative: /api/v1/admin/** gate boi `hasRole("CONTENT_ADMIN")`. Khong sua V22-V27; chi them V28+. Khong dong Flutter, khong dong Learning Engine internals.

## Phases

| # | Phase | Effort | Status | File |
|---|-------|--------|--------|------|
| 01 | Backend — Event Completion Policy admin API + atomic publish | 5h | completed | [phase-01-backend-policy-api.md](phase-01-backend-policy-api.md) |
| 02 | Backend — Dossier admin API + V28 `historical_dossier_versions` + event links | 6h | completed | [phase-02-backend-dossier-api.md](phase-02-backend-dossier-api.md) |
| 03 | Backend — Rule validate/history + reconcile admin surface | 3h | completed | [phase-03-backend-rule-validate-history.md](phase-03-backend-rule-validate-history.md) |
| 04 | Admin UI — Gamification tab (policy editor + dossier links) | 5h | completed | [phase-04-admin-ui-gamification-tab.md](phase-04-admin-ui-gamification-tab.md) |
| 05 | Admin UI — Dossier library + editor | 4h | completed | [phase-05-admin-ui-dossier-library.md](phase-05-admin-ui-dossier-library.md) |
| 06 | Admin UI — Rule Builder V2 + history + reconcile panel | 6h | completed | [phase-06-admin-ui-rule-builder.md](phase-06-admin-ui-rule-builder.md) |
| 07 | Tests — backend ITs | 2h | completed | [phase-07-tests-backend.md](phase-07-tests-backend.md) |
| 08 | Tests — admin Vitest + docs + verify | 2h | completed | [phase-08-tests-admin-docs.md](phase-08-tests-admin-docs.md) |

## Architecture Overview

- Backend: 3 admin controllers moi (`AdminCompletionPolicyController`, `AdminDossierController`, `AdminItemRuleController`) + service tang tren domain san co. Publish/archive/validate dung transaction + `findByIdForUpdate` tren event/dossier row.
- Frontend: 1 tab moi `gamification` trong Event Workspace + 1 trang `/dossiers` + section Rule Builder + History trong `/items/[id]`. Tat ca qua `apiFetch` + React Query + Zod.
- DB: V28 tao `historical_dossier_versions` (snapshot noi dung moi publish). Khong them cot moi vao V22 — dung `event_dossiers.sort_order` cho displayOrder, dung `item_unlock_rule` append-only cho rule history.

## Key Decisions

- ~~Copy-on-write~~ → in-place DRAFT edits voi policyId on dinh (user override): setter chi duoc goi tren row DRAFT qua guard o service; PUBLISHED immutable theo contract.
- Publish = atomic: pessimistic lock tren `historical_events` row → validate → archive old PUBLISHED → flush → set new PUBLISHED → insert `historical_dossier_versions` row → commit. Partial unique index `ux_event_policy_published` da co.
- Dossier revision: `historical_dossiers.dossier_version` tang 1 moi publish; snapshot full content vao `historical_dossier_versions` de pin `user_dossier_unlocks.dossier_version` truy vet duoc.
- Rule history: doc tu `item_unlock_rule` append-only (`active=false` la old revision); khong can schema moi.
- Reconcile UI: dung endpoint hien co `POST /admin/rewards/reconcile-unlocks` + `POST /admin/rewards/backfill`; khong auto-run, hien thi so that.

## Constraints

- Khong DELETE/TRUNCATE learner data; khong reset policy/progress/unlocks/inventory/rewards.
- Khong sua published lesson snapshots; khong dong EventCompletionEngine / ItemUnlockService internals / Energy/Wallet/Island/Shop/RewardPolicy.
- Khong Playwright/e2e. Backend `mvnw verify`; admin `npm ci / typecheck / test / build`.
- Khong commit/push.
