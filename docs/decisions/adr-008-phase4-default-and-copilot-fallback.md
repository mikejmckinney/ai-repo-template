# ADR-008: Phase 4 runs by default; Copilot path gets relay-side fallback

## Status

Accepted

## Date

2026-04-22

## Context

ADR-007 introduced **Phase 4** of `.github/prompts/pr-resolve-all.md` —
auto-resolution of bot-authored review threads after a successful fix
cycle. It made two design choices that this ADR revisits:

1. **Phase 4 was gated on a per-PR opt-in label, `auto-resolve-threads`,
   applied alongside `claude-fix` or `copilot-relay`.**
2. **Phase 4 was specified as agent-agnostic**, on the assumption that
   either the Claude path or the Copilot path could fire the
   `addPullRequestReviewThreadReply` and `resolveReviewThread` GraphQL
   mutations under the agent's own token.

Two pieces of post-ship evidence make it worth re-deciding now:

**The label adds friction without adding safety.** ADR-007's per-thread
gate (allow-listed bot author + Phase 2 status `✅ Fixed` + verification
green + thread not already resolved) is the actual safety mechanism.
The label is paranoia on top of paranoia. Worse, applying it alongside
`copilot-relay` in a single API call fires two `pull_request.labeled`
events in quick succession; `agent-relay-reviews.yml` has
`concurrency.cancel-in-progress: true`, so the first matching relay run
gets cancelled and the `@copilot follow` comment is never posted. We
documented the workaround ("apply labels one-at-a-time, with
`copilot-relay` last") in `docs/guides/agent-pipeline.md` rather than fix the
underlying friction. There is no real workflow where a maintainer would
want the fix procedure to run **and** mark items `✅ Fixed` **and** leave
the corresponding bot threads dangling. Maintainers who disagree with a
specific resolution can unresolve the thread; the audit-trail reply
makes that trivial.

**The Copilot-path Phase 4 is non-functional end-to-end.** V3 verification
on PR #99 showed the Copilot cloud agent's token returns `FORBIDDEN` on
both required mutations (verbatim diagnosis from Copilot's own Phase 3
Resolution Report: "`addPullRequestReviewThreadReply` +
`resolveReviewThread` both returned `FORBIDDEN` — Copilot cloud agent
token lacks `pull-requests:write` scope"). The Phase 4 **gate logic** is
correct on the Copilot path — allow-list match, status check, thread
state evaluation, audit-reply drafting all happened. Only the mutation
calls themselves fail. Tracked in
[issue #100](https://github.com/mikejmckinney/ai-repo-template/issues/100).

The relay workflow that triggered Copilot, `agent-relay-reviews.yml`,
already supplies `CLAUDE_PAT` and uses it to post the `@copilot follow`
comment. That same token has `pull-requests: write` and is the obvious
candidate for a fallback that completes Copilot's intent.

## Decision

ADR-008 makes two coupled changes that supersede the corresponding
parts of ADR-007:

### 1. Drop the `auto-resolve-threads` label. Phase 4 runs by default.

Whenever `pr-resolve-all.md` is invoked (Claude path or Copilot path),
Phase 4 runs unconditionally. The per-thread gate from ADR-007 is
preserved verbatim and remains the only safety mechanism — it has never
silenced a human thread or an ambiguous fix in any verification run
(V1–V6).

The Phase 4 report section in the Phase 3 Resolution Report becomes
unconditional too: there is no longer a "Label `auto-resolve-threads`
not present — skipping thread resolution." variant. Every Phase 3
report includes the Phase 4 table.

### 2. Relay-side fallback for the Copilot path.

`agent-relay-reviews.yml` gains a second job, `phase4-fallback`,
triggered by `issue_comment.created`. Job-level guards (`if:`):

- The PR carries `copilot-relay`.
- The comment author is one of the Copilot SWE-agent identities
  (`copilot`, `Copilot`, `copilot[bot]`, `copilot-swe-agent`,
  `copilot-swe-agent[bot]`) — every form GitHub may emit across
  REST/GraphQL and the Copilot product surfaces.

Runtime guards (job steps, fail-closed, before any `CLAUDE_PAT` use):

- **Fork guard.** A first step uses the default read-only
  `GITHUB_TOKEN` to fetch the PR's `isCrossRepository` flag and aborts
  if the head ref is from a fork. The job-level `if:` cannot perform
  this check — `github.event.repository.full_name` always equals
  `github.repository` on `issue_comment` because the comment lives on
  the upstream PR — so the runtime check is the actual fork guard for
  `CLAUDE_PAT`.
- **Phase 4 header presence.** Checked **after** re-fetching the
  comment body (step 1 below), not in the job-level `if:`. The
  `issue_comment` event payload may truncate long comment bodies, so a
  job-level `contains(github.event.comment.body, '…')` check can
  false-negative when the Phase 4 section sits past the truncation
  cutoff.

Steps:

1. Re-fetch the comment via
   `gh api /repos/{owner}/{repo}/issues/comments/{id}` (event payload
   may truncate long bodies).
2. Parse the Phase 4 markdown table for rows whose Action is
   `⚠️ Errored`. To make this parse robust, `pr-resolve-all.md` adds a
   canonical `Thread ID` column to the Phase 4 table — the GraphQL node
   ID (`PRRT_…`) needed by `resolveReviewThread`. The ID column is
   required, not optional.
3. Compute a fingerprint = `sha256` of sorted errored Thread IDs. If a
   prior comment on the PR contains
   `<!-- relay-fallback-fingerprint:<same> -->`, skip — the fallback
   already ran for this set. (Mirrors the existing relay dedup pattern.)
4. For each errored row, under `CLAUDE_PAT`:
   - POST audit reply via `addPullRequestReviewThreadReply`. Reply body
     uses the canonical format from `pr-resolve-all.md` Phase 4 step 2,
     with agent identifier `relay-fallback (agent-relay-reviews)` and
     the latest commit on the PR head as `<SHORT_SHA>`.
   - Fire `resolveReviewThread`. Confirm `isResolved: true`.
5. Post a single fingerprinted summary comment listing per-row outcomes
   (`✅ resolved` / `❌ still errored: <reason>`).
6. On parse failure (table malformed, columns missing, no `Thread ID`,
   or `⚠️ Errored` row(s) present but no extractable `PRRT_…` ID),
   post a single fingerprinted parse-error comment on the PR and exit
   non-zero. Do not retry; do not silently skip. The fingerprint is
   computed over the Phase 4 section so that re-fires on a malformed
   table don't spam the PR.

The new job has its own `concurrency` group
(`phase4-fallback-${{ github.event.issue.number }}`) and its own
permissions block (`pull-requests: write`, `contents: read`). The
existing `relay` job's `concurrency` block is moved from the
workflow level to the job level so the two jobs can run
concurrently on the same PR without cancelling each other.

## Options Considered

### Option A: Relay-side fallback via CLAUDE_PAT (chosen, with the label removal)

Described above. Preserves ADR-007's "Copilot decides, not human" promise
end-to-end (Copilot still does the gate logic and drafts the audit
reply intent in its Resolution Report; the fallback only re-fires the
mutations Copilot couldn't). Re-uses the token already wired into the
relay workflow. V3-style verifiable on a scratch PR.

**Cons**: The fallback job parses Copilot's Resolution Report markdown,
so the Phase 4 table format is now load-bearing. Mitigated by adding the
canonical `Thread ID` column and loud-failing on parse errors rather than
silently retrying. The new `issue_comment.created` trigger is noisy at
the workflow-runs level (fires on every PR comment) but the job-level
`if:` keeps actual run cost near zero.

### Option B: Drop Copilot-path Phase 4 from ADR-007 scope

Narrow ADR-007 to Claude-path only. Document
`copilot-relay` + `auto-resolve-threads` (or, post-this-ADR, just
`copilot-relay`) as a no-op for thread resolution.

**Pros**: Simplest. Zero code. No new failure modes.

**Cons**: Abandons a major ADR-007 promise. Maintainers using the
Copilot path keep the auto-merge unblock problem ADR-007 was supposed
to fix.

### Option C: Two-step UX — `claude-fix` after Copilot finishes

Document the procedure as: trigger Copilot via `copilot-relay`; once
Copilot pushes its fix commit, apply `claude-fix` so Claude runs Phase 4
against Copilot's `✅ Fixed` items.

**Pros**: Workable today with zero workflow code.

**Cons**: Hidden blocker. `pr-resolve-all.md` Phase 4 explicitly says:
"Do not resolve threads from a previous fix cycle. Scope Phase 4 to
items fixed in the current run only." Claude on a follow-up cycle has an
empty Phase 1 index (Copilot already fixed everything) and Phase 4
correctly skips every thread. Option C is **not viable without prompt
changes** that allow Claude to inherit Copilot's prior cycle scope —
which is essentially Option A in a clumsier form, with double the
fix-cycle budget and an awkward two-label UX.

### Option D: Keep the `auto-resolve-threads` label (Option A only, no label removal)

Implement the relay fallback but leave ADR-007's opt-in label in place.

**Pros**: Backward-compatible. Downstream repos that adopted ADR-007
keep the same UX.

**Cons**: Preserves the concurrency-race friction described above.
Doesn't eliminate the "two labels in order" gotcha. The label adds no
safety the per-thread gate doesn't already provide. We keep paying the
documentation tax (Label-application gotcha note in
`docs/guides/agent-pipeline.md`) without a corresponding benefit.

## Consequences

### Positive

- **Single-label UX on both paths.** `claude-fix` (or `copilot-relay`)
  is now the only label needed for the full fix-and-resolve flow. The
  Label-application gotcha disappears.
- **Copilot-path Phase 4 becomes functional end-to-end.** What Copilot
  drafts in its Resolution Report, the relay-fallback job mechanically
  completes. ADR-007's "auto-merge unblock" benefit now applies on the
  Copilot path too.
- **Audit trail is unchanged.** Every resolution still posts an
  audit-trail reply naming the resolving commit and `ISS-NN`. The
  fallback identifies itself as `relay-fallback (agent-relay-reviews)`
  so a reviewer can tell at a glance which path resolved a given
  thread.
- **Idempotency** via the fingerprint marker prevents double-resolve if
  the workflow re-fires (e.g., comment edit, manual workflow_dispatch).
- **Graceful future-proofing.** If a future Copilot token grants
  `pull-requests:write`, Copilot's own mutations succeed, the
  Resolution Report has no `⚠️ Errored` rows, and the fallback no-ops.

### Negative

- **The Phase 4 table format is now load-bearing** for the Copilot
  path. The `Thread ID` column is the canonical machine-readable handle;
  changing the column shape is a breaking change for the fallback job.
  Mitigation: documented in `pr-resolve-all.md` Phase 4 prose and
  enforced by the `process_doc_maintenance.md` prompt-mirror rule.
- **Behavior change for downstream adopters of ADR-007.** Any repo that
  adopted the template's ADR-007 + the `auto-resolve-threads` label will
  see Phase 4 start running by default after pulling this template
  update. The change is safe by design (the per-thread gate is
  unchanged) but it is a behavior change. Downstream owners can delete
  the now-orphaned `auto-resolve-threads` label from their repos —
  it has no effect on the new code.
- **`issue_comment.created` is a noisy trigger** at the Actions UI
  level (one workflow run row per PR comment). Job-level `if:` keeps
  actual compute cost near zero but the run history grows.

### Neutral

- No new secrets. `CLAUDE_PAT` is already wired into
  `agent-relay-reviews.yml`.
- The Claude-path Phase 4 is unchanged in mechanism — only the trigger
  (label → unconditional) shifts. V2's evidence (PR #97, 7 bot threads
  resolved with canonical audit replies) still applies.
- ADR-007 status changes to `Accepted (superseded by ADR-008)`. Body
  left intact per supersession discipline (`docs/decisions/README.md`).

## Implementation

- [x] Write this ADR; flip ADR-007 status to
      `Accepted (superseded by ADR-008)`.
- [x] Update `docs/decisions/README.md` index (add row for ADR-008,
      flip ADR-007 status column).
- [x] Edit `.github/prompts/pr-resolve-all.md`:
      remove the "Only execute Phase 4 if the PR carries the
      `auto-resolve-threads` label" guard; remove the
      `Label …  not present — skipping` report variant; add the
      canonical `Thread ID` column to the Phase 4 report table;
      update prose noting the column is the machine-readable handle
      the relay-fallback job parses.
- [x] Edit `.github/workflows/agent-relay-reviews.yml`: remove
      `auto-resolve-threads` label references in the inline-mirror
      comment text; add `issue_comment.created` trigger; add the new
      `phase4-fallback` job per the design above.
- [x] Edit `.github/workflows/agent-fix-reviews.yml`: remove
      `auto-resolve-threads` label references in any inline-mirror
      comment text.
- [x] Edit `scripts/setup.sh`: remove
      `_ensure_label "auto-resolve-threads"` (and the fallback warning
      list entry).
- [x] Edit `docs/guides/agent-pipeline.md`: remove
      `auto-resolve-threads` from the label table and Manual
      Intervention table; remove the Label-application gotcha note;
      add the `phase4-fallback` job to the workflow inventory; drop
      the "Claude path only" caveats from the resolution-path prose.
- [x] Edit `test.sh`: add `docs/decisions/adr-008-...md` to
      `DOCS_FILES`.
- [x] **V7 (Copilot path)**: scratch PR, label only `copilot-relay`,
      3 planted bot threads. Confirm: relay → Copilot fix → Resolution
      Report with errored rows including `Thread ID` column → fallback
      job runs → audit replies + mutations succeed → all 3 threads
      `isResolved: true` → re-trigger is idempotent.
      *V7 PASS, with two follow-ups filed: #107 (Copilot occasionally
      stops after Phase 1) and #108 (audit reply rendered `(ISS-?)`).
      Both addressed in PR follow-ups; #107 added the
      `copilot-stall-watcher` job in the same workflow file, and #108
      fixed the awk lookup with parser unit tests in
      `scripts/test-phase4-fallback-parser.sh`.*
- [x] **V8 (Claude path)**: scratch PR, label only `claude-fix`,
      3 planted bot threads. Confirm Phase 4 runs by default
      (no extra label needed) → 3 bot threads resolved with audit
      replies. Mirrors V2 minus the second label.
      *V8 PASS — 9/9 threads resolved.*
- [x] **V9 (negative)**: scratch PR, label only `claude-fix`,
      1 human thread + 1 bot thread whose Phase 2 status is
      `Needs clarification`. Confirm both stay open (per-thread gate
      preserved).
      *V9 case (a) PASS (human-author skip verified end-to-end);
      case (b) close-covered by parser/filter unit tests under #108
      because Claude correctly judged the planted ambiguous line as
      fixable rather than emitting `Needs clarification` on a bot
      thread.*

## References

- ADR-007 (`adr-007-auto-resolve-review-threads.md`) — superseded by
  this ADR. Body intact for historical context.
- Issue [#100](https://github.com/mikejmckinney/ai-repo-template/issues/100)
  — primary trigger for this ADR.
- PR #99 (V3 verification) — primary evidence that Copilot-path Phase 4
  mutations return `FORBIDDEN`.
- PR #97 (V2 verification) — Claude-path Phase 4 end-to-end pass; the
  baseline this ADR preserves.
- `.github/prompts/pr-resolve-all.md` — Phase 4 procedure (modified by
  this ADR).
- `.github/workflows/agent-relay-reviews.yml` — gains the
  `phase4-fallback` job.
- ADR-006 (`adr-006-auto-merge-opt-in-model.md`) — opt-in-label
  precedent ADR-007 followed; this ADR partially walks back from that
  pattern on the principled grounds that the label added no safety the
  per-thread gate doesn't already provide.
- `docs/decisions/README.md` — supersession discipline applied here.
- GitHub GraphQL API:
  [`resolveReviewThread`](https://docs.github.com/en/graphql/reference/mutations#resolvereviewthread),
  [`addPullRequestReviewThreadReply`](https://docs.github.com/en/graphql/reference/mutations#addpullrequestreviewthreadreply).
