---
description: Post-merge retro fix pass — implement daily findings on retro/fix branch (draft PR).
agent: agent
---

# Post-merge retro fix implementation

You are implementing findings from the daily post-merge retrospective batch on branch `retro/fix-<RUN_DATE>`. A human or agent will review before merge.

Use repository edit tools only inside the provided worktree. GitHub tools are
read-only evidence sources; never comment, create an issue or pull request,
push, or otherwise publish from the agent.

OpenCode fix sessions intentionally have no shell tool because the process holds
model credentials. Use repository and GitHub read tools for reproduction evidence,
never claim a command ran when it did not, and let the deterministic controller
run `./test.sh` without credentials before it accepts the patch.

## Hard rules

- Review the **current branch state** first (diff vs `main`, existing commits, and `retro/fix-verify-<RUN_DATE>.json` if present). Map each `findings[]` row by `dedupe_key` and implement **only findings not yet addressed**.
- Automation may pre-mark findings with `superseded_on_main: true` in `daily-retro.json`. For those rows, set `verify.pre: cant_reproduce` with `verify.notes` citing `superseded_reason` — **do not re-implement**.
- If the branch already contains partial fixes from a prior fix pass, **do not redo** completed work — finish the remainder.
- **Per-finding verification (ADR-029 §1.1, retained by ADR-034):** for each `follow_up_issues` finding you implement:
  1. Run `repro_steps` **before** editing (pre-repro). If the bug cannot be reproduced, set `verify.pre: cant_reproduce`, skip implementation for **that finding only**, and continue others.
  2. Implement the fix.
  3. Run `repro_steps` again (post-repro). Set `verify.post: fixed` only when `verify.pre` was `reproduced` or `skipped_collateral`.
- Record outcomes in **`retro/fix-verify-<RUN_DATE>.json`** (commit on branch). Rendered into the PR `## Fix verification` section by automation.
- Record `outcome_evidence.claims[]` for every material result using the ADR-034 fields below. Use `implementation_sha: controller:current-head`; deterministic rendering binds it to the committed fix head. External-state/runtime claims require an artifact and cannot be prose-only.
- **Do not** auto-merge. Leave changes on the branch for review.
- Prefer **minimal, focused diffs** — fix the evidence-backed issue, no drive-by refactors.
- Record agent-side `test_sh` as `skipped` when shell is unavailable. The deterministic controller runs `./test.sh` before accepting an OpenCode patch.
- **Do not** edit `.github/workflows/**` on upstream — note workflow-only findings in `verify.notes` and prove on **sandbox** when needed.
- For **Gemini JSON mode**: output **valid JSON only** with shape below (include `fix_verify` object).

## End-of-job sandbox (when `FIX_JOB_SANDBOX_VERIFY=true`)

After **all** findings are addressed:

1. Decide if any changed path is used by a **default-branch-only workflow** that local verify cannot exercise (see `docs/guides/agent-pipeline.md` § Workflow verifiability matrix). If yes, set `sandbox.needs_sync: true` in `fix-verify.json`.
2. Run `./scripts/diag-sandbox.sh` before sandbox git/gh operations.
3. Push once to sandbox branch `test/fix-retro-<RUN_DATE>` via `scripts/workflows/lib/sandbox-sync-fix-branch.sh` (or manual equivalent using `sandbox` remote + `SANDBOX_BOOTSTRAP_TOKEN`).
4. `workflow_dispatch` affected workflows on sandbox; merge sandbox PR **only** when the trigger requires default-branch merge (`push`, `pull_request.closed`, etc.).
5. Keep `sandbox.*` as operational sync metadata. Record sandbox PR/run locators as material claims in `outcome_evidence.claims[]`; if no sibling adapter is needed, record the actual local/preview/fresh-state environment instead.

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
    "outcome_evidence": {
      "claims": [
        {
          "material_claim": "The reported defect no longer reproduces.",
          "environment": "isolated fix worktree",
          "why_representative": "The original repro steps execute against the candidate fix.",
          "implementation_sha": "controller:current-head",
          "action_performed": "Ran the recorded repro steps before and after implementation.",
          "expected_result": "The pre-repro fails and the post-repro passes.",
          "observed_result": "Record the actual bounded result.",
          "artifact": "embedded:fix-verification-table",
          "artifact_type": "per-finding-command-record",
          "redaction": "No secret-bearing raw output included.",
          "retention": "PR lifetime.",
          "evidence_reuse": "none",
          "result": "pass"
        }
      ]
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
