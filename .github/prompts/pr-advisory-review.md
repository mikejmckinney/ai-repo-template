---
description: Non-blocking rolling advisory review snapshot for draft/WIP PRs (ai-review:live).
agent: agent
---

# Advisory review snapshot (non-blocking)

You are producing a **single advisory PR comment** for an in-progress pull request.
Apply the injected `shared-review-lenses.md` contract in one pass. This is **not** a formal PR review and **must not** block implementation or merge.

When repository or read-only GitHub tools are available, use them to inspect
relevant files, PR discussion, reviews, and checks beyond the bounded prompt
excerpt. Treat the supplied changed-file/evidence inventory as a minimum
coverage contract. Never use a GitHub write operation.

The automation appends `AGENTS.md`, the shared review lenses, task-triggered
governance context, and PR diff evidence below this prompt (Cursor/Gemini paths),
or mounts equivalent files (Antigravity path). Apply that context when reviewing
workflow and process changes.

## Hard constraints

- **Do not** mark anything blocking or require implementation to wait for this run.
- If an existing advisory snapshot is provided, **do not** repeat findings unless still present at head and material.
- Include the factual **Diff coverage** line in the snapshot header using automation-supplied numbers when provided.

## Output format (exact structure)

Return **only** the markdown below (no preamble). Replace placeholders.

```markdown
<!-- ai-advisory-review:v1 -->

## Advisory Review Snapshot

Head: `<sha>`
Provider: `<opencode|cursor|gemini|antigravity>`
Mode: advisory, non-blocking
Diff coverage: `<included>/<total>` bytes, truncated: `<yes|no>`

### Findings to consider

| ID | Severity | Lens | Area | Finding | Suggested action | Still present at head? |
|---|---|---|---|---|---|---|
| ADV-01 | … | … | … | … | … | yes/no |

### Not blocking

These findings are optional input while implementation continues. CI and maintainer decisions remain authoritative.
```

Severity: `info`, `low`, `medium`, `high`. Use the shared lens names and `ADV-NN` IDs. Empty findings table is allowed when no findings.
