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

## Addendum (2026-04-25, issue #170): Claude-fix delegations route through `copilot-relay`

ADR-008 originally covered two trigger paths into the
`phase4-fallback` retry: (a) PRs labeled `copilot-relay` from open,
and (b) Claude-fix runs that complete without delegating. A third
path went undocumented and became broken in practice:

**(c) Claude-fix runs that delegate a workflow-file edit to Copilot.**
The Claude GitHub App token cannot push to `.github/workflows/**`.
The pre-#170 implementation handled this by posting a free-form
`@copilot The following review item(s) require edits…` comment.
Copilot's cloud agent picked up the mention, applied the edit,
pushed, and posted a "Done in `<SHA>`" comment with no Phase 1 / 3 / 4
structure. `phase4-fallback` only parses Copilot's Phase 3 Resolution
Report for the Phase 4 table — without that table, the fallback
no-ops, the bot-authored thread that motivated the delegation stays
open, and auto-merge stalls indefinitely. Observed end-to-end on PR
#169 (the dog-food PR for #168): see the
[claude-fix delegation comment](https://github.com/mikejmckinney/ai-repo-template/pull/169#issuecomment-4316786637)
and [Copilot's unstructured "Done in" response](https://github.com/mikejmckinney/ai-repo-template/pull/169#issuecomment-4316791298).

The fix is **not** to broaden the fallback's `if:` gate (the fallback
parses the triggering comment and there is no Phase 4 table to parse
on a "Done in `<SHA>`" comment), and **not** to give Copilot extra
permissions (we cannot inject secrets into GitHub's hosted
SWE-agent environment). The fix is to route the delegation through
the existing `copilot-relay` flow:

When `agent-fix-reviews.yml` detects a workflow-file change is
required, it now:

1. Posts `@copilot follow .github/prompts/pr-resolve-all.md` with the
   workflow items scoped in the comment body.
2. Marks the delegated items `🔄 Delegated to Copilot` in its own
   Phase 3 Resolution Report (no change from prior behavior).

Note: The `copilot-relay` label is NOT applied by claude-fix to avoid
double-dispatching Copilot (the label's `pull_request.labeled` trigger in
`agent-relay-reviews.yml` would post a second `@copilot follow` comment,
causing competing resolution runs). The direct comment is sufficient.

Copilot then runs `pr-resolve-all` end-to-end, attempts Phase 4,
hits FORBIDDEN, marks rows ⚠️ Errored, and posts its Phase 3 with
the Errored Phase 4 table. `phase4-fallback` fires on that comment
**unchanged** and retries the mutations under `CLAUDE_PAT`. Threads
close. Auto-merge proceeds.

Workflow YAML for `phase4-fallback` is unchanged. The diff for #170
lives entirely in `agent-fix-reviews.yml`'s prompt — the delegation
step.

### Semantic update to `copilot-relay`

`copilot-relay` continues to mean "Copilot drives end-to-end resolution
from PR open." Claude-fix delegation (workflow-file edits mid-cycle) now
routes through a direct `@copilot follow` comment rather than applying
the label, to avoid double-dispatching Copilot via competing label and
mention triggers. Both paths invoke the same Copilot pr-resolve-all flow.

### Verification (V10)

**Pre-merge constraint (resolved — PR #173 merged 2026-04-25)**: V10 was
blocked until PR #173 merged because the smoke-test PR had to use the
updated `agent-fix-reviews.yml` delegation logic (the one that posts
`@copilot follow .github/prompts/pr-resolve-all.md` instead of a
free-form mention) — and that change lived in PR #173 itself. V10 is
now committed to the first dog-food PR after merge.

Live on a smoke-test PR that introduces a workflow-file issue:

1. Apply `claude-review` + `claude-fix` (no `copilot-relay`).
2. Confirm claude-fix's Phase 3 marks the workflow item
   `🔄 Delegated to Copilot` AND posts the scoped `@copilot follow`
   comment (does NOT apply the `copilot-relay` label to avoid
   double-dispatching).
3. Confirm Copilot's cloud agent runs `pr-resolve-all`, posts its
   own Phase 1 Index, pushes the workflow fix, posts Phase 3 with
   the Phase 4 table marked `⚠️ Errored`.
4. Confirm `phase4-fallback` fires on Copilot's Phase 3 comment,
   audit-replies, calls `resolveReviewThread`, succeeds.
5. Confirm the bot-authored thread is now `isResolved=true` and
   auto-merge proceeds.

**V10 FAILS if** any of the following hold:

- Copilot posts "Done in `<SHA>`" with no Phase 4 table (old broken
  behavior).
- `phase4-fallback` no-ops when the table is present (malformed parse).
- The bot-authored review thread stays `isResolved=false` after
  `phase4-fallback` runs.
- Auto-merge does not proceed after thread resolution.

Regression: separately, on a PR that opens with `copilot-relay`
(no `claude-fix`), the existing flow must still work unchanged.

### Risks and known limitations

1. **Copilot's Phase 1 and already-resolved items**: The delegation
   comment scopes workflow items explicitly and asks Copilot to mark
   Claude's already-pushed fixes as `✅ Already resolved` in its own
   Phase 1 scan. This is a behavioral assumption, not a verified
   contract. If Copilot re-fixes items Claude already resolved, the
   cost is duplicated API calls and commits, not a correctness issue —
   `pr-resolve-all` Phase 2 Step 2 verifies the issue still exists
   before applying any fix. V10 will confirm this assumption.

2. **Phase 4 race on late-arriving delegate commits** (tracked in
   [#177](https://github.com/mikejmckinney/ai-repo-template/issues/177)):
   If a delegate's fix commit lands *after* the last Phase 4 cycle ran,
   no mechanism re-triggers thread resolution on subsequent commits.
   Two coupled gaps cause this:

   - **claude-fix's Phase 4** evaluates the working tree at the moment
     its workflow run started. A subsequent push doesn't re-trigger it
     (no `push` trigger on `agent-fix-reviews.yml` for already-reviewed
     PRs).
   - **`phase4-fallback`** only retries `⚠️ Errored` rows from
     Copilot's most recent Phase 3 Resolution Report. Once a later
     claude-fix cycle has overwritten the resolution status with its
     own Phase 4 table (typically marking the still-pending item
     `⏭️ Skipped — waiting for fix`), the fallback can no longer find
     the Errored rows to retry.

   The window opens whenever claude-fix Phase 4 N+1 fires *after*
   Copilot's Phase 4 (consuming the Errored signal) but *before*
   Copilot's actual fix commit. Observed on PR #173 itself: Copilot's
   ISS-01 fix in `b1d4ebe` (00:42:12Z) landed 8 seconds after
   claude-fix's last Phase 4 cycle (00:42:04Z) and the thread stayed
   open until manually resolved via the GraphQL `resolveReviewThread`
   mutation. See #177 for the proposed fix (re-trigger
   `phase4-fallback` on `pull_request.synchronize`).

**Addendum references:**

- Issue [#170](https://github.com/mikejmckinney/ai-repo-template/issues/170)
  — the parent fix this addendum documents.
- Issue [#177](https://github.com/mikejmckinney/ai-repo-template/issues/177)
  — follow-up tracking the Phase 4 race documented in Risk #2.
- PR [#169](https://github.com/mikejmckinney/ai-repo-template/pull/169)
  — the failure mode in production. See the
  [delegation comment](https://github.com/mikejmckinney/ai-repo-template/pull/169#issuecomment-4316786637)
  and [Copilot's unstructured response](https://github.com/mikejmckinney/ai-repo-template/pull/169#issuecomment-4316791298).

## Addendum (2026-04-25, issue #177): `phase4-fallback` self-triggers on push

The first addendum (Risk #2) noted that when a delegate's fix commit
lands *after* the last Phase 4 cycle ran, no mechanism re-triggers
thread resolution on subsequent commits. Concretely: on PR #173,
Copilot's ISS-01 fix in `b1d4ebe` (00:42:12Z) landed 8 seconds after
claude-fix's last Phase 4 cycle (00:42:04Z), and the bot-authored
review thread stayed open until manually resolved.

This addendum documents the fix shipped in #177:

`phase4-fallback` now triggers on `pull_request.synchronize` in addition
to its existing `issue_comment` trigger. On the synchronize path, a new
"Discover triggering Copilot Phase 3 comment" step queries the PR's
comments for the most recent Copilot-authored comment containing the
canonical `### Phase 4 — Thread auto-resolution` header, and feeds its
ID into the existing parse-and-mutate logic via the existing
`COMMENT_ID` env var. The parsing, fingerprint dedup, and mutation
logic are reused unchanged.

Both trigger paths' job-level `if:` gate filter by either
`copilot-relay` OR `claude-fix` label — those are the only labels that
signal Copilot might have posted a Phase 4 table on the PR. The
`claude-fix` gate covers the post-#170 case where claude-fix
delegations to Copilot intentionally do NOT apply `copilot-relay` (per
ISS-04 in PR #173) yet still produce a Copilot Phase 3 comment with
`⚠️ Errored` rows.

Re-runs are idempotent: the existing fingerprint dedup (sha256 of
sorted Errored Thread IDs) short-circuits when the same set has
already been processed. Cost: ~30s of runner time per push to a
qualifying PR; bounded.

Rejected alternatives:

- **Option A** (new dedicated workflow file): adds a moving piece
  without reusing the tested parser.
- **Option C** (have claude-fix consult Copilot's Phase 4 table): only
  fixes the claude-fix→Copilot path; leaves the symmetric pure-relay
  path with the same structural gap; couples claude-fix more tightly
  to Copilot's output format.

### Verification (V12)

V12 dog-foods on the PR that implements issue #177. That PR will
likely trigger claude-fix (workflow-file edit), which will likely
delegate to Copilot. When Copilot pushes its fix commit *after*
claude-fix's last Phase 4 cycle ran, the new synchronize trigger fires,
discovers Copilot's Phase 3 comment, parses the `⚠️ Errored` rows, and
resolves the orphaned thread under `CLAUDE_PAT`. Auto-merge proceeds
without manual thread resolution.

**V12 FAILS if** any of the following hold:

- A delegate's commit lands after the last Phase 4 cycle, the
  synchronize trigger does not fire, and the orphan thread persists.
- The synchronize trigger fires but the discovery step fails to find
  the Copilot Phase 3 comment.
- The fingerprint dedup mis-fires and re-runs spam the PR with
  duplicate fallback comments.

**Addendum references:**

- Issue [#177](https://github.com/mikejmckinney/ai-repo-template/issues/177)
  — the bug this addendum closes.
- PR [#173](https://github.com/mikejmckinney/ai-repo-template/pull/173)
  — the dog-food where the race surfaced; ISS-01's thread had to be
  manually resolved.
- `.github/workflows/agent-relay-reviews.yml` — `phase4-fallback` job
  (the trigger and discovery step changes).
- PR [#179](https://github.com/mikejmckinney/ai-repo-template/pull/179)
  — the PR that ships this fix.

## References

- ADR-007 (adr-007-auto-resolve-review-threads.md) — superseded by
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
