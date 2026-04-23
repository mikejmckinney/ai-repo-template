# ADR-007: Auto-resolve bot-authored review threads via opt-in `auto-resolve-threads` label

## Status

Accepted (superseded by [ADR-008](./adr-008-phase4-default-and-copilot-fallback.md))

> **Note**: ADR-008 (2026-04-22) supersedes two specific design choices
> in this ADR:
>
> 1. The `auto-resolve-threads` opt-in label is removed; Phase 4 runs
>    by default whenever `pr-resolve-all.md` is invoked. The per-thread
>    gate is preserved verbatim and remains the only safety mechanism.
> 2. The Copilot-path Phase 4 — described below as non-functional
>    pending issue #100 — is now functional via a relay-side fallback
>    job in `agent-relay-reviews.yml` that fires the GraphQL mutations
>    under `CLAUDE_PAT` after parsing the `⚠️ Errored` rows from
>    Copilot's Phase 3 Resolution Report.
>
> The rest of this ADR's body (Context, Decision, Options Considered,
> Consequences) is left intact for historical context. Read ADR-008 for
> the current design.

## Date

2026-04-21

## Context

`.github/prompts/pr-resolve-all.md` is the canonical review-resolution
procedure for this repo and is run by **two different agents**:

- **Claude** via `.github/workflows/agent-fix-reviews.yml` (opt-in via the
  `claude-fix` label), or via a direct `@claude follow .github/prompts/pr-resolve-all.md` mention wired through `.github/workflows/claude.yml`.
- **Copilot** via `.github/workflows/agent-relay-reviews.yml` (opt-in via the
  `copilot-relay` label — the relay posts an `@copilot follow .github/prompts/pr-resolve-all.md` comment that the Copilot cloud agent picks up), or via a direct human `@copilot follow` mention.

Either agent reads the prompt, pushes commits, posts an Issue/Suggestion
Index, and posts a Resolution Report — but **leaves every review thread
open**. The human (or subsequent automation) has to click "Resolve
conversation" on each thread before the PR looks clean, even though the fix
already landed in a referenced commit.

On PRs with dense bot review (Gemini + Copilot review + Claude auto-review +
Codex Connector), this leaves 10–30 unresolved threads after a successful fix
cycle. That:

- Clutters the PR timeline and makes real unresolved human feedback harder to
  spot.
- Blocks the `agent-auto-merge.yml` eligibility check (condition 2:
  "no unresolved review threads"), so an auto-labeled PR that was actually
  fixed still sits open until a human does cleanup.
- Undermines the paper trail: reviewers looking at the PR later see "N
  unresolved threads" and assume work is pending.

The fix needs to resolve bot-authored threads automatically *after* their
corresponding fix has passed verification — without silencing human
reviewers who expect to resolve their own threads, and without resolving
threads whose Phase 2 outcome was ambiguous (`⚠️ Needs clarification`,
`❌ Not reproducible`, `❌ Out of scope`).

Issue #91 tracks this gap.

## Decision

We will extend the existing `pr-resolve-all.md` procedure with a **Phase 4**
that runs only when the PR carries an opt-in `auto-resolve-threads` label
(applied in addition to either `claude-fix` or `copilot-relay`, or alongside
a direct `@claude follow` / `@copilot follow` mention). Because Phase 4 lives
in the shared prompt file, it is **agent-agnostic** — whichever agent is
executing the prompt on a given PR (Claude or Copilot) performs the
thread-resolution step. Phase 4 resolves review threads whose root comment
was authored by an allow-listed bot **and** whose matching Phase 2 item
cleared with status `✅ Fixed`. Every other thread is left open.

No new permissions or secrets are required for the workflows that invoke
the prompt — the inline-prompt edits in `agent-fix-reviews.yml` and
`agent-relay-reviews.yml` are documentation-only updates surfacing Phase 4
to the running agent, not permission-model changes:

- `agent-fix-reviews.yml` already supplies `CLAUDE_PAT`,
  `pull-requests: write`, and `allowed_bots: "*"`, which are the only
  permissions the Claude invocation of Phase 4 needs. **V2 verification
  on PR #97 confirmed end-to-end**: 7 bot threads resolved with canonical
  audit replies, human thread left open, `isOutdated == true` correctly
  not a blocker.
