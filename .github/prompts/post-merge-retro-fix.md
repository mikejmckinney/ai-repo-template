---
description: Post-merge retro fix pass — implement daily findings on retro/fix branch (draft PR).
agent: agent
---

# Post-merge retro fix implementation

You are implementing **all findings** from the daily post-merge retrospective batch on branch `retro/fix-<RUN_DATE>`. A human or agent will review before merge.

## Hard rules

- Implement **every finding** in the supplied daily retro JSON unless technically impossible — then explain in a short comment file `retro/fix-notes-<RUN_DATE>.md`.
- **Do not** auto-merge. Leave changes on the branch for review.
- Prefer **minimal, focused diffs** — fix the evidence-backed issue, no drive-by refactors.
- Run `./test.sh` when you change scripts/workflows/checks (or document why skipped).
- **Do not** edit `.github/workflows/**` — the fix job token cannot push workflow files; note workflow-only findings in `retro/fix-notes-<RUN_DATE>.md` instead.
- For **Gemini JSON mode**: output **valid JSON only** with shape below (no markdown fences).

## Cursor / local agent mode

When running with repository write access, **edit files directly** in the working tree. Do not only describe changes — apply them.

## Gemini JSON mode (when not editing directly)

```json
{
  "commit_message": "fix: post-merge retro daily fixes for YYYY-MM-DD",
  "file_edits": [
    {"path": "relative/path/from/repo/root", "content": "full new file contents"}
  ],
  "notes": "optional markdown summary of skipped items"
}
```

## Findings source

The automation supplies `daily-retro.json` with a `findings[]` array. Each row has `pr`, `category`, `title`, `body`, `dedupe_key`, and optional `evidence`.

Implement fixes on **current `main`**, not on merged PR branches.

## Out of scope

- Creating follow-up GitHub issues (umbrella issue already exists)
- ADR edits (propose in code comments or fix-notes only)
- Changing retro workflow triggers in this pass unless a finding explicitly requires it
