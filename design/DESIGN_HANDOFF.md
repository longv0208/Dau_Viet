# DẤU VIỆT — DESIGN TO DEVELOPMENT HANDOFF / TRACEABILITY

**Purpose:** nối đặc tả UI (Flutter/Next.js) → model/API Spring Boot → asset → QA. Tất cả endpoints dưới đây là **API mapping đề xuất**, phải đối chiếu `API_SPEC.md` trước implementation; endpoint không tự động trở thành API chính thức.

## 1. Architecture contract

```text
Admin form → Draft Lesson + Evidence/Media config
            ↓ validate/publish
    Immutable LessonVersion JSON snapshot
            ↓ REST learner-safe DTO
Flutter ActivityRenderer → User Answer → Spring Boot ActivityHandler
                                                ↓
                  ActivityAttempt + Semantic Output + State Transition
                                                ↓
                                     Result/Reward (idempotent)
```

**Never:** client check answer key, hardcode `eventId`, modify published version, trust client EXP/currency, link evidence only by display text.

## 2. Mobile ↔ API ↔ entity mapping

| Screen ID | Data/API proposal | Major entities | Critical output |
|---|---|---|---|
| M-01/02 | `POST /api/auth/login`, refresh, logout | User/session | authenticated state |
| M-03 | `GET /api/me/dashboard` | User, Attempt, Progress | resume deep link |
| M-04/05 | `GET /api/periods`, `GET /api/periods/{id}` | Period metadata (proposal) | selected period |
| M-06 | `GET /api/periods/{id}/map` | Event, unlock policy | selected event ID |
| M-07/08 | `GET /api/events/{id}`; `GET /api/events/{id}/lessons` | HistoricalEvent, Lesson | active published lesson |
| M-09 | `POST /api/lessons/{id}/attempts`; `GET /api/attempts/{id}/current` | LessonVersion, LearnerAttempt | current activity DTO |
| M-10..17 | `POST /api/attempts/{id}/activities/{aid}/submit` | ActivityAttempt, evidence refs | validated semantic output & next |
| M-18/19 | `GET /api/attempts/{id}/result`, `POST /api/attempts/{id}/complete` | LessonResult, RewardGrant | completion/reward receipt |
| M-20..23 | `GET /api/me/collection`, `/achievements`, `/profile`, `/map` | Collection, Progress, User | view model |
| M-24..28 | `/api/islands`, `/api/inventory`, `/api/shop`, `/api/energy` | Economy entities | separate service layer |

**Caution:** HistoricalPeriod isn't a required BA entity in earlier docs; add it only if choosing a first-class period model. URL shapes for create attempt/complete must be reconciled with existing `API_SPEC.md` rather than implemented in duplicate.

## 3. Admin ↔ entity ↔ artifact mapping

| Screens | Domain objects | Output / guardrail |
|---|---|---|
| A-03/04 | HistoricalEvent (+ HistoricalPeriod proposal) | reviewed metadata and hero asset IDs |
| A-05/06/07 | Lesson, LessonTemplate | draft question/objectives and template preset |
| A-08 | Stage, transition config | ordered state graph; required stages |
| A-09/12 | Activity + validation/hint/feedback rule | typed, server-valid config + output contract |
| A-10 | Evidence/Source | provenance, relation IDs, content references |
| A-11 | Asset/Media | media IDs, rights, usage and safe retention |
| A-13 | Preview | learner-safe DTO + test simulation |
| A-14/15 | LessonVersion, publish audit | immutable snapshot, version number, audit record |
| A-18..21 | Reward, Item, Island, Energy policy | separate P2 module, not lesson fields |

## 4. Activity data contract (example, not full production schema)

**Admin-only source** (restricted):

```json
{
  "id": "act-bd-quiz-01",
  "type": "MULTIPLE_CHOICE",
  "instruction": "Chọn con sông diễn ra trận Bạch Đằng năm 938",
  "config": {
    "options": [
      {"id": "opt-a", "text": "Sông Hồng"},
      {"id": "opt-b", "text": "Sông Bạch Đằng"}
    ]
  },
  "validationConfig": {"correctOptionIds": ["opt-b"]},
  "feedbackConfig": {"correct": "Chính xác", "incorrect": "Xem lại địa điểm trận đánh"}
}
```

**Mobile public DTO** omits `validationConfig`; reference objects can carry asset URL, alt text, captions and source references. **Answer submission** includes only stable IDs, attempt ID and client idempotency key. **Server response** includes grading status, hint/feedback, saved semantic output and next stage/activity pointer.

## 5. State machine & output

