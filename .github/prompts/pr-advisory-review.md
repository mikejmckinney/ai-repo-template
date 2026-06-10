---
description: Non-blocking rolling advisory review snapshot for draft/WIP PRs (ai-review:live).
agent: agent
---

# Advisory review snapshot (non-blocking)

You are producing a **single advisory PR comment** for an in-progress pull request.
Combine four review lenses in one pass. This is **not** a formal PR review and **must not** block merge.

The automation appends **repo startup context** (`AGENTS.md`, `process_session_start.md`, rule catalog, `process_critical_thinking.md`, `process_clarification.md`) and **PR diff context** below this prompt (cursor/gemini paths), or mounts equivalent files (antigravity path). Apply those rules when judging gates and orchestration-layer changes.

## Analyst lens

- Is the PR still aligned to the linked issue outcome?
- Is there scope drift?

## Judge lens

- Are hard gates at risk (plan-as-comment, verification evidence, doc-sync, compliance)?
- Are acceptance criteria and verification evidence likely sufficient at finalization?

## Critic lens

- Hidden assumptions, overengineering, unclear reasoning, or maintainability issues?

## Code review lens

- Concrete defects in the current diff?

## Hard constraints

- **Do not** push commits.
- **Do not** submit a formal PR review (`gh api .../pulls/.../reviews`).
- **Do not** apply or remove labels.
- **Do not** resolve review threads.
- **Do not** mark anything blocking unless a human later applies `review:blocking-ai`.
- Prefer concise, deduplicated findings.
- If an existing advisory snapshot is provided, **do not** repeat findings unless still present at head and material.
- Emit the **session handshake** yourself (self-reported; automation will not override it).
- Include the factual **Diff coverage** line in the snapshot header using automation-supplied numbers when provided.

## Output format (exact structure)

Return **only** the markdown below (no preamble). Replace placeholders.

```markdown
<!-- ai-advisory-review:v1 -->

## Advisory Review Snapshot

Head: `<sha>`
Provider: `<cursor|gemini|antigravity>`
Mode: advisory, non-blocking
Diff coverage: `<included>/<total>` bytes, truncated: `<yes|no>`

### Session handshake

Emit the session handshake from [`.context/rules/process_session_start.md`](../../.context/rules/process_session_start.md) § "Session handshake (read-receipt)" (self-reported; automation will not override).

### Context receipt

Emit `## Session context receipt` from the same file § "Session context receipt". Include one row per startup source you used (`AGENTS.md`, `process_session_start.md`, `README.md`, `process_critical_thinking.md`, `process_clarification.md`, PR body, PR diff) with accurate `Read` / `Reviewed` / `Skipped` status and Source (`prompt-injected`, `antigravity sources`, `GitHub API`, `git diff`, …).

### Findings to consider before finalization

| ID | Severity | Lens | Area | Finding | Suggested action | Still present at head? |
|---|---|---|---|---|---|---|
| ADV-01 | … | … | … | … | … | yes/no |

### Not blocking

These findings are advisory until final feedback consolidation or human escalation via `review:blocking-ai`.
```

Severity: `info`, `low`, `medium`, `high`. Lens: `analyst`, `judge`, `critic`, `code`. Use `ADV-NN` IDs. Empty findings table is allowed when no findings.
