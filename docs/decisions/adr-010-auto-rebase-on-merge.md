# ADR-010: Auto-rebase on merge for parallel agent PRs

## Status

Accepted

## Date

2026-04-23

## Context

ADR-009 established a five-layer Conflict-Avoidance Hierarchy plus a
sixth comment-only layer (the Parallelism Report). That ADR
deliberately stopped at "advisory" and listed *"Conflict auto-rebase
on safe (non-overlapping) histories"* as future work (issue #116).

In practice, when two agent-authored PRs run in parallel and the first
one merges, the second one must rebase to stay current with `main`.
For most agent PRs this is mechanical busywork: the two PRs touch
*different files* (soft overlap by ADR-009's classifier), so the
rebase will succeed cleanly. Today this is left to the human
reviewer, who either (a) clicks "Update branch" in the GitHub UI
(creates a merge commit, polluting history), (b) tells the agent to
rebase manually (extra Copilot session), or (c) merges anyway and
discovers conflicts in CI.

The cost is small per PR but compounds with parallel-merge volume.
Issue #116 asked for an automated solution that:

- Runs after every merge to `main`.
- Acts on the soft-overlap classification ADR-009 already produces.
- Skips PRs that would be unsafe to touch (forks, drafts, PRs with
  active review, opt-out PRs).
- Fails safe — never destroys work, never force-pushes over an
  upstream change.
- Posts a structured handoff comment on conflicts so the owning agent
  can pick it up without scraping the workflow log.

The hard-overlap case (issue #116 left this open) is *exactly* the
case where rebase failure is most likely *and* where a structured
handoff comment is most valuable. Skipping hard overlap leaves the
highest-value signal on the floor for no real safety reason — the
workflow can post the advisory comment without ever touching the
branch.

## Decision

Ship `.github/workflows/auto-rebase-on-merge.yml`, backed by the
pure-bash library `scripts/auto-rebase-overlapping.sh` (unit-tested
via `scripts/test-auto-rebase-overlapping.sh`). On every merge to
`main`, walk every other open PR and:

| Overlap | PR opted in? | Action |
|---|---|---|
| **soft** (same owned-path prefix, different files) | `auto-rebase` label present | `git rebase origin/main` → on clean, `git push --force-with-lease=<branch>:<pre-rebase-sha>` + post `auto-rebase-success` comment; on conflict, `git rebase --abort`, post `auto-rebase-conflict` comment, apply `rebase-conflict` label |
| **hard** (identical file path) | `auto-rebase` label present | Do **not** attempt rebase. Post `auto-rebase-overlap` advisory comment listing the overlapping paths + apply `rebase-conflict` label |
| **none** | (any) | Skip silently |
| any | `do-not-rebase` label present | Skip silently |
| any | `auto-rebase` label absent | Skip silently |

Always-skip conditions, evaluated before the overlap check:

1. The merged PR itself.
2. PRs from forks (force-push to a fork is impossible from the
   workflow context regardless).
3. Draft PRs.
4. PRs with at least one unresolved review thread (don't disturb a
   branch the reviewer is mid-thought on).

### Safety invariants

- **`force-with-lease=<branch>:<pre-rebase-sha>`.** The expected SHA
  is captured before the rebase starts. If anyone (human or bot)
  pushed to the branch between capture and push, the lease refuses
  and the workflow logs a warning rather than overwriting the new
  commit.
- **`git rebase --abort` on every conflict.** Working tree is left
  clean.
- **Per-PR worktree.** `git worktree add` isolates each PR's rebase
  attempt so a failed iteration can't leak state into the next one.
- **Opt-in only.** The `auto-rebase` label must be applied to each PR
  individually. There is no repo-level "always rebase everything"
  switch in v1.

### Why opt-in (not opt-out) for v1

Force-push-with-lease *is* safe in the strict sense (it refuses on
upstream change), but it's still surprising to a contributor who
didn't expect the workflow to touch their branch. Requiring an
explicit `auto-rebase` label per PR makes the consent unambiguous and
matches the pattern ADR-006 used for auto-merge.

We can flip to opt-out (`do-not-rebase` becomes the only escape
hatch) after we've observed the workflow on real PRs for a few weeks
and confirmed the surprise factor is low. The workflow already reads
the `do-not-rebase` label, so the flip is a one-line change to
`should_rebase_pr`.

### Why hard overlap gets a comment-only path (not "skip silently")

The original issue #116 said *"with a soft overlap"* and was silent
on hard overlap. We considered three options:

- (A) Soft only — match issue wording exactly.
- (B) Soft + hard — attempt rebase on both.
- (C) Soft attempts rebase; hard gets a comment-only advisory.

(B) was rejected: hard-overlap rebases will conflict almost every
time, generating noise without adding value beyond what (C) already
gives you. (A) was rejected because it leaves the most-likely-to-
conflict case with zero structured signal — exactly the case where
the owning agent most needs a handoff. (C) gets the handoff signal
without any branch-touching risk: the workflow only ever posts a
comment + applies a label. Force-push-with-lease never enters the
hard-overlap code path.

## Options Considered

### Option 1 — Workflow only (no library extraction)

Inline all the decision logic in YAML. Rejected: matches the
multi-dispatch-safety pattern (ADR-009, #114) where the same logic
choice was made *against*. Pure-bash logic is unit-testable; YAML
isn't, and the cost of regression is silent force-pushes to wrong
branches.

### Option 2 — Parse the Parallelism Report comment

Reuse the existing comment posted by `agent-parallelism-report.yml`
instead of recomputing overlap. Rejected: couples the auto-rebase
workflow to the comment's exact format, which is human-readable
markdown and not designed as a stable interface. Calling
`classify_overlap` directly is one source of truth and immune to
format drift.

### Option 3 — Block merge on hard overlap (revisit ADR-009 Option 2)

Make the Parallelism Report a required check that fails on hard
overlap. Rejected for v1 of #116: out of scope. ADR-009 explicitly
deferred this and the data we'd need to justify it (how often hard
overlap happens in legitimate workflows) doesn't exist yet.

### Option 4 — Run on a schedule instead of on merge

Cron-walk open PRs every N minutes. Rejected: latency between merge
and rebase is exactly what makes the workflow valuable. The
`pull_request: closed` trigger fires within seconds.

## Consequences

### Positive

- **Removes mechanical rebase work** from human reviewers and from
  agent sessions for the soft-overlap case.
- **Surfaces hard-overlap conflicts immediately** via a structured
  comment + filterable label, instead of waiting for the owning agent
  to discover them in CI hours later.
- **Force-with-lease keeps the branch safe** even if a human pushed
  during the workflow run.
- **Matches the multi-dispatch-safety architecture** (#114) — pure-
  bash library + thin workflow + fixture-driven unit tests — so
  reviewers and agents already know the shape.
- **Closes a known follow-up** from ADR-009 §Future work.

### Negative

- **One more workflow** in `.github/workflows/`. Mitigated: thin
  glue, all logic is testable.
- **Force-push-with-lease, even with a lease, is still a force-push.**
  Mitigated: opt-in via `auto-rebase` label; no repo-level toggle.
- **Three new labels** (`auto-rebase`, `do-not-rebase`,
  `rebase-conflict`) to maintain. Mitigated: documented in
  multi-agent-coordination.md and the workflow header.
- **Bot comment volume goes up** on parallel-merge days. Mitigated:
  `<!-- auto-rebase-* -->` upsert markers (future enhancement —
  current implementation posts a fresh comment each merge; if this
  proves noisy we'll switch to upsert via the existing
  `agent-parallelism-report.yml` pattern).

### Neutral

- **No change to ADR-009.** The Parallelism Report stays comment-only
  and advisory; this ADR adds a *separate* workflow that consumes the
  same `classify_overlap` library.
- **No new role** in `.context/rules/agent_ownership.md`.

## Implementation

The PR landing alongside this ADR ships:

- `.github/workflows/auto-rebase-on-merge.yml` — the new workflow.
- `scripts/auto-rebase-overlapping.sh` — pure-bash library:
  `should_rebase_pr`, `attempt_rebase`, `format_success_comment`,
  `format_conflict_comment`, `format_overlap_warning_comment`.
- `scripts/test-auto-rebase-overlapping.sh` — fixture-driven unit
  tests (35 assertions) wired into `test.sh`.
- `docs/guides/multi-agent-coordination.md` — new "Auto-rebase on
  merge" subsection documenting the three labels and the opt-in
  model.
- ADR-009 §Future work — updated to mark "Conflict auto-rebase" as
  shipped → ADR-010.
- `.context/rules/agent_ownership.md` "Shared / Contested Files"
  table — adds the new workflow + library + ADR.

## Verification

1. `bash scripts/test-auto-rebase-overlapping.sh` → 35/35 green.
2. `bash test.sh` → 169 passed / 0 failed (delta from previous: +1
   for the new tests entry, plus the new file existence checks).
3. `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/auto-rebase-on-merge.yml'))"`
   → OK.
4. **Live smoke test (post-merge of this PR):** open four throwaway
   PRs — A↔B touching different files under `docs/decisions/` (soft
   overlap), A↔C touching the same file (hard overlap), A↔D touching
   a backend path (none overlap). Label B/C/D `auto-rebase`. Merge
   A. Expected: B is rebased + force-pushed-with-lease + success
   comment; C gets advisory comment + `rebase-conflict` label, branch
   untouched; D is silently skipped; A is self-skipped. Negative
   path: pre-conflict B by editing the same line A edited, merge a
   fresh A2, verify B gets `auto-rebase-conflict` comment +
   `rebase-conflict` label, branch untouched.

## Future work

- **Upsert auto-rebase comments** with `<!-- auto-rebase-* -->`
  markers if multi-merge days produce noisy comment threads.
- **Promote to opt-out** (`do-not-rebase` becomes the only escape
  hatch) once the v1 opt-in model has proven stable across many
  merges.
- **Hard-block PRs with hard overlap** at merge time (ADR-009 Option
  2 — still deferred; would supersede the comment-only path here).
- **Same-line conflict detection ahead of rebase attempt** — could
  use `git merge-tree` to predict conflicts without actually starting
  the rebase. Optimization, not a correctness fix.

## References

- Issue #116 — parent.
- Issue #114 — multi-issue dispatcher; established the pure-bash
  library + fixture test pattern this ADR reuses.
- ADR-009 — Parallel multi-agent execution. ADR-010 closes one of
  ADR-009's listed follow-ups.
- ADR-006 — Auto-merge opt-in model. Same opt-in rationale.
- ADR-008 — Phase 4 default + Copilot fallback. Established the
  CLAUDE_PAT / fork-skip / marker-based comment patterns this
  workflow reuses.
- `scripts/multi-dispatch-safety.sh` — `classify_overlap` is the
  single source of truth this workflow consumes.
- `docs/guides/multi-agent-coordination.md` — Auto-rebase section.
