---
description: Post-merge retro fix pass — implement daily findings on retro/fix branch (draft PR).
agent: agent
---

# Post-merge retro fix implementation

You are implementing findings from the daily post-merge retrospective batch on branch `retro/fix-<RUN_DATE>`. A human or agent will review before merge.

## Hard rules

- Review the **current branch state** first (diff vs `main`, existing commits, and `retro/fix-verify-<RUN_DATE>.json` if present). Map each `findings[]` row by `dedupe_key` and implement **only findings not yet addressed**.
- If the branch already contains partial fixes from a prior fix pass, **do not redo** completed work — finish the remainder.
- **Per-finding verification (ADR-029 §1.1):** for each `follow_up_issues` finding you implement:
  1. Run `repro_steps` **before** editing (pre-repro). If the bug cannot be reproduced, set `verify.pre: cant_reproduce`, skip implementation for **that finding only**, and continue others.
  2. Implement the fix.
  3. Run `repro_steps` again (post-repro). Set `verify.post: fixed` only when `verify.pre` was `reproduced` or `skipped_collateral`.
- Record outcomes in **`retro/fix-verify-<RUN_DATE>.json`** (commit on branch). Rendered into the PR `## Fix verification` section by automation.
- **Do not** auto-merge. Leave changes on the branch for review.
- Prefer **minimal, focused diffs** — fix the evidence-backed issue, no drive-by refactors.
- Run `./test.sh` when you change scripts/workflows/checks; record result in `fix-verify.json` (`test_sh`: `pass` | `fail` | `skipped`).
- **Do not** edit `.github/workflows/**` on upstream — note workflow-only findings in `verify.notes` and prove on **sandbox** when needed.
- For **Gemini JSON mode**: output **valid JSON only** with shape below (include `fix_verify` object).

## End-of-job sandbox (when `FIX_JOB_SANDBOX_VERIFY=true`)

After **all** findings are addressed:

1. Decide if any changed path is used by a **default-branch-only workflow** that local verify cannot exercise (see `docs/guides/agent-pipeline.md` § Workflow verifiability matrix). If yes, set `sandbox.needs_sync: true` in `fix-verify.json`.
2. Run `./scripts/diag-sandbox.sh` before sandbox git/gh operations.
3. Push once to sandbox branch `test/fix-retro-<RUN_DATE>` via `scripts/workflows/lib/sandbox-sync-fix-branch.sh` (or manual equivalent using `sandbox` remote + `SANDBOX_BOOTSTRAP_TOKEN`).
4. `workflow_dispatch` affected workflows on sandbox; merge sandbox PR **only** when the trigger requires default-branch merge (`push`, `pull_request.closed`, etc.).
5. Record `sandbox.issue_url`, `sandbox.pr_url`, and workflow run URLs in `fix-verify.json`. If no sandbox needed, set `sandbox.skip_reason` and use `n/a` for URLs.

## Cursor / local agent mode

When running with repository write access, **edit files directly** in the working tree. Do not only describe changes — apply them.

## Gemini JSON mode (when not editing directly)

```json
{
  "commit_message": "fix: post-merge retro daily fixes for YYYY-MM-DD",
  "file_edits": [
    {"path": "relative/path/from/repo/root", "content": "full new file contents"}
  ],
  "fix_verify": {
    "run_date": "YYYY-MM-DD",
    "run_kind": "retro",
    "findings": [
      {
        "dedupe_key": "example-key",
        "repro_steps": ["from daily-retro.json"],
        "verify": {
          "pre": "reproduced",
          "post": "fixed",
          "sandbox": "n/a",
          "notes": ""
        }
      }
    ],
    "sandbox": {
      "needs_sync": false,
      "issue_url": "n/a",
      "pr_url": "n/a",
      "skip_reason": "local verify only",
      "workflow_runs": []
    },
    "test_sh": "pass"
  }
}
```

## Findings source

The automation supplies `daily-retro.json` with a `findings[]` array. Each row has `pr`, `category`, `title`, `body`, `dedupe_key`, `repro_steps` (for `follow_up_issues`), and optional `evidence`.

The fix job may continue an **existing draft PR branch** (merged with latest `main`) or start fresh from `main`. Always verify what is already implemented on the branch before editing.

## Reviewer

Remove `retro/fix-verify-<RUN_DATE>.json` manually before undraft/merge (ephemeral review artifact).

## Out of scope

- Creating follow-up GitHub issues (umbrella issue already exists)
- ADR edits (propose in `verify.notes` only)
- Changing retro workflow triggers in this pass unless a finding explicitly requires it
