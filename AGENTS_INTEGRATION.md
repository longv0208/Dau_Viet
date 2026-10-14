# Integrate AI Coding Contract into existing AGENTS.md

Insert this mandatory step **immediately after** the first item under `## Start every task` in root `AGENTS.md`:

```markdown
2. Read `docs/AI_CODING_RULES.md` and enforce its naming, structure, code quality, security, verification and Definition of Done requirements across mobile/backend/admin. If it conflicts with an approved ADR or product requirement, stop and record the conflict; do not silently choose.
```

Renumber the original subsequent items (2 → 3, 3 → 4, 4 → 5). **Do not overwrite the existing AGENTS.md**: it already contains critical harness, agent and product invariants. Place the new canonical file at `docs/AI_CODING_RULES.md`.

For Claude Code and other repo-aware coding agents, root `AGENTS.md` remains the entrypoint. The rule cannot guarantee compliance by itself: enforce with PR review and executable CI checks.
