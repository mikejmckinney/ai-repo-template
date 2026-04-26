# ADR-014: Auto-merge waits for late bot reviews (grace period + opt-out)

## Status

Accepted

## Date

2026-04-26

## Context

`agent-auto-merge.yml` fires from a `workflow_run` trigger on
`["CI Tests", "Lint and Format", "Auto-Fix Reviews (Claude)"]`. On
small/fast PRs (~30s CI), this means the merge call runs the moment
required CI is green. But three of the bot reviewers we depend on —
`gemini-code-assist`, `copilot-pull-request-reviewer`, and
`chatgpt-codex-connector` — post their reviews 1–3 min later via webhook
flows that do **not** trigger any GitHub Actions workflow. Their reviews
therefore land on a closed/merged PR; the branch is gone, `claude-fix`
can't check it out, and the findings are silently dropped from the
resolution pipeline.

PR #181 is the recorded incident: 5 bot reviews posted post-merge,
4 of them legitimate findings, all of which had to be re-discovered by
hand and shipped in a follow-up PR. Issue #182 documents the timeline
and proposes three options:

- **Option A** — auto-merge waits ~3 min for late reviewers, with a
  per-PR escape hatch for trivial PRs.
- **Option B** — proceed to merge, then file post-merge bot reviews as
  follow-up issues.
- **Option C** — document as a known limitation, add a label after merge
  to surface affected PRs.

ADR-006 established the opt-in `auto-merge` label model. ADR-008
established Phase 4 thread auto-resolution and the `CLAUDE_PAT` fallback
for Copilot's missing scope. This ADR is adjacent to both: it preserves
the opt-in model and the existing readiness checks, and addresses a race
condition that those earlier decisions did not anticipate.

## Decision

**Adopt Option A: auto-merge holds the merge call up to 180 s after the
readiness check passes, polling every 60 s for new reviews from the
slow-bot allow-list. The wait exits early on the first poll where
≥1 in-allowlist review is detected. PRs labeled `auto-merge-fast` skip
the wait entirely.**

Concrete rules:

1. **Insertion point.** A new step "Wait for late bot reviews" runs
   after the readiness check (`Find PRs ready to merge`) and before
   `Squash and merge`, gated by `if: steps.find.outputs.eligible == 'true'`.
2. **Allow-list.** `gemini-code-assist`, `copilot-pull-request-reviewer`,
   `chatgpt-codex-connector`, `codex`. Compared after stripping the
   `[bot]` suffix and lowercasing, per the canonical normalization rule
   in `.github/prompts/pr-resolve-all.md:168`. `claude` is intentionally
   **excluded** because `claude.yml` already gates merge via the
   existing `workflow_run` trigger on "Auto-Fix Reviews (Claude)";
   waiting again here would double-count and slow merges by another
   ~3 min when Claude has already reviewed.
3. **Poll budget.** `MAX_POLLS=3`, `POLL_INTERVAL=60`. Total upper
   bound 180 s — matches the relay-settle window in
   `agent-relay-reviews.yml:214` and `agent-relay-reviews.yml:1010`.
4. **Early exit.** Proceed to merge as soon as ≥1 review from the
   allow-list is detected since the head-commit timestamp.
5. **Graceful timeout.** On poll budget exhaustion, proceed to merge
   anyway — the wait is *advisory*, not a merge-blocker. Reviews that
   arrive after the merge call lose the race; this is the same outcome
   as today, just with a smaller blast radius.
6. **Escape hatch.** New label `auto-merge-fast` (purple, `#5319E7`).
   When present, the wait step logs `fast-path` and exits 0 immediately.
   For trivial PRs where slow-bot feedback is acceptable to lose.
7. **Concurrency.** No change. The existing
   `cancel-in-progress: true` (`agent-auto-merge.yml:102–104`) cancels
   an in-flight wait when a `pull_request_review` event triggers a
   re-fire; the fresh run re-evaluates eligibility against the
   updated review set, including the existing
   unresolved-thread gate (`agent-auto-merge.yml:292–364`).

## Consequences

**Positive:**

- The PR-#181 race goes away for the common case: gemini and
  copilot-pr-reviewer typically post within 60–120 s of CI completion,
  which falls inside the 180 s window with margin.
- No extra dependency or new workflow file. The fix is one additive
  step in an existing workflow plus one new label.
- Graceful timeout means the change can never make merging *worse* than
  today — at the limit, behavior matches the pre-change "merge as soon
  as eligible" path.
- The `auto-merge-fast` escape hatch preserves the original fast-path
  for genuinely trivial PRs and gives operators a per-PR control
  surface (no env-var tuning required).
- PR audit trail is complete: every PR points back to a documented intent.

**Negative:**