- `agent-relay-reviews.yml` forwards bot reviewers' comments to Copilot
  via `@copilot follow .github/prompts/pr-resolve-all.md`. The Copilot
  cloud agent can read the prompt file and **correctly runs the
  Phase 4 gate logic** (allow-list check, `✅ Fixed` status match,
  audit-reply drafting), but in this repo its token **does not** carry
  the `pull-requests:write` scope required by the `addPullRequestReviewThreadReply`
  and `resolveReviewThread` GraphQL mutations. V3 verification on PR #99
  produced 3× `FORBIDDEN` on these mutations, confirming Copilot-path
  Phase 4 is **not functional end-to-end** as currently designed — the
  fix commit lands, but the threads don't close. See
  [issue #100](https://github.com/mikejmckinney/ai-repo-template/issues/100)
  for the options under consideration (relay-side fallback via
  `CLAUDE_PAT`, scope narrowing, or a two-step `copilot-relay` →
  `claude-fix` UX). Until #100 lands a fix, applying
  `auto-resolve-threads` alongside `copilot-relay` is best understood as
  a **no-op** on the Copilot path.

The label is created by `scripts/setup.sh` alongside the other pipeline
labels, and documented in `docs/guides/agent-pipeline.md`.

Allow-listed bots are matched from `user.login` / GraphQL `author.login`
using the same normalization rule as Phase 4 in
`.github/prompts/pr-resolve-all.md`: strip any trailing `[bot]` from the
login, then compare case-insensitively against the normalized allow-list
below. (REST and GraphQL disagree on whether the `[bot]` suffix is
present, and login casing is inconsistent, so the normalized form is
the canonical one.)

Normalized allow-list:

- `gemini-code-assist`
- `copilot-pull-request-reviewer`
- `copilot` (the Copilot SWE agent)
- `chatgpt-codex-connector`
- `codex`
- `claude` (only when the thread's root comment was authored directly by
  the `claude[bot]` / `claude` identity — e.g., Claude's auto-review
  workflow. If a human opened the thread and `claude[bot]` merely
  replied, the root author is the human and Phase 4 must leave the
  thread open.)

Per-thread gate (all four must hold):

1. Root comment author is in the allow-list.
2. Phase 2 status for the matching `ISS-NN` item is `✅ Fixed`.
3. Phase 2 verification (tests, lint, build, typecheck) passed for the fix.
4. Thread is not already resolved.

Before resolving, the resolving agent (Claude or Copilot, whichever ran
the prompt) posts an audit-trail reply on the thread citing the resolving
commit SHA and the `ISS-NN` ID, then fires the GraphQL
`resolveReviewThread` mutation.

## Options Considered

### Option 1: Extend `pr-resolve-all.md` with a Phase 4 gated on a new `auto-resolve-threads` label (chosen)

- **Pros**:
  - Zero workflow changes — the prompt-file edit is the entire mechanism.
  - Opt-in is per-PR via label, mirroring the ADR-006 `auto-merge` pattern.
  - Agent-agnostic: because both Claude (via `agent-fix-reviews.yml`) and
    Copilot (via `agent-relay-reviews.yml` → `@copilot follow`) execute the
    same prompt file, a single edit covers both resolution paths.
  - Two-label separation (`claude-fix`/`copilot-relay` + `auto-resolve-threads`)
    lets repo owners run the fix procedure without resolution if they want
    to audit every thread manually.
  - Allow-list plus the Phase 2 `✅ Fixed` gate means human threads and
    ambiguous fixes are never silenced.
  - Audit-trail reply preserves traceability — a reviewer who disagrees can
    simply unresolve the thread.
- **Cons**:
  - The prompt-file is now the load-bearing specification for a
    behavior-changing workflow step; schema drift risk if the prompt is
    edited without updating the ADR.
  - The resolving agent has to make extra GraphQL calls per thread
    (mutation + reply), which slightly increases API / premium-request usage
    on PRs with many bot threads.
  - Two agents interpreting one prompt file means the Phase 4 instructions
    must stay strictly declarative — agent-specific behavior (cycle
    numbering, workflow names in the audit reply) is parameterized rather
    than assumed.

### Option 2: Always auto-resolve bot threads whenever `claude-fix` is set, without a second label

- **Pros**:
  - Simplest UX — one label, one behavior.
  - Matches the expectation that "if Claude fixed it, the thread is done."
- **Cons**:
  - Removes the escape hatch for maintainers who want to audit each fix
    before declaring the thread resolved.
  - Mixes two concerns (run the fix procedure / silence the reviewers) into
    one control surface, making rollback harder if Phase 4's gating logic
    has a bug.
  - Violates the ADR-006 opt-in precedent of "one label per intent."

### Option 3: Add a separate `agent-resolve-threads.yml` workflow triggered on `workflow_run: agent-fix-reviews`

- **Pros**:
  - Keeps concerns fully separated in their own workflow files.
  - Could run independently of the Claude Code Action.
- **Cons**:
  - A second workflow means a second permissions surface, a second token
    path, and a second place to maintain the bot allow-list.
  - The thread-resolution logic needs the `ISS-NN` → thread mapping that
    Phase 2 produces, so it either needs to re-derive that mapping from the
    posted comments (fragile) or Phase 3's report becomes a machine-parsed
    artifact (over-engineered).
  - Adds a new `workflow_run` trigger with cross-workflow timing issues
    identical to the ones that bit us in ADR-006's Phase B verification.

### Option 4: Resolve threads via GitHub's native "Resolve conversation on merge" behavior

- **Pros**:
  - No custom logic at all.
- **Cons**:
  - Doesn't exist — GitHub only marks threads as "outdated" when the
    commented line moves; it never auto-resolves them on merge. This option
    is not available.

## Consequences

### Positive

- **Claude path (`claude-fix` + `auto-resolve-threads`)**: Bot-authored
  threads close themselves once the fix is verified, so
  `agent-auto-merge.yml`'s unresolved-thread gate stops blocking PRs that
  were actually fixed. Validated end-to-end on PR #97 (V2).
- Human reviewers still own their own threads — Phase 4 never touches a
  thread whose root comment was human-authored.
- Audit-trail replies (`Resolved by agent-fix-reviews in <sha> (ISS-NN,
  cycle N/3)`) make every resolution traceable without digging through
  workflow logs.
- Opt-in design means existing repos using `claude-fix` keep their current
  behavior until they explicitly add the new label.

### Negative

- The prompt-file (`.github/prompts/pr-resolve-all.md`) is now
  behavior-critical, not just advisory. Edits to it directly change what
  gets resolved.
- Bot allow-list needs maintenance when GitHub introduces new bot
  reviewers; an unlisted bot's threads stay open until the list is updated.
- Very large PRs (>100 review threads) require GraphQL pagination in the
  Phase 4 query — the prompt mentions this but agents must actually
  implement it correctly.
- **Copilot-path Phase 4 is currently non-functional** — V3 verification
  (PR #99) showed `FORBIDDEN` on both `addPullRequestReviewThreadReply`
  and `resolveReviewThread` when invoked by the Copilot cloud agent in
  this repo. The Copilot-path Phase 4 gate logic is correct; only the
  mutations fail. Tracked in
  [issue #100](https://github.com/mikejmckinney/ai-repo-template/issues/100).
  Until resolved, `copilot-relay` + `auto-resolve-threads` is a no-op
  combination; maintainers needing bot-thread auto-resolution should
  use the Claude path.
- Applying `copilot-relay` and `auto-resolve-threads` to a PR in a
  single API call (as opposed to one-at-a-time in the UI) fires two
  `pull_request.labeled` events in quick succession.
  `agent-relay-reviews.yml` uses `concurrency.cancel-in-progress: true`,
  so the first (matching) relay run is cancelled by the second
  (non-matching) event and the `@copilot follow` comment is never
  posted. Workaround: apply labels one-at-a-time, with `copilot-relay`
  applied last. Documented in `docs/guides/agent-pipeline.md`.

### Neutral

- No new secrets, permissions, or triggers are introduced. The
  workflow-file edits in this ADR are documentation-only (inline-prompt
  updates surfacing Phase 4 to the running agent), so all existing Phase B
  test coverage for `agent-fix-reviews.yml` still applies.
- The `auto-resolve-threads` label has no effect unless a resolution path
  runs `.github/prompts/pr-resolve-all.md`; applying the label alone is a
  no-op rather than an error.

## Implementation

- [x] Extend `.github/prompts/pr-resolve-all.md` with Phase 4, allow-list,
      per-thread gate, audit-trail reply format, and Phase 4 report template.
- [x] Add `_ensure_label "auto-resolve-threads"` to `scripts/setup.sh` and
      include it in the fallback warning list.
- [x] Add the label to `docs/guides/agent-pipeline.md`'s label
      table, resolution-path selection prose, and Manual Intervention table.
- [x] Create this ADR.
- [x] Verify on a real PR by labeling `claude-fix` + `auto-resolve-threads`
      (Claude path) and separately `copilot-relay` + `auto-resolve-threads`
      (Copilot path), plus the unlabeled-negative case. **Claude path
      ✅ passed end-to-end** on PR #97 (V2) — 7 bot threads resolved with
      canonical audit replies, human thread stayed open. **Copilot path
      partial pass** on PR #99 (V3) — gate logic correct but mutations
      return `FORBIDDEN`; tracked as
      [issue #100](https://github.com/mikejmckinney/ai-repo-template/issues/100).
      **Unlabeled negative ✅ passed** on PR #101 (V4) — Phase 3 report
      contained the canonical `Label auto-resolve-threads not present —
      skipping thread resolution.` line and no threads were touched.
      Consolidated V1–V6 results:
      [Verification Report comment on PR #93](https://github.com/mikejmckinney/ai-repo-template/pull/93#issuecomment-4292631375).

## References

- Issue #91 — "Auto-resolve bot-authored review threads after fixes land"
- `.github/prompts/pr-resolve-all.md` — canonical Phase 1–4 procedure
- `.github/workflows/agent-fix-reviews.yml` — invokes the prompt with
  `CLAUDE_PAT` and `pull-requests: write`
- ADR-006 (`adr-006-auto-merge-opt-in-model.md`) — prior art for the
  opt-in-label pattern this ADR follows
- GitHub GraphQL API —
  [`resolveReviewThread` mutation](https://docs.github.com/en/graphql/reference/mutations#resolvereviewthread)
  and
  [`PullRequest.reviewThreads` connection](https://docs.github.com/en/graphql/reference/objects#pullrequestreviewthreadconnection)
