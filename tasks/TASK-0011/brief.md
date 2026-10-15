# TASK-0011 — Learning Engine Core: Activity Execution & Stage Transitions

Backend Learning Engine executes pinned published LessonVersion snapshots:
evaluates learner activity submissions server-side, resolves valid
stage/activity transitions over the snapshot's nextStageIds graph, and
evaluates lesson completion per published completion config.

Deliverables: runtime contracts (AttemptContext, ActivitySubmission,
ActivityResult, StageProgress, NextActivity/NextStage, LessonCompletion),
ActivityHandler registry for all 12 ActivityTypes, generic stage transition
resolver, lesson completion evaluator, learner-safe results (no hidden keys),
minimal runtime API surface, tests, docs.

Out of scope: Flutter, admin UI, full attempt lifecycle/resume APIs,
persistent progress dashboard, EXP/rewards. Coordinate with TASK-0012.

Pinned-version safety: attempts execute only their pinned LessonVersion;
republish must not affect existing attempts; malformed snapshot -> controlled
errors. Full brief in task JSON.
