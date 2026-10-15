---
title: "TASK-0011 Learning Engine Core — Activity Execution and Stage Transitions"
description: "Server-authoritative engine over pinned LessonVersion snapshots: 12 ActivityHandlers, generic stage-transition resolver, completion evaluator, minimal runtime API"
status: pending
priority: P1
effort: 14h
branch: main
tags: [learning-engine, attempts, activity-handlers, stage-transitions, completion]
created: 2026-10-16
---

# TASK-0011 — Learning Engine Core: Activity Execution and Stage Transitions

## Context Links

- `tasks/TASK-0011/task.json` + `tasks/TASK-0011/brief.md` — execution source of truth
- `docs/LEARNING_ENGINE_DESIGN.md` §2/§5-§9 — contracts, handler catalog, attempt state machine, submit pseudocode, guardrails
- `docs/API_SPEC.md` §2 learner endpoints (`/attempts/...`), §4 security/idempotency, error envelope
- `docs/DATABASE_DESIGN.md` §learner runtime — `learner_attempts`, `activity_attempts`, `lesson_results`, `idempotency_records` (all exist in V4)
- `docs/AGENT_WORKFLOW.md` — risk/verification/handoff
- Code: `lesson/draft/{ActivityType,StageType,DraftSchema,DraftValidator,ActivityConfigValidator,SnapshotBuilder}.java`, `lesson/draft/validators/*`, `lesson/application/{LessonPublishService,LearnerProjectionService,LearnerLessonService}.java`, `lesson/api/LearnerLessonController.java`, `common/error/{ErrorCode,GlobalExceptionHandler}.java`, `V4__learner_runtime_progress_rewards.sql`
- Prior plan `plans/261016-0005-task0010-lesson-publish/` for conventions

## Overview

Build the server-authoritative Learning Engine that executes a learner attempt against the pinned, immutable `lesson_versions.snapshot_json`. Deliver: typed runtime contracts, an `ActivityHandler` registry covering all 12 `ActivityType`s, a generic stage transition resolver over the snapshot `nextStageIds` graph, a completion evaluator honoring `completion` config, and a minimal runtime API surface that lets a learner start an attempt, read the current activity, submit answers, and finish — all evaluated server-side with hidden keys never emitted. Rewards/EXP, idempotency-key persistence, resume-for-ABANDONED, and the progress dashboard are deferred to TASK-0012.

## Phase Index

| # | File | Status | Summary |
|---|---|---|---|
| 01 | `phase-01-contracts-registry-skeleton.md` | pending | Runtime contracts + `ActivityHandler` registry + engine entrypoint + snapshot model |
| 02 | `phase-02-activity-handlers.md` | pending | Implement all 12 `ActivityHandler`s (grouped: acknowledgment / selection / structured-response) |
| 03 | `phase-03-transition-completion.md` | pending | `StageTransitionResolver` + `LessonCompletionEvaluator` over snapshot graph + completion config |
| 04 | `phase-04-runtime-service-api.md` | pending | `LearnerAttemptService` + `LearnerAttemptController` (start/get-current/submit/complete) |
| 05 | `phase-05-tests.md` | pending | Unit + integration tests for handlers, resolvers, API, no-answer-key leak |
| 06 | `phase-06-docs-verification.md` | pending | Update API_SPEC, LEARNING_ENGINE_DESIGN (evaluation semantics), DATABASE_DESIGN; run `mvnw verify` |

## Key Decisions

| Question | Decision | Rationale |
|---|---|---|
| Package | `com.dauviet.learning` (top-level, parallel to `lesson`) | Engine is a runtime concern, not an authoring concern; keeps `lesson` package focused on authoring + publish, mirrors the design doc's `LearningEngine` domain element. Sub-packages: `learning.contract`, `learning.handler`, `learning.resolver`, `learning.service`, `learning.api`, `learning.infrastructure.persistence`. |
| Persistence in scope? | **Yes — minimal** (`learner_attempts` + `activity_attempts` writes only) | V4 already has tables + unique constraint `ux_attempt_active_user_version` + `learner_attempts.row_version` for optimistic locking. Full attempt lifecycle (resume/forfeit, idempotency replay, `lesson_results`, `user_evidence`, `reward_transactions`) deferred to TASK-0012. We need real rows so tests can prove pinned-version behavior. |
| Idempotency-Key | Accept header on submit; **do not wire `idempotency_records`** yet | Same posture as TASK-0010 publish — defer to TASK-0012 which owns the full submission idempotency contract. Documented open question. |
| `lesson_results` write on completion? | **Deferred** | Completion detection is implemented, but the `lesson_results` row + reward ledger + `status=COMPLETED` transition writes happen in TASK-0012 alongside idempotency. TASK-0011 returns a `LessonCompletion` verdict DTO only. |
| Snapshot access | New `SnapshotService` parses `snapshot_json` once per request into a typed in-memory model (`SnapshotModel`) — never exposed to learner payload | Avoids re-walking raw `JsonNode` in every handler; central place to fail `SNAPSHOT_CORRUPT`. |
| Non-linear `nextStageIds` | Resolver treats it as a DAG walk, not a linear `+1` | `DraftValidator` already enforces acyclic + terminal-reachability at publish; resolver just needs deterministic next-stage choice. Chosen policy: first `nextStageIds` entry whose required activities aren't all complete; fall back to first incomplete stage in array order; else `null`. |
| VERIFICATION semantics | `SUPPORTED / PARTIAL / CONTRADICTED` computed server-side from prior activity outputs vs `config.requiredEvidenceIds` | Where BA is ambiguous (what counts as supported), document chosen rule: SUPPORTED if hypothesis + all required evidence ids present in prior outputs; PARTIAL if hypothesis present but evidence incomplete; CONTRADICTED if hypothesis missing or contradicts `config.expectedHypothesis` when authored. |
| CER / REFLECTION / READ / VIEW_IMAGE / EXPLORE_MAP correctness | **Completion semantics, not correctness** | BA does not define grading for these; engine accepts syntactically valid submissions and marks activity complete. Open-ended semantics recorded in plan + LEARNING_ENGINE_DESIGN §13. |

