---
description: Weekly repo review fix pass — implement weekly findings on weekly/fix branch (draft PR).
agent: agent
---

# Weekly repo review fix implementation

You are implementing findings from the weekly full-repo review batch on branch `weekly/fix-<RUN_WEEK>`. A human or agent will review before merge.

## Hard rules

- Review the **current branch state** first (diff vs `main`, existing commits, and any `weekly/fix-notes-<RUN_WEEK>.md`). Map each `findings[]` row by `dedupe_key` and implement **only findings not yet addressed**.
- If the branch already contains partial fixes from a prior fix pass, **do not redo** completed work — finish the remainder.
- When a finding is technically impossible, explain in `weekly/fix-notes-<RUN_WEEK>.md`.
- **Do not** auto-merge. Leave changes on the branch for review.
- Prefer **minimal, focused diffs** — fix the evidence-backed issue, no drive-by refactors.
- Run `./test.sh` when you change scripts/workflows/checks (or document why skipped).
- **Do not** edit `.github/workflows/**` — the fix job token cannot push workflow files; note workflow-only findings in `weekly/fix-notes-<RUN_WEEK>.md` instead.
- For **Gemini JSON mode**: output **valid JSON only** with shape below (no markdown fences).

## Cursor / local agent mode

When running with repository write access, **edit files directly** in the working tree. Do not only describe changes — apply them.

## Gemini JSON mode (when not editing directly)

```json
{
  "commit_message": "fix: weekly repo review fixes for YYYY-Www",
  "file_edits": [
    {"path": "relative/path/from/repo/root", "content": "full new file contents"}
  ],
  "notes": "optional markdown summary of skipped items"
}
```

## Findings source

The automation supplies `weekly-review.json` with a `findings[]` array. Each row has `scope`, `category`, `title`, `body`, `dedupe_key`, and optional `evidence`.

The fix job may continue an **existing draft PR branch** (merged with latest `main`) or start fresh from `main`. Always verify what is already implemented on the branch before editing.

## Verification

After edits, run `./test.sh` when feasible and summarize results in commit message or notes file.