- Slows the median auto-merge by 60–180 s for every non-`auto-merge-fast`
  PR. Compounds across high-throughput repos. Operators can opt out
  per-PR; we do not provide a repo-wide kill switch in v1.
- The early-exit-on-first-review heuristic has a known weakness: per
  the PR #181 timeline, gemini posted at +1 m 39 s and
  copilot-pr-reviewer at +3 m 06 s — 1 m 27 s apart. The early-exit
  would proceed at gemini's review and miss copilot's. This is an
  accepted v1 trade-off; alternatives (wait for ≥2 distinct bots, or
  wait the full 180 s always) are deferred (see "Out of scope" below).
- A bot that *never* reviews a particular PR (e.g. chatgpt-codex-connector
  is offline that day) will burn the full 180 s every time the other
  bots are also late or absent. This is unavoidable without a per-bot
  expectation list, which would be brittle to maintain.
- Adds a new workflow step that depends on `gh pr view --json reviews`
  returning timely data. Failures (network, GitHub outage) fall back to
  the graceful-timeout path — no merge block, but no wait either. Logged
  as `::warning::` for operator visibility.

**Neutral:**

- ADR-006 (opt-in model) is unchanged. ADR-008 (Phase 4 fallback) is
  unchanged. This ADR does not supersede or weaken either.
- The 60 s poll interval was chosen to mirror the relay settle window;
  finer-grained polling (e.g. 15 s) would reduce wasted wall-clock when
  reviews arrive mid-cycle, at the cost of more `gh` API calls. Not
  worth tuning until a real workload shows it matters.

## Out of scope (deferred)

- **Wait-for-N-distinct-bots heuristic.** Mitigates the early-exit
  weakness above. Track if PR #181-style multi-bot races recur after
  this lands.
- **Option B (file post-merge reviews as follow-up issues).** Orthogonal
  to the wait. Worth a separate issue if the early-exit window still
  loses reviews in practice.
- **Repo-wide kill switch.** No env var or repo variable to disable the
  wait globally; the per-PR `auto-merge-fast` label is the operator's
  only control surface in v1.

## Verification

- [ ] **V1 (file integrity):** `bash test.sh` from repo root passes
  the YAML-header check on `agent-auto-merge.yml` and the file-existence
  check on this ADR (paths in `REQUIRED_FILES`). Pre-existing
  git-signing failure in `test-auto-rebase-overlapping.sh` is not
  introduced by this change.
- [ ] **V2 (live race test, default path):** Open a small docs-only PR
  labeled only `auto-merge`. Confirm via the workflow-run logs:
  - "Wait for late bot reviews" step runs.
  - Either an early-exit line ("At least one slow-bot review has
    landed; proceeding to merge.") OR the timeout line ("Timeout
    reached after 180 s; proceeding to merge (graceful).").
  - On at least 1 of 3 trial PRs, a slow-bot review (gemini or
    copilot-pr-reviewer) is visible on the PR before the merge commit
    appears in `git log`.
- [ ] **V3 (escape-hatch test):** Open a small PR with both
  `auto-merge` and `auto-merge-fast`. Confirm the workflow-run log
  shows `fast-path: auto-merge-fast label present, skipping bot-review wait.`
  and that the merge fires without the 180 s pause.
- [ ] **V4 (concurrency test):** During a wait window, manually submit
  a `pull_request_review` (e.g. an Approve from a maintainer). Confirm
  the in-flight workflow run is cancelled and a fresh run re-evaluates
  eligibility; the unresolved-thread gate (existing) re-runs against
  the updated review set.
- [ ] **V5 (label creation):** `bash scripts/setup.sh` is idempotent;
  re-running it after this change creates the `auto-merge-fast` label.
  `gh label list --json name --jq '.[].name'` shows the label.

## References

- Tracking issue: #182 (auto-merge races past slow bot reviewers)
- Recorded incident: PR #181 timeline (5 lost reviews, 4 legitimate
  findings)
- Sibling decisions:
  - `docs/decisions/adr-006-auto-merge-opt-in-model.md` (the opt-in
    model this ADR extends)
  - `docs/decisions/adr-008-phase4-default-and-copilot-fallback.md`
    (Phase 4 + `CLAUDE_PAT` fallback, related race shape)
- Related issues: #177 (Phase 4 race on late delegate commits), #175
  (auto-merge re-evaluation after claude-fix)
- Implementation files:
  - `.github/workflows/agent-auto-merge.yml` (insertion between L378–L380)
  - `scripts/setup.sh` (new label, L350)
  - `.github/prompts/pr-resolve-all.md:168` (allow-list normalization rule)
  - `.github/workflows/agent-relay-reviews.yml:232` (allow-list shape)
  - `.github/workflows/agent-relay-reviews.yml:1010–1026` (poll-loop pattern)