## Requirements (from AC)

- AC-1: typed contracts (`AttemptContext`, `ActivitySubmission`, `ActivityResult`, `StageProgress`, `NextActivity`/`NextStage`, `LessonCompletion`) emitted learner-safe (no `LEARNER_HIDDEN_KEYS`).
- AC-2: handler registry resolves per `ActivityType`; unknown → structured error (never 500).
- AC-3: all 12 handlers with documented semantics.
- AC-4: stage transitions follow `nextStageIds`, required gating, cycle-safe, non-linear; completion per `completion` config.
- AC-5: attempts resolve activities only inside their pinned `lesson_version_id`; republish cannot affect in-flight; malformed snapshot → controlled error.
- AC-6: invalid submissions → 4xx with structured codes; no answer keys in any emitted payload.
- AC-7: minimal API surface — start/get-current/submit/complete; ownership enforced; no reward side-effects.
- AC-8: unit coverage all 12 handlers + resolvers + completion; ITs for API; regression green.
- AC-9: docs updated; semantics decisions recorded.

## Success Criteria

- `mvnw verify` exit 0 (all TASK-0008..0010 ITs still green plus new tests).
- IT asserts every API response omits every `LEARNER_HIDDEN_KEYS` leaf name anywhere in the payload.
- Concurrent submit on same activity does not produce two `activity_attempts` rows for the same `attempt_no` (DB UNIQUE backstop + optimistic `row_version` guard).
- Republishing a lesson while an attempt is `IN_PROGRESS` does not affect that attempt's pinned snapshot.
- `POST /lessons/{id}/attempts` on unpublished/archived lesson → 404 `LESSON_NOT_PUBLISHED`.

## Risk Assessment

- **Ambiguous evaluation rules** for VERIFICATION/CER/REASONING_CONNECT — mitigated by documenting chosen semantics in phase-02 and in LEARNING_ENGINE_DESIGN §13; flagged for BA/PO.
- **State JSON shape** — `state_json` is a free-form object; define minimal schema `{completedActivityIds:[], outputsByActivityId:{}, currentStageId, currentActivityId}` up front so TASK-0012 can extend.
- **Answer-key leak** — handlers must strip all keys in `DraftSchema.LEARNER_HIDDEN_KEYS` before emitting `ActivityResult.feedback`/`output`; add a serializer-level IT assertion.
- **Concurrent submit** — rely on `learner_attempts.row_version` JPA `@Version` + unique `(learner_attempt_id, activity_id, attempt_no)`; test with `ExecutorService`.
- **Snapshot drift between pin and execution** — impossible by construction (snapshot immutable via DB trigger), but document for reviewers.

## Next Steps / Open Questions (to user)

1. VERIFICATION rule when `config.expectedHypothesis` is absent but `requiredEvidenceIds` exist — plan uses "all required evidence present + hypothesis chosen" = SUPPORTED; PARTIAL otherwise. Confirm?
2. CER grading — currently completion-only (accept any non-empty claim+reasoning). Should server enforce `config.rubric.criteria` count or `requiredEvidenceIds` subset check at runtime, or leave to later grading task?
3. REASONING_CONNECT — `config.allowedRelations` exists in draft validator; for MVP, evaluate relation type validity only (no expected edge set), or also check pair membership against `nodes`? Plan: validate node ids + relation name only.
4. EXPLORE_MAP — `config.markers[].id` must be in submission markerId; is "completed" = all markers discovered, or any non-empty subset? Plan: complete when `minMarkers` (new optional config, default = all marker ids) discovered.
5. `lesson_results` + `user_evidence` writes — confirm deferral to TASK-0012 (planned).
6. Resume policy for `ABANDONED` attempt — defer to TASK-0012 (planned).

## Docs Impact

major — new endpoints, new package, evaluation semantics doc, error codes.
