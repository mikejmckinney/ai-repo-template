---
description: Final feedback consolidation inbox for completed implementations (implementation-complete).
agent: agent
---

# Final feedback consolidation (non-blocking)

You are producing a **single Feedback Inbox PR comment** after implementation is marked complete.
Consolidate advisory snapshots, formal bot/human reviews, and inline review comments into one deduplicated inbox.

This is **not** a formal PR review. **Do not** edit code, push commits, resolve threads, apply labels, or submit `gh api .../pulls/.../reviews`.

## Your task

1. Read the collected artifacts in the automation-supplied sections below.
2. Consider **current-head findings only** (head SHA in context). Mark stale items under "Already resolved / stale feedback".
3. Deduplicate repeated findings across advisory snapshots, Gemini, Copilot, Claude/Judge, Codex, and humans.
4. Classify each distinct finding as: `must-fix`, `should-fix`, `follow-up`, `already-resolved`, or `needs-human`.
5. Produce one markdown comment body with the exact structure below.

## Hard constraints

- **Do not** push commits or open PRs.
- **Do not** submit a formal PR review.
- **Do not** apply or remove `claude-fix`, `implementation-complete`, or `review:blocking-ai`.
- **Do not** resolve review threads.
- Prefer actionable, deduplicated rows with stable `FB-NN` IDs.
- Emit the **session handshake** yourself (self-reported; automation will not override it).
- If a prior feedback inbox exists, merge forward — do not lose still-valid items.

## Output format (exact structure)

Return **only** the markdown below (no preamble). Replace placeholders.

```markdown
<!-- ai-feedback-inbox:v1 -->

## Final Feedback Inbox

Head reviewed: `<sha>`
Mode: final consolidation, non-blocking unless a human applies `review:blocking-ai`

### Session handshake

Emit the current handshake from [`AGENTS.md`](../../AGENTS.md). Do not append a
context-receipt table.

### Must fix before merge

| ID | Source(s) | File/area | Finding | Recommended action |
|---|---|---|---|---|

### Should fix when low-risk

| ID | Source(s) | File/area | Finding | Recommended action |
|---|---|---|---|---|

### Follow-up issue candidates

| ID | Source(s) | Area | Suggested issue |
|---|---|---|---|

### Already resolved / stale feedback

| Source | Why stale |
|---|---|

### Next steps (human)

- Review this inbox; address `must-fix` items before merge.
- Optionally apply `claude-fix` for automated remediation (existing `agent-fix-reviews.yml` rules apply).
- Apply `review:blocking-ai` only when a human wants AI findings to block merge.
```

Empty tables are allowed when no items qualify for that section.
