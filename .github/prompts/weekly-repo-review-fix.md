---
description: Weekly repo review fix pass — implement weekly findings on weekly/fix branch (draft PR).
agent: agent
---

# Weekly repo review fix implementation

You are implementing findings from the weekly full-repo review batch on branch `weekly/fix-<RUN_WEEK>`. A human or agent will review before merge.

Use repository edit tools only inside the provided worktree. GitHub tools are
read-only evidence sources; never comment, create an issue or pull request,
push, or otherwise publish from the agent.

OpenCode fix sessions intentionally have no shell tool because the process holds
model credentials. Use repository and GitHub read tools for reproduction evidence,
never claim a command ran when it did not, and let the deterministic controller
run `./test.sh` without credentials before it accepts the patch.

## Hard rules

- Review the **current branch state** first (diff vs `main`, existing commits, and `weekly/fix-verify-<RUN_WEEK>.json` if present). Map each `findings[]` row by `dedupe_key` and implement **only findings not yet addressed**.
- If the branch already contains partial fixes from a prior fix pass, **do not redo** completed work — finish the remainder.
- **Per-finding verification (ADR-029 §1.1, retained by ADR-034):** for each `follow_up_issues` finding you implement:
  1. Run `repro_steps` **before** editing (pre-repro). If the bug cannot be reproduced, set `verify.pre: cant_reproduce`, skip implementation for **that finding only**, and continue others.
  2. Implement the fix.
  3. Run `repro_steps` again (post-repro). Set `verify.post: fixed` only when `verify.pre` was `reproduced` or `skipped_collateral`.
- Record outcomes in **`weekly/fix-verify-<RUN_WEEK>.json`** (commit on branch).
- Record auditable ADR-034 material claims in `outcome_evidence.claims[]` using `implementation_sha: controller:current-head`; the renderer binds it to the committed fix head.
- **Do not** auto-merge. Leave changes on the branch for review.
- Prefer **minimal, focused diffs**.
- Record agent-side `test_sh` as `skipped` when shell is unavailable. The deterministic controller runs `./test.sh` before accepting an OpenCode patch.
- **Do not** edit `.github/workflows/**` on upstream — prove workflow fixes on sandbox when needed.
- Findings marked `superseded_on_main: true` describe missing paths that now exist on `main`. Do not implement them again; record `verify.pre: cant_reproduce` and cite `superseded_reason`.
- For **Gemini JSON mode**: output **valid JSON only** (include `fix_verify`).

## End-of-job sandbox (when `FIX_JOB_SANDBOX_VERIFY=true`)

After **all** findings are addressed, select environments with `docs/guides/outcome-validation.md`. Follow the post-merge sibling-sandbox rules only for default-branch GitHub behavior and record the PR/run as an outcome-evidence artifact.

## Cursor / local agent mode

Edit files directly in the working tree.

## Gemini JSON mode

Use the same required evidence shape as post-merge retro fix, including
`core_user_action`, `irreducible_side_effect`, and `cost_authorization`. Use
`run_week`, `run_kind: weekly`, and path
`weekly/fix-verify-<RUN_WEEK>.json`.

## Findings source

`weekly-review.json` — each row includes `repro_steps` for `follow_up_issues`.

## Reviewer

Remove `weekly/fix-verify-<RUN_WEEK>.json` manually before undraft/merge.

## Out of scope

- Creating follow-up GitHub issues (umbrella exists)
- ADR edits (notes in `verify.notes` only)