| Activity type | Learner input | Server output | Next-stage usage |
|---|---|---|---|
| MCQ | option IDs | evaluated answer/feedback | completion, rule |
| EXPLORE_MAP | discovered marker IDs | `DiscoveredItem[]` | unlock evidence |
| EVIDENCE_SELECT | evidence IDs | `SelectedEvidence[]` | reasoning/hypothesis |
| MATCHING/REASONING | relation pairs | `Inference[]` | hypothesis |
| HYPOTHESIS | claim ID/text + evidence IDs | `Hypothesis` | verification |
| DRAG_ORDER | event ID sequence | `Reconstruction` | verification |
| VERIFICATION | comparison inputs | Supported/Partial/Contradicted | revise/continue |
| CER | claim, evidence IDs, reasoning | `HistoricalConclusion` | story/result |
| REFLECTION | optional response | `ReflectionResponse` | result |

Save `ActivityAttempt` appendably and `current position` transactionally; retain durable snapshots for versioned attempts. Idempotent completion/claim should be backed by unique constraint or transactional invariant in DB.

## 6. End-to-end happy path and API sequence

1. Admin creates event → draft lesson → choose template → stages/activity/evidence/media.
2. Admin previews with sample learner state; validate complete/config references.
3. Publish creates `LessonVersion v1` and exposes *public* schema for new attempts.
4. Mobile fetches event → lessons → create/resume attempt; attempt pins version.
5. Flutter renders activity by `type`; submit includes idempotency key; backend validates and persists.
6. Verification returns `Partial` if insufficient evidence, directs user to revise; outputs remain traceable.
7. CER complete → story → result/claim; reward granted exactly once.
8. Admin publishes v2 while existing attempt stays on v1; assets pinned.

## 7. UI QA matrix — minimum flows

| Test | Expected behavior | Owner |
|---|---|---|
| Small-screen 320dp + Vietnamese long text | no clipped CTA/navigation | Flutter + Design |
| Orientation/restart mid-drag | submitted state preserved; draft policy known | Flutter + Backend |
| Weak connection/double Submit | no duplicate answer/reward | Backend + QA |
| Wrong MCQ then retry | configured feedback/retry, no premature progress | Backend + Flutter |
| Verification contradictory | allowed branch to hypothesis/reconstruction | Engine |
| CER empty evidence | fail with visible explanation | Engine + Admin |
| Required image missing | publish blocked, old version safe | Admin + Backend |
| New event/lesson with same types | no new engine code | Integration QA |
| Asset with no approved rights | not selectable for publish | Admin + Content |
| Screen reader + drag alternative | controls usable without drag | Design + Flutter |

## 8. Milestone deliverables

| Milestone | Design deliverable | Development gate |
|---|---|---|
| D0 | Approved screen inventory, navigation, decisions, foundation tokens | estimate backlog |
| D1 | Figma mobile P0 frames + components + states | start Flutter shell |
| D2 | Admin editor wireframes + DTO forms + preview behavior | start CMS |
| D3 | Illustration pack P0 with manifests/rights | hook asset library |
| D4 | Prototype 1 lesson with failure/retry/resume | end-to-end demo |
| D5 | Gamification/shop assets & flows if approved | begin P2 |

## 9. Open decisions (sign-off required)

1. **Scope conflict:** BA newer = Admin builder Must, historical map Should; old FR = historical map Must, Admin CMS phase 2. Proposed baseline follows newer BA.
2. `HistoricalPeriod` entity: standalone period layer or static grouping of events? Mockup timeline presumes this.
3. Bottom navigation: concept variants inconsistent; finalize 4–5 tabs.
4. Four Dấu Vết: fixed categories vs lesson-configured N cards; proposal N with a four-card example.
5. Mandatory vs optional stages: Reflection Should; which templates get Reconstruction?
6. Scoring/rubric: retry penalty, multiple correct answers, partial credit, free-text/CER assessment without AI.
7. Auto-save: draft answer state on device vs server; conflict behavior across devices.
8. Story: separate stage? Proposal narrative **after CER** and before Result.
9. Commerce/energy: currency, package prices, age rating, payment platform compliance and fairness are not defined by current docs.
10. Art assets: source editable layers, actual design tokens, licenses, historical validation, final density/performance budget pending.

## 10. Definition of Ready — implement a screen

- [ ] Screen ID/route/permission/priority approved
- [ ] Wireframe + spec covering loading/empty/error/locked/resume states
- [ ] CTA and back behavior documented
- [ ] API contract and example success/error payload available
- [ ] Design components/tokens named
- [ ] Required asset IDs approved or fallback specified
- [ ] Accessibility/keyboard and small-screen acceptance criteria
- [ ] Analytics/privacy decision if relevant
- [ ] QA acceptance criteria and regression route identified

**Status:** Spec-ready for review, not art-ready. Implementation should wait for product sign-off on P0 screen list and baseline decisions.
