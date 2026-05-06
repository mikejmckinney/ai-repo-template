# ADR-016: Pre-Merge Verification Gate (Plan Template + Sandbox Repo)

## Status

Accepted

## Date

2026-05-06

## Context

GitHub Actions runs a workflow file from a specific git ref depending on the
trigger event in its `on:` block. For some triggers — `pull_request_review`,
`pull_request_review_comment`, `pull_request_target`, `issue_comment`,
`push`, `schedule`, `workflow_run` — the workflow file is **always** loaded
from the **default branch**, never from the PR branch under review.
(`pull_request_target` is included because GitHub loads the workflow from
the PR's *base* branch, not its head; this is also the trigger most
commonly abused for write-permission escalation.) See the trigger-event
matrix in `docs/guides/agent-pipeline.md` § "Workflow verifiability matrix"
for the canonical list.

This produces a structural verifiability gap: a change to such a workflow on
a PR branch cannot be exercised pre-merge. The new behavior only surfaces
after merge to `main`, when the trigger fires from the new code.

PR #225 paid the price for this gap: 11 rounds of bot review, each round
catching one bug in `agent-relay-reviews.yml` after the prior fix had been
merged. The cycle was forced by the trigger constraint, not by reviewer
volume — bugs in a default-branch-only workflow can only surface in a
real-world `pull_request_review` event firing against `main`. The
downstream consequence (stale-lock alert #224) was paid out of the same
budget. Engineering cost: ~11 round-trips for what should have been one PR.

The pattern is not unique to PR #225. Any future change to
`agent-fix-reviews.yml`, `agent-relay-reviews.yml`,
`agent-coordination-sync.yml`, `auto-rebase-on-merge.yml`, the scheduled
workflows, or any new `workflow_run`-chained workflow will hit the same
wall. Without a gate, "merge-and-hope" is the only option.

The existing `.github/PLAN_TEMPLATE.md` (ADR-011) captures
implementation intent before code; it does not yet require the author
to declare *how the change will be verified*. ADR-005's pre-flight
gate runs at issue-open time and validates outcome scope; it doesn't
look at workflow trigger semantics. There is no current gate that
catches "you changed a default-branch-only workflow on a PR branch and
declared the verification target as 'PR branch'."

## Decision

Adopt a **hybrid pre-merge verification gate** with three components:

1. **Plan-template Change-class field** — every Implementation Plan
   comment must declare `Change class: <code-or-docs |
   pull_request-triggered workflow | default-branch-only workflow |
   mixed>` and `Verification target: <PR branch | sandbox repo |
   both>` under the Verification section. Defaults to `code-or-docs` /
   `PR branch` for the typical PR (no friction increase for the 90%
   case).

2. **Classifier check `scripts/verify-pr.sh`** — reads the changed-path
   list (from `git diff` or `PR_FILES`), classifies each path against
   the trigger-event matrix, and compares the most-restrictive bucket
   present against the author's declaration. Exits non-zero on
   mismatch and points the author at either (a) re-declaration or (b)
   the sandbox playbook. Runs locally pre-push and (planned) in CI.

3. **Sandbox sibling repo `mikejmckinney/ai-repo-template-sandbox`** —
   identical structure to this repo with its own scoped secrets
   (sandbox-only PAT recommended; do **not** reuse the production
   `CLAUDE_PAT`). Verification flow for default-branch-only workflows:
   push the PR branch to sandbox → merge to sandbox `main` → trigger
   the relevant event there → on green, merge the original PR here.
   The playbook lives at `docs/guides/sandbox-verification.md`.

The gate is codified in:

- `AGENTS.md` § "PR completion criteria" — `Change class:
  default-branch-only workflow` requires sandbox verification before
  the PR is "done."
- `.github/prompts/pr-resolve-all.md` Phase 2 — when the PR is in the
  sandbox class, the resolution loop must call out the sandbox path.
- `.context/rules/process_doc_maintenance.md` — links
  `PLAN_TEMPLATE.md` ↔ `verify-pr.sh` ↔ the matrix as a doc-sync
  trigger.
- This ADR — the durable rationale.

## Options Considered

### Option 1: Hybrid (Plan-template + classifier + sandbox repo) — chosen

- **Pros**: Surgical fix for the structural gap; no friction for the
  ~90% of PRs that don't touch default-branch-only workflows; the
  sandbox is reusable for any future class of default-branch-only
  experiment (rulesets, secrets, branch protections); the classifier
  catches misclassification automatically.
- **Cons**: One more sibling repo to keep in approximate sync; one
  more script to maintain; one more declaration line in the Plan
  template.

### Option 2: Sub-branch off the PR branch

- **Pros**: No new external resources.
- **Cons**: Doesn't actually solve the problem. The trigger
  constraint is about *which repo's default branch* hosts the
  workflow file, not branch topology. A sub-branch isn't on `main`
  either, so it hits the same wall. Rejected.

### Option 3: "Branch-as-main" pattern (long-lived staging branch, FF to main on green)

- **Pros**: No new repo.
- **Cons**: Just renames the problem. Staging is still production for
  any cron / webhook event listening to it. Adds branch-protection
  complexity without solving the verifiability gap. Rejected.

### Option 4: Local emulation only (`act`, expanded `test.sh`)

- **Pros**: No external infra; fast feedback loop.
- **Cons**: Insufficient for end-to-end webhook flows that depend on
  GitHub-side state (PR review thread node IDs, comment IDs, App
  permissions, ruleset interactions). `act` cannot reproduce a
  `pull_request_review` event with a real `PRRT_*` thread ID. The
  classes that bit PR #225 — `FORBIDDEN` mutations, jq stream parsing
  on real bot payloads — are out of `act`'s reach. Useful as a
  complement, not as the sole solution. Rejected as the standalone
  fix.

## Consequences

### Positive

- Bugs in default-branch-only workflows surface in sandbox, not in
  this repo's `main`. The PR #225 cycle (11 rounds) cannot recur.
- The Plan template now carries the verification surface as
  first-class metadata; reviewers can see at a glance whether a PR
  needs sandbox verification.
- The classifier's exit code is wireable into pre-commit, pre-push,
  CI, and Judge's diff-gate without further design.
- The sandbox is a reusable test bed for any future
  governance experiment that can't be safely tried in production
  (e.g., new branch protection rules, new GitHub Apps, secret
  rotation playbooks).

### Negative

- **One more repo.** Sandbox needs its own secrets and (occasional)
  manual force-pushes from this `main` to stay in sync. The playbook
  documents the cadence.
- **One more script.** `verify-pr.sh` needs to track changes to the
  trigger matrix. This is contained: the matrix lives in one place
  (`agent-pipeline.md`), and the classifier's detection rules
  reference it directly. Drift will be visible in `test.sh`
  invariants.
- **Process surface increase.** Authors must pick a Change class.
  Default `code-or-docs` covers the typical PR with zero new effort;
  the matrix in `agent-pipeline.md` makes the choice unambiguous for
  the ~10% case.

### Neutral

- **Sandbox secrets hygiene.** A scoped sandbox-only PAT is
  recommended over reusing `CLAUDE_PAT` for blast-radius reasons. If
  sandbox is compromised, no production credentials leak. Documented
  in the playbook; not enforced (this ADR doesn't have the authority
  to mint a new PAT scope policy).

## Implementation

Three phases (referenced from issue #227's Acceptance Criteria):

- **Phase 1 — Plan template + classifier + matrix** (this PR):
  - `.github/PLAN_TEMPLATE.md` Verification section gains `Change
    class` and `Verification target` lines.
  - `scripts/verify-pr.sh` (new) — classifier with --paths-from /
    PR_FILES / git-diff resolution and four declared-class buckets.
  - `scripts/test-verify-pr.sh` (new) — fixture tests covering all
    classification branches and the conservative file-removed case.
  - `docs/guides/agent-pipeline.md` § "Workflow verifiability matrix"
    — canonical trigger list.
  - `test.sh` — invariants for the new files and references.
- **Phase 2 — Sandbox playbook + actual sandbox repo** (this PR for
  the playbook; the actual `gh repo create` step is documented for the
  maintainer to run because creating an external repo with secrets is
  intentionally a manual gate):
  - `docs/guides/sandbox-verification.md` (new) — setup, sync cadence,
    merge-and-exercise procedure, force-reset escape hatch, scoped-PAT
    rationale.
- **Phase 3 — Codify** (this PR):
  - `AGENTS.md` § "PR completion criteria" — pre-merge verification
    bullet referring to the matrix and playbook.
  - `.github/prompts/pr-resolve-all.md` Phase 2 — sandbox-path
    callout for default-branch-only workflow PRs.
  - `.context/rules/process_doc_maintenance.md` — doc-sync row
    linking PLAN_TEMPLATE + verify-pr.sh + matrix + playbook.
  - This ADR.

CI wiring of `verify-pr.sh` against `PR_FILES` is intentionally a
follow-up: the script and its tests ship in this PR; the workflow
step that runs it on every PR is a separate change (mechanically
straightforward but it touches `lint-and-format.yml`, which makes it
a default-branch-only workflow change requiring its own sandbox
verification — exactly the loop this ADR is opening).

## References

- Issue #227 — feature request and Implementation Plan
- PR #225 — the 11-round cycle that motivated this ADR
- Issue #224 — stale-lock alert (downstream consequence of #225)
- ADR-005 — Analyst pre-flight gate (issue-open scope check)
- ADR-011 — Plan-as-comment requirement (companion gate at PR-open
  time; ADR-016 extends the Verification section it introduced)
- ADR-014 — Pre-flight gate broadening (related family)
- `docs/guides/agent-pipeline.md` § "Workflow verifiability matrix"
- `docs/guides/sandbox-verification.md`
- `scripts/verify-pr.sh`
