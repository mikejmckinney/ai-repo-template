# ADR-006: Auto-merge is opt-in via `auto-merge` label (custom workflow, any branch)

## Status

Accepted

## Date

2026-04-21

## Context

Issue [#50](https://github.com/mikejmckinney/ai-repo-template/issues/50) asked
for `merge-if-ready` — automatic PR merging once the pipeline's five
readiness conditions are met (CI green, no unresolved threads, no
`CHANGES_REQUESTED`, not draft, not blocked). Two forces were in tension:

1. **The existing workflow was too aggressive.** `agent-auto-merge.yml` ran
   on every `copilot/*` PR and merged unless a `no-auto-merge` label was
   present. That "opt-OUT" posture meant any Copilot PR that happened to
   pass CI could land without a human ever choosing to merge it — the
   "runaway merge" risk the issue flags.
2. **GitHub's native "Allow auto-merge" doesn't fit our bot-review loop.**
   Native auto-merge fires the moment required approvals + CI are green,
   which in practice closes the PR before Gemini Code Assist, Claude
   auto-review, and Copilot code review have finished posting their
   reviews. Our pipeline is specifically designed to collect and act on
   those bot reviews (via `agent-fix-reviews.yml`), so native auto-merge
   would skip the reviewers we care about.

In addition, the `copilot/*`-only branch restriction meant PRs from
`claude/*` branches (this very branch, for example) and from human
contributors couldn't be auto-merged at all — an inconsistency with the
issue's framing of "merge when all readiness signals are green".

## Decision

We will keep the custom `agent-auto-merge.yml` workflow and change its
activation model from **opt-out on `copilot/*`** to **opt-in on any
branch**, gated by an explicit `auto-merge` label. Specifically:

- Remove the `branch starts with copilot/` restriction.
- Invert the label check: skip unless the PR carries an `auto-merge`
  label (instead of skip if it carries `no-auto-merge`).
- Keep all five eligibility conditions unchanged — the workflow's
  per-PR readiness logic was already correct; only the activation model
  changes.
- Keep the fork-origin guard (defense in depth: a maintainer could
  accidentally label a fork PR, and `workflow_run` / `pull_request_target`
  run in the base-repo context with secrets).
- Gate the "drain Copilot queue" post-merge step on the merged branch
  starting with `copilot/`. A non-`copilot/*` merge doesn't free a
  Copilot slot, so promoting a queued issue at that point would create
  an off-by-one between concurrent budget and slot availability.

The `auto-merge` label is created idempotently by `scripts/setup.sh`
so new repos pick it up automatically.

## Options Considered

### Option 1: GitHub native "Allow auto-merge" repo setting

- **Pros**: zero custom code; UI-familiar; handled by GitHub itself.
- **Cons**: fires as soon as required approvals + CI pass, which in
  our pipeline means before the bot reviewers (Gemini / Claude / Copilot
  code review) have finished posting their reviews and before
  `agent-fix-reviews.yml` can resolve anything. Also lacks a custom
  readiness predicate (e.g. no unresolved review threads).
- **Verdict**: rejected — incompatible with the bot-review loop.

### Option 2: Keep `copilot/*`-only opt-OUT (status quo before this change)

- **Pros**: no label churn; default behavior matches Copilot's rapid
  iteration cadence.
- **Cons**: runaway-merge risk (every green Copilot PR lands unless
  explicitly blocked); doesn't cover `claude/*` or human-initiated PRs;
  the `no-auto-merge` block label is easy to forget at PR-open time.
- **Verdict**: rejected — it's the exact problem the issue asks us to
  fix.

### Option 3: Custom workflow, opt-IN via `auto-merge` label on any branch (chosen)

- **Pros**: explicit per-PR intent (no accidents); all five readiness
  conditions still enforced; works for any branch prefix; bot reviews
  always get the chance to run before merge; label can be applied at
  PR-open time or retroactively.
- **Cons**: requires someone (maintainer or future automation) to apply
  the label; `no-auto-merge` becomes dead; contributors must learn the
  new label.
- **Verdict**: chosen. The trade-off is a single labeling step in
  exchange for eliminating the runaway-merge failure mode.

### Option 4: Hybrid — native auto-merge triggered by workflow after bot reviews

- **Pros**: delegates the actual merge step to GitHub.
- **Cons**: higher complexity (workflow needs to enable native
  auto-merge only after bot reviews settle); no new capability over
  Option 3; two systems to reason about when debugging a merge that
  didn't happen.
- **Verdict**: rejected — complexity without corresponding benefit.

## Consequences

### Positive

- Explicit per-PR intent: no PR merges without a maintainer or
  automation applying the label.
- Bot reviewers always get to run — we never close a PR before
  Gemini / Claude / Copilot code review have posted.
- No branch-name coupling: `claude/*`, `feature/*`, and human branches
  are all eligible once labeled.
- Safer default: a new repo initialized from this template will not
  auto-merge anything until labeling is turned on.

### Negative

- Requires a labeling step per PR (manual for now; could be automated
  in a follow-up — e.g., `agent-auto-ready.yml` could apply the label
  when flipping a Copilot PR from draft to ready).
- The old `no-auto-merge` label becomes dead weight until repos prune
  it.
- Contributors used to the old opt-OUT model must learn to apply the
  new label.

### Neutral

- The Copilot queue-drain step still only fires when a `copilot/*`
  branch merges. This is orthogonal to the label change; the gate just
  moves from "implicit via branch filter" to "explicit via step `if`".

## Implementation

- [x] Rewrite header comment block in `.github/workflows/agent-auto-merge.yml`.
- [x] Update the `pull_request_target: labeled/unlabeled` trigger comment.
- [x] Remove the `copilot/*` branch restriction in the eligibility step.
- [x] Invert the label check from `no-auto-merge` (block) to `auto-merge`
      (allow).
- [x] Keep the fork-origin guard.
- [x] Gate the "Drain Copilot queue" step on
      `startsWith(steps.find.outputs.branch, 'copilot/')`.
- [x] Update `docs/guides/agent-pipeline.md` (Step 5, label
      table, troubleshooting, manual-intervention table).
- [x] Update the labels comment in `.github/workflows/agent-relay-reviews.yml`.
- [x] Add `_ensure_label "auto-merge"` to `scripts/setup.sh` and update
      the fallback warning list.

## References

- [Issue #50](https://github.com/mikejmckinney/ai-repo-template/issues/50) — the request this ADR answers.
- `docs/guides/agent-pipeline.md` — operator-facing
  description of the pipeline.
- ADR-003 — prior precedent for keeping custom pipeline workflows
  instead of delegating to GitHub features.
