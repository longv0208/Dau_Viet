---
title: "Phase 07 — Docs + verification"
description: "Write HTML_ANIMATION_GUIDE.md, update PROGRESS/CHANGELOG/architecture docs, run final verification."
status: pending
priority: P2
effort: 1h
---

# Phase 07 — Docs + Verification

## Context Links

- Docs conventions: `docs/PROJECT_OVERVIEW.md`, `docs/TECH_STACK.md`, `docs/CODING_RULES.md`, `docs/AGENT_WORKFLOW.md`
- Documentation rules: `C:\Users\FPTSHOP\.claude\rules\documentation-management.md`
- Existing docs to touch: `docs/project-changelog.md`, `docs/system-architecture.md`, `docs/development-roadmap.md`, `docs/backend-runbook.md` (if exists).
- Plain markdown, NO emojis/icons.

## Overview

- Priority: P2 — final polish.
- Status: pending.
- Brief: document the HTML animation feature for non-devs (Vietnamese-friendly), update project changelog/architecture, run end-to-end verification.

## Key Insights

- Repo uses Vietnamese in user-facing strings; docs mix EN+VN — write `HTML_ANIMATION_GUIDE.md` primarily in Vietnamese (matches in-app copy) with EN technical terms where standard.
- `docs/PROGRESS.md` is generated from `tasks/<id>/task.json` — do NOT edit by hand; update `task.json` status instead.

## Requirements

### Create: `docs/HTML_ANIMATION_GUIDE.md`

Audience: content team + devs. Sections:

1. **Giới thiệu** — what HTML animations are, when to use vs RIVER_TIDE/JOURNEY_MAP.
2. **Yêu cầu tệp HTML** — self-contained, ≤15 MB, UTF-8, no external resources (script/link/img src must be `data:`), `<script src>` not allowed, relative paths not allowed.
3. **Cách tải lên** — drag-drop into "Tải hoạt họa HTML lên" zone in `/animations`.
4. **Xem trước** — sandboxed preview, viewport toggles, replace file.
5. **Xuất bản** — publish flow produces immutable version; versions cannot be edited, only superseded.
6. **Dùng trong bài học** — pick in Lesson Builder animation picker.
7. **Hiển thị trên app** — Flutter WebView, authenticated fetch, checksum verification.
8. **Giới hạn** — no `localStorage`/`cookies` in iframe/WebView, no external CDNs, no `fetch()` calls (inline all assets as `data:` URIs); what to do if animation needs network.
9. **Bảo mật** — sandbox attrs, CSP, checksum, authentication.
10. **Troubleshooting** — common rejection reasons table (line snippet + code + how to fix).

### Update existing docs

- `docs/project-changelog.md` — add entry for HTML_WEBVIEW feature.
- `docs/system-architecture.md` — add row/section for `animation_scene_html` + `animation_scene_version_html` tables + `HTML_WEBVIEW` renderer + learner endpoint.
- `docs/development-roadmap.md` — mark relevant milestone/task as done (if tracked).
- `docs/TECH_STACK.md` — add `webview_flutter` to mobile stack.
- `docs/backend-runbook.md` — document `dauviet.animations.html.max-bytes` config knob + new endpoints.

### Task bookkeeping

- Update `tasks/<id>/task.json` for the relevant TASK (likely TASK-0019 or next ID — confirm with user at handoff).
- Regenerate `docs/PROGRESS.md` via its generator script if one exists (check `scripts/` or run manually documented steps).

## Implementation Steps

1. Write `docs/HTML_ANIMATION_GUIDE.md` (Vietnamese-first, plain markdown).
2. Update `docs/project-changelog.md`, `docs/system-architecture.md`, `docs/development-roadmap.md`, `docs/TECH_STACK.md`.
3. Update `docs/backend-runbook.md` with new config + endpoints.
4. Verify: `git status` shows only expected files; `git diff --check` clean.
5. Final smoke (manual):
   - Start backend: `mvn -pl dau-viet-backend spring-boot:run`.
   - Start admin: `cd dau-viet-admin && pnpm dev`.
   - Upload sample HTML, preview, publish.
   - Build Flutter: `cd dau-viet-mobile && flutter run` — pick scene in lesson → WebView renders.

## Todo

- [ ] `docs/HTML_ANIMATION_GUIDE.md` written.
- [ ] `docs/project-changelog.md` updated.
- [ ] `docs/system-architecture.md` updated.
- [ ] `docs/TECH_STACK.md` updated (webview_flutter).
- [ ] `docs/backend-runbook.md` updated (config + endpoints).
- [ ] `docs/development-roadmap.md` updated.
- [ ] `tasks/<id>/task.json` status updated.
- [ ] End-to-end smoke verified.

## Success Criteria

- New guide readable by non-dev content team; covers all rejection codes.
- Changelog entry written in plain style matching repo conventions.
- Architecture doc reflects new tables + endpoint.
- `git diff --check` clean, no stray files.

## Risks

- Generated `PROGRESS.md` regeneration step unknown — ask user or check `scripts/` before assuming.
- Documentation drift — keep `HTML_ANIMATION_GUIDE.md` short and link to code instead of duplicating inline.

## Security Considerations

- Guide explicitly documents that uploaded HTML runs untrusted-code in user's WebView; recommend content-team review step before publish.
- No secrets/API keys in any doc.

## Next Steps / Handoff

- After verification, hand off to `code-reviewer` agent for review against this plan.
- If approved, document any deviations in `task.json` notes.
