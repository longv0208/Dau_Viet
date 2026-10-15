# Phase 01 — Draft schema contract

## Context links
- `docs/LEARNING_ENGINE_DESIGN.md` §2 (master stages), §4 (published schema), §5 (Java contracts), §6 (handler catalog)
- `docs/DATABASE_DESIGN.md` §2 (snapshot-bound subentities — draft_json holds stages/activities)
- `dau-viet-backend/src/main/resources/db/migration/V3__authoring_publishing_evidence_assets.sql` (`chk_lesson_draft` requires object)
- Source of truth for allowed stage types: LEARNING_ENGINE_DESIGN §2 table.

## Overview
- Priority: P1
- Status: pending
- Canonical JSONB shape stored in `lessons.draft_json`. All Stage/Activity/Evidence-Ref/Rule/Transition semantics live inside this single document — no separate tables.

## Requirements
- `draft_json` is an object; `schema_version` integer required, current value `1` (constant `DraftSchema.CURRENT_VERSION`).
- Stable IDs: stage/activity IDs are strings `[a-z0-9][a-z0-9-]{1,63}` (not UUIDs) so templates can preset meaningful IDs.
- Stages ordered by array position; `order` field is redundant — use array index. Same for activities.
- Stage-level transitions via `nextStageIds[]`. Stage with empty/null `nextStageIds` is a terminal stage.
- Learner-visible vs server-only fields documented; preview (deferred) will project via whitelist.

## Canonical schema (v1)

```json
{
  "schemaVersion": 1,
  "objectives": ["..."],                    // duplicated into lessons.objectives_json on save
  "stages": [
    {
      "id": "stage-context",
      "type": "CONTEXT",                    // enum StageType (below)
      "title": "Bối cảnh",
      "required": true,
      "activities": [
        {
          "id": "act-intro",
          "type": "READ",                   // enum ActivityType
          "required": true,
          "instruction": "Đọc bối cảnh...",
          "config": { /* type-specific */ },
          "validation": { "kind": "ACKNOWLEDGE" },       // SERVER_ONLY
          "feedback":   { "success": "Tốt", "error": "..." },
          "evidenceRefs": ["ev-tide"]                    // referenced evidence IDs
        }
      ],
      "nextStageIds": ["stage-discovery"],
      "requiredEvidenceIds": []                          // stage gate (publish check)
    }
  ],
  "completion": {
    "requireAllRequiredStages": true,
    "requiredStageIds": ["stage-conclusion"],            // optional explicit list
    "minScore": null                                     // reserved
  }
}
```

## Enums

```java
public enum StageType {
    CONTEXT, DISCOVERY, EVIDENCE, REASONING, HYPOTHESIS,
    RECONSTRUCTION, VERIFICATION, CONCLUSION, REFLECTION
}

public enum ActivityType {
    READ, VIEW_IMAGE, MULTIPLE_CHOICE, EXPLORE_MAP,
    EVIDENCE_SELECT, MATCHING, REASONING_CONNECT,
    HYPOTHESIS_CHOICE, DRAG_ORDER, VERIFICATION,
    CER, REFLECTION_PROMPT
}
```

Allowed stage→activity mapping (validator enforces):

| StageType | Allowed ActivityTypes |
|---|---|
| CONTEXT | READ, VIEW_IMAGE |
| DISCOVERY | EXPLORE_MAP, VIEW_IMAGE, READ |
| EVIDENCE | EVIDENCE_SELECT, READ |
| REASONING | MATCHING, REASONING_CONNECT, READ |
| HYPOTHESIS | HYPOTHESIS_CHOICE, READ |
| RECONSTRUCTION | DRAG_ORDER, READ |
| VERIFICATION | VERIFICATION, READ |
| CONCLUSION | CER, READ |
| REFLECTION | REFLECTION_PROMPT, READ |

(READ allowed everywhere as supporting material. Publish-check enforces at least one "primary" non-READ activity per required stage.)

## Server-only vs learner-visible

SERVER_ONLY keys (never emitted to learner):
- `stages[].activities[].validation` (entire object)
- `stages[].activities[].config.correctOptionIds`, `correctPairs`, `correctOrder`, `requiredEvidenceIds`, `expectedHypothesis`, `answerKey`
- `stages[].requiredEvidenceIds` — exposed at publish-check only
- Any future `*.answer`, `*.key`, `*.expected` — enforce via `DraftSchema.LEARNER_HIDDEN_KEYS`

Learner-visible: `id`, `type`, `instruction`, `title`, `required`, whitelisted `config` fields (`question`, `options`, `prompt`, `pairs.left/right`, `markers`, `imageAssetId`, `text`, `visibleSourceIds`, etc.).

## Related code files

Create:
- `com/dauviet/lesson/draft/DraftSchema.java` — constants (`CURRENT_VERSION=1`, ID pattern, hidden-keys set, objectives key)
- `com/dauviet/lesson/draft/StageType.java`, `ActivityType.java` — enums
- `com/dauviet/lesson/draft/DraftModels.java` — Jackson records for `LessonDraft`, `StageDef`, `ActivityDef`, `Completion` (or separate small files if >200 LOC)

Modify:
- none in this phase (validator builds on this in phase-02).

## Implementation steps
1. Add package `com.dauviet.lesson.draft`.
2. Define `DraftSchema` constants class (final, private ctor).
3. Define `StageType`, `ActivityType` enums.
4. Define Jackson model records (`LessonDraft`, `StageDef`, `ActivityDef`, `Completion`). Use `@JsonIgnoreProperties(ignoreUnknown = false)` to catch typos early — extra keys -> save-level error.
5. Map `STAGE_ALLOWED_ACTIVITIES` constant in `DraftSchema` (immutable map StageType -> Set<ActivityType>).
6. `LEARNER_HIDDEN_KEYS`: `Set<String>` of dotted paths or top-level names to strip.

## Todo
- [ ] `DraftSchema.java` constants
- [ ] `StageType`, `ActivityType` enums
- [ ] `LessonDraft`, `StageDef`, `ActivityDef`, `Completion` records
- [ ] Stage→activity allow-list constant
- [ ] `LEARNER_HIDDEN_KEYS` set
- [ ] Unit test: parse minimal valid draft; reject extra top-level key

## Success criteria
- Canonical JSON example in this file round-trips via `ObjectMapper` without loss.
- Hidden-keys set covers all server-only fields used in this schema.

## Risks
- Too-strict `ignoreUnknown=false` may reject future fields — accept; new fields require schema bump.
- Stage-type set may need BA additions; keep enum narrow for MVP.

## Security
- Server-only fields must never appear in any DTO returned by learner endpoints (not yet built); document this for TASK-0010.
