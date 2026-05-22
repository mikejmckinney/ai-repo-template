---
description: Resolve every open issue, suggestion, and TODO on a PR; produce Index + Resolution Report and auto-resolve bot threads.
agent: agent
---

# PR Issue Resolution — Systematic Verify-and-Fix

> **Context:** this prompt plugs into Phase 6 of the OP issue→merge playbook. See [`op-issue-workflow.md`](op-issue-workflow.md) for the end-to-end OP playbook.
>
> **Usage**: Post one of these as a PR comment:
>
> - `@claude follow .github/prompts/pr-resolve-all.md`
> - `@copilot follow .github/prompts/pr-resolve-all.md`
>
> Both agents will read this file and execute the Phase 1–4 procedure below.
> Claude is wired via `.github/workflows/claude.yml`'s `claude-mention` job.
> Copilot follows the `@copilot follow <path>` rule documented in
> `.github/copilot-instructions.md`.
>
> **Phase 4** (auto-resolve bot-authored review threads) runs by default
> on every invocation of this prompt. The per-thread gate (allow-listed
> bot author + Phase 2 status `✅ Fixed` + verification green + thread
> not already resolved) is the only safety mechanism — there is no
> opt-in label. On the Copilot path, the GraphQL mutations may return
> `FORBIDDEN` because the Copilot cloud agent token lacks
> `pull-requests:write` in this repo; in that case, the relay-fallback
> job in `.github/workflows/agent-relay-reviews.yml` re-fires the
> mutations under `CLAUDE_PAT` after parsing the `⚠️ Errored` rows from
> the Phase 4 report table. See ADR-008 for the design.
>
> **When to stop**: this prompt covers *how* to fix bot findings;
> AGENTS.md → "PR completion criteria (interactive sessions)" covers
> *when the PR is done* (CI green + threads resolved or explicitly
> deferred). Read both before declaring work complete.

---

You are resolving every open issue, suggestion, and TODO in this pull request. Your job is to find them all, verify each one, fix the valid ones, and produce a traceable audit trail. Do not guess — verify everything against the actual code.

> **How to run this prompt**: Read this entire file before starting. Execute
> Phase 1, then Phase 2. Execute Phase 4 **before** posting the Phase 3
> Resolution Report so Phase 3 can include the Phase 4 results. Do not
> interleave or skip phases. If your cumulative response would exceed
> GitHub's per-comment size limit, post sequential `Part 1/N`,
> `Part 2/N`, … comments rather than truncating. Apply the Rules section to
> every phase.

## Round disciplines

These three rules apply at the start of every round and override any implicit defaults:

### 1 — Round cap

Resolve the cap via this precedence chain (most specific wins):

1. **Comment `@<agent> cap-override <N>` on this PR** → run at most N rounds (most recent matching comment wins if multiple exist).
2. **Label `cap-override` on this PR** → run unbounded rounds for this PR.
3. **Repo variable `PR_RESOLVE_MAX_ROUNDS`** — read via `gh variable get PR_RESOLVE_MAX_ROUNDS` (empty result or non-integer → use 3).
4. **Default** → 3 rounds.

At the start of each round, check comments first, then labels, then the repo variable. When the resolved cap is reached: post a comment listing all remaining unresolved items and the escalation path (fix manually, split the PR, apply `cap-override`, or upshift to a higher-context model). Do not silently stop.

#### Override justification (rounds > 3 with `cap-override` in effect)

When the round cap is overridden (label `cap-override` on the PR, or
`@<agent> cap-override <N>` comment with `N > 3`) **and** the current
round number is greater than 3, every Resolution Report posted from
round 4 onward MUST include a one-line justification on its own line:

```text
Override justification: <sandbox-class | legitimate refactor | complex semantic dependency | other: <≤80-char reason>>
```

Place this line in the Resolution Report directly under the `### Summary` block (before the per-item table). One of the four bracketed categories must be chosen verbatim; `other:` requires an explicit free-text reason of 80 characters or fewer.

The four categories are deliberately narrow:

- **sandbox-class** — the bug class can only be reproduced by merging to `main` or a sibling sandbox repo (the workflow-verifiability gap covered by issue #227).
- **legitimate refactor** — a bot finding genuinely required reorganising adjacent code (e.g., extracting a helper to fix a real correctness bug); the round count grew because the refactor surfaced a downstream finding.
- **complex semantic dependency** — the fix interacts with multiple shell/jq/regex semantics that cannot be statically caught by shellcheck/actionlint (e.g., `set -e` exit-code propagation through `$(...)`).
- **other:** — none of the above; you owe the maintainer a one-line explanation.

This rule exists because PR #228 ran 8 rounds with `cap-override`
silently in effect and PR #225 ran 11. The cap is a hard stop; the
override is the escape hatch; the justification line is the friction
that forces articulation rather than silent looping.

Judge enforces this rule at diff-gate (`.agents/judge.md`
item 15) and BLOCKs when override is in effect, the round count is > 3,
and the latest Resolution Report omits the justification line.

### 2 — Fetch PR data once per round

Fetch `currentActivePullRequest` (or its REST/GraphQL equivalent) **exactly once per round**, before the fix pass begins. Do not re-fetch between individual fixes within the same round. Re-fetching mid-round produces stale context, wastes premium tokens, and is the leading cause of duplicate fix attempts.

### 3 — Classify before fixing

At the front of each round, perform a cheap classification pass over all unresolved items **before** writing any code. Every item in the Phase 1 index **must** have an explicit classification — no silent omissions:

- **substantive** — logic error, false positive/negative in a linter/checker, correctness bug, missing required behavior; fix first, one per commit, verify each individually.
- **nit** — style, naming, whitespace, doc wording, minor UX improvement with no correctness impact; fix last, one per commit, after all substantive items.
- **out-of-scope** — requires files/systems outside this PR, purely advisory, or a known architectural limitation of the current design; mark `❌ Out of scope` immediately, post a deferral reply, do not fix.

Fix substantive items first, nit items last. This avoids expanding fix scope mid-round and running out of context before correctness issues are addressed.

### 4 — Recurring nits and known limitations

When the same finding recurs across multiple rounds without a practical fix path, treat it as a **known limitation** rather than re-deferring indefinitely. For each recurring finding that meets all three criteria:

1. The finding is factually correct (the limitation exists in the code)
2. Fixing it requires a non-trivial architectural change (e.g. per-token parsing, quote-aware grep) that is out of scope for the current PR
3. The same bot has raised it in **two or more prior rounds**

Do the following **once** (not every round):

1. **Document the limitation in the source code** — add a `KL-NN` (Known Limitation) entry in the file's header comment block. Include: what the limitation is, why it exists, and what would be needed to fix it properly. This makes the tradeoff visible to any future contributor.
2. **Add a skip-class entry to the bot config files** — update `.cursor/BUGBOT.md` and `.gemini/styleguide.md` under their "Project conventions (skip these classes of finding)" section. Reference the `KL-NN` code so the rationale is traceable. Both files are read by Gemini and Cursor Bugbot before every review; an explicit skip-class entry prevents the bot from re-raising the same finding.
3. **Resolve the thread** — after documenting the limitation and adding the skip-class entry, the bot thread can be resolved (it has been addressed — just not by a code fix). Use the standard Phase 4 audit reply: "Deferred as known limitation KL-NN — documented in `<file>` header and `BUGBOT.md`/`styleguide.md`. If this impacts real code, re-open with a concrete failing example."

**What counts as a nit vs a known limitation:**

- A **nit** is something you could fix quickly in this PR but choose not to because the value is low (style, naming). File it as a follow-up if warranted.
- A **known limitation** is something that cannot be fixed properly in this PR without a significant architectural change. Document it so future contributors understand why the simpler approach was chosen.

Never silently re-defer the same finding round after round — that wastes tokens and produces an unreadable PR history. Document once, skip forever.

### 5 — Settle window between rounds

When a round ends and you need to wait for reviewer state to settle
before the next fetch pass, **do not blind-sleep first**. Prefer the
repo-local helper:

```bash
scripts/pr-resolve-all-poll.sh <PR_NUMBER>
```

The helper is the pre-#321 settle detector for this prompt. It reads
`scripts/lib/bot-allowlist.txt` as the canonical machine-readable bot
identity set, observes live PR state from GitHub, and emits one final
machine-readable line containing at least `RESULT=<value>` and, when the
current PR head is available, `HEAD=<sha>`.

In this v0 contract, `latest actionable event` means the newest PR review,
PR comment, or review-thread comment timestamp visible from GitHub, falling
back to the head commit timestamp only when no newer PR activity exists.

In this pre-#321 v0 contract, `RESULT=CONVERGED` is intentionally stricter
than the quiet-window fallback: it requires an explicit non-pending review
submitted against the current `HEAD` for each participating allow-listed bot
with zero unresolved bot-rooted threads of its own. Comment-only bot
activity may still advance via `RESULT=QUIET_ELAPSED`, but it does not
prove current-head convergence on its own.

Dispatch on the helper result exactly as follows:

| Helper result | Exit code | Next action |
|---|---:|---|
| `RESULT=CONVERGED` | `0` | Reviewer state converged on the current head; re-fetch PR data once (Round discipline 2) and continue the next round / fetch pass. |
| `RESULT=QUIET_ELAPSED` | `0` | The fallback quiet window elapsed since the latest actionable event; re-fetch PR data once and continue the next round / fetch pass. |
| `RESULT=SHA_CHANGED` | `3` | A new push / force-push landed; restart the procedure against the new `HEAD` rather than continuing on stale state. |
| `RESULT=TIMEOUT` | `2` | Stop and escalate / pause for human direction. Do not silently loop forever. |
| `RESULT=API_ERROR` | `4` | Retry the helper once. If the second attempt still fails with a transient GitHub/runtime error (`ERROR=GH_AUTH`, `ERROR=REPO_VIEW`, or any `ERROR=GRAPHQL_*` value), fall back to one documented time-based wait (`QUIET_WINDOW`, default `360` seconds) and then do one fresh fetch pass. If it fails with a repo-local contract/runtime error (`ERROR=MISSING_GH`, `ERROR=MISSING_JQ`, `ERROR=MISSING_ALLOWLIST`, `ERROR=EMPTY_ALLOWLIST`, `ERROR=HEAD_MISSING`, `ERROR=STATE_BUILD`, or `ERROR=TIMESTAMP_PARSE`), pause / escalate instead of blind looping. |

This v0 helper is intentionally **pre-#321-compatible**: it detects
settle-window state from GitHub PR APIs only. It does **not** yet prove
the formal #321 round contract or parse Index / Resolution Report HTML
markers. Once #321 lands, refine the helper to consume the formal
marker/runtime-gate contract instead of this conservative inference.

---

## Phase 1: Build the Issue/Suggestion Index

Scan ALL of these sources for issues, suggestions, requested changes, and TODOs:

1. **PR description** — look for task lists, noted limitations, known issues, "TODO" or "FIXME" mentions.
2. **Review threads** — every unresolved review comment, including inline code comments and top-level review bodies. Pay attention to threads marked "Request changes."
3. **Commit messages** — scan for "TODO", "FIXME", "HACK", "WIP", or "known issue" language.
4. **Code diff** — scan the changed files for new `TODO`, `FIXME`, `HACK`, `XXX`, or `WORKAROUND` comments introduced in this PR.
5. **Linked issues** — if the PR description references GitHub issues (#NNN), read those issues for acceptance criteria that may not be fully met.
6. **CI/workflow failures** — if any checks failed, treat each distinct failure as an indexed item.

**For each item found, assign a sequential ID** (e.g., `ISS-01`, `ISS-02`, ...).

**Index every item, then assign status. Never drop an item before indexing it.** Items that are optional, deferred, advisory, framed as live-verification follow-ups, or otherwise non-actionable still get an `ISS-NN` ID and an explicit terminal status — `❌ Out of scope` (with a one-line reason) is the default for these. The terminal statuses available at indexing time are: `✅ Already resolved`, `⚠️ Needs clarification`, `❌ Not reproducible`, `❌ Out of scope`. Items still being worked stay `🔍 Pending` until Phase 2 resolves them. Silent omission is a Phase 1 failure: if the author can't tell whether you saw an item, you didn't run Phase 1 correctly.

**Always post the index as a standalone PR comment before starting fixes**, regardless of item count. This comment must precede any fix commits and must be distinct from the Phase 3 Resolution Report. **If the PR has more than 10 items**, additionally proceed in batches of 5 to prevent token exhaustion and let the author course-correct early.

**If an item was already addressed** in a subsequent commit or resolved thread: mark it `✅ Already resolved` with a link to the resolving commit, and skip to the next item.

### Index Output Format

Post this as a PR comment before starting fixes:

```markdown
## Issue/Suggestion Index

| ID | Source | Summary | Classification | Status |
|----|--------|---------|----------------|--------|
| ISS-01 | [Review comment](link) | Missing null check on `user` param | substantive | 🔍 Pending |
| ISS-02 | [PR description](link) | TODO: add rate limiting | nit | 🔍 Pending |
| ISS-03 | [Code comment](link) | FIXME in src/auth.ts:42 | substantive | 🔍 Pending |
| ISS-04 | [CI failure](link) | TypeScript build error | substantive | 🔍 Pending |
| ISS-05 | [Review comment](link) | Suggestion: extract helper fn | nit | ✅ Already resolved in abc1234 |
| ISS-06 | [Review body](link) | Optional: rename `foo` → `bar` for clarity | nit | ❌ Out of scope — purely advisory; defer to follow-up |
| ISS-07 | [Review body](link) | Live-verify multiple-reviews edge case post-merge | out-of-scope | ❌ Out of scope — verification step, not a diff change |
| ISS-08 | [Review body](link) | `find \| while` without `-print0` (3rd round) | known-limitation | ❌ Known limitation KL-NN — documented in file header and BUGBOT.md/styleguide.md |

**Total**: X items found, Y already resolved, Z to address.
Classification: W substantive, V nits, U out-of-scope/KL.
Proceeding with fixes (substantive first, nits last).
```

## Phase 2: Verify, Fix, Validate Each Item

For each unresolved item, work through this sequence. Do not skip steps.

> **Sandbox-class PRs (issue #227 / ADR-016)**: when this PR's
> Implementation Plan declares `Change class: default-branch-only
> workflow` (or `mixed` with a default-branch-only path), the
> trigger constraint means a fix to the workflow file cannot be
> exercised on the PR branch — GitHub Actions will load the workflow
> from `main`, not from the PR ref. Pre-merge verification *must*
> happen in the sandbox sibling repo per
> [`docs/guides/sandbox-verification.md`](../../docs/guides/sandbox-verification.md).
> If a Phase-2 Step-4 validation depends on observing the trigger
> firing, run that validation in sandbox and link the green sandbox
> run from the Resolution Report. Skipping this step is the failure
> mode that produced the 11-round PR #225 cycle.

### Step 1 — Link

Provide a direct URL to where the issue was mentioned (review comment permalink, PR description section, file + line in the diff, or issue number).

### Step 2 — Verify

Confirm the issue actually exists in the current state of the branch. This means:

- For bugs/logic issues: read the relevant code and confirm the problem. If possible, describe a concrete scenario that would trigger it.
- For missing tests: confirm the behavior is untested by searching the test files.
- For style/refactor suggestions: confirm the code matches what the reviewer described.
- For CI failures: read the failure log and identify the root cause.
- If the issue is **not reproducible** (already fixed, reviewer was mistaken, or the code has changed): document why and mark it accordingly. Do not fabricate a fix for a non-issue.

### Step 3 — Fix

If the issue is valid, implement the fix:

- Make the smallest change that addresses the issue.
- Stay inside the files already touched by this PR when possible. If a fix requires changes to files outside the PR's scope, flag it and ask before proceeding.
- For refactor suggestions: apply only if the suggestion is clearly better. If it's a judgment call, implement it but note that the author may want to review.
- **Fix-only commits**: each commit in this fix pass must address only one indexed item (whether substantive or nit). Do not refactor surrounding code, rename variables, reorganize imports, or make style improvements in the same commit — note them in Phase 3 "Additional Observations" and commit separately or file a follow-up. This is consistent with Round discipline Rule 3 ("Classify before fixing", issue #220), which keeps each fix in its own commit. (Evidence: PR #228 Round 5 combined a real fix with a `grep | wc -l` → `grep -c` refactor in one commit; the refactor changed exit-code semantics under `set -e` and caused the Round 7 regression.)
- Include the exact file path and line numbers in your report.

### Step 4 — Validate

After each fix (or batch of fixes):

- Run the test suite. Report pass/fail counts.
- Run the linter. Report clean/error counts.
- Run the build/typecheck. Report success/failure.
- If the repo has an `AI_REPO_GUIDE.md`, use its commands as canonical. Otherwise, detect from `package.json`, `Makefile`, `pyproject.toml`, etc.
- If a verification command is not available or not applicable, say so explicitly rather than skipping silently.

### Step 5 — Status

Assign one of:

- `✅ Fixed` — issue was valid, fix implemented, verification passed.
- `✅ Already resolved` — issue was already addressed before this run.
- `⚠️ Needs clarification` — issue is ambiguous, or the right fix depends on a design decision the author should make. Describe what's unclear and suggest options.
- `⚠️ Partial fix` — fix addresses part of the issue but something remains. Explain what's left.
- `❌ Not reproducible` — the issue does not exist in the current code. Explain why.
- `❌ Out of scope` — fix requires changes to files/systems outside this PR, OR the item is purely advisory/optional with no clear action, OR it's a live-verification step that cannot be addressed in the diff. Describe what's needed (or why it's non-actionable) so the author can file a follow-up or defer appropriately.

**Promote repeat-deferred findings to the skip list.** If a finding's status
is `❌ Out of scope`, `❌ Not reproducible`, or `❌ Known limitation` **and**
the same finding (same `file:line` or same class of pattern) has been
raised by any review bot in a prior round of this PR, add a one-line entry
to `.cursor/BUGBOT.md` and `.gemini/styleguide.md` under "Project
conventions (skip these classes of finding)" (or as a new `KL-NN` if it's
a specific known limitation in a script's own code) **before** posting the
deferral reply. The dedup meta-instruction in those files is best-effort;
an enumerated entry is deterministic. This converts ad-hoc deferrals into
durable suppressions across future rounds and future PRs.

## Phase 3: Resolution Report

After all items are processed, post a final summary comment:

```markdown
## Resolution Report

### Summary
- **Total items found**: X
- **Already resolved**: X
- **Fixed in this pass**: X
- **Needs clarification**: X
- **Not reproducible**: X
- **Out of scope**: X

<!--
Required from round 4 onward when `cap-override` is in effect on this PR
(see "Override justification" under Round disciplines). Omit this line otherwise.
When required, copy EXACTLY ONE of these lines (outside this comment block):
  Override justification: sandbox-class
  Override justification: legitimate refactor
  Override justification: complex semantic dependency
  Override justification: other: <≤80-char reason>
-->

### Verification
- Tests: ✅ X passed, ❌ X failed
- Lint: ✅ Clean / ❌ X errors
- Build: ✅ Success / ❌ Failed
- Typecheck: ✅ Clean / ❌ X errors

### Additional Observations
(optional) Drive-by nits, refactors, or style improvements noticed during the fix pass but deferred per the fix-only commits rule. Commit separately or file as a follow-up issue.

### Detail

---

#### ISS-01: Missing null check on `user` param
- **Source**: [Review comment](link)
- **Evidence**: `src/auth.ts:42` — `user` parameter is used without a null guard. If the session lookup returns null (expired session, deleted user), this throws an unhandled TypeError.
- **Fix**: Added null check with early return of 401 at `src/auth.ts:42-45`. Commit: `abc1234`.
- **Verification**: `npm test` — 47 passed, 0 failed. New test added in `tests/auth.test.ts:89`.
- **Status**: ✅ Fixed

---

#### ISS-02: TODO: add rate limiting
- **Source**: [PR description](link)
- **Evidence**: Confirmed — no rate limiting exists on the `/api/login` endpoint. The TODO in the PR description is a known deferred item.
- **Fix**: N/A — this is a follow-up item, not a bug in the current diff.
- **Verification**: N/A
- **Status**: ❌ Out of scope — recommend filing as a separate issue.

---

(continue for each item)
```

## Phase 4: Resolve bot-authored review threads

Phase 4 runs on every invocation of this prompt — Claude via `.github/workflows/agent-fix-reviews.yml`, Copilot via `@copilot follow` comments posted by `.github/workflows/agent-relay-reviews.yml` or by a human, and any agent invoked through a direct `@claude follow` / `@copilot follow` mention. If you are running this prompt, the gate below applies to you.

Resolve review threads whose backing item cleared Phase 2 with status `✅ Fixed` and whose top-level review comment was authored by an allow-listed bot. The point is to trim noise from CI-only reviewers after the fix has landed — never to silence a human. The per-thread gate below is the only safety mechanism.

### Allow-list (bot reviewers only)

**Normalization rule:** GitHub's REST and GraphQL APIs disagree on bot login formatting — REST returns `gemini-code-assist[bot]`, while GraphQL often returns the same identity as `gemini-code-assist` (no `[bot]` suffix). Before comparing, **strip any trailing `[bot]` from the login** and then compare case-insensitively against the normalized allow-list below. This is the canonical matching rule for Phase 4; apply it whichever API (REST or GraphQL) you sourced the login from. `scripts/lib/bot-allowlist.txt` is the canonical machine-readable source for the same normalized set; keep the human-readable list below in lockstep with that file. (`.github/workflows/agent-relay-reviews.yml` has separate bot-detection logic that matches on either a `[bot]` suffix **or** a literal allow-regex rather than stripping and normalizing — do not rely on that workflow's matcher as a reference for Phase 4.)

Normalized allow-list (match with `[bot]` stripped and compared case-insensitively):

- `gemini-code-assist`
- `copilot-pull-request-reviewer`
- `copilot` (the Copilot SWE agent; REST returns `Copilot`, GraphQL returns `copilot`)
- `chatgpt-codex-connector`
- `codex` (the shorter form Codex sometimes emits)
- `cursor` (Cursor Bugbot; REST returns `cursor[bot]`)
- `claude` — **only when the thread's root comment was authored directly by the `claude[bot]` / `claude` identity** (e.g., Claude's auto-review workflow posted the review). If a human opened the thread and `claude[bot]` merely replied (for example because the human wrote `@claude fix this` mid-thread), the root author is the human and Phase 4 must leave the thread open. The per-thread gate below already enforces "root author is allow-listed" — this bullet is a reminder that the root-author test is what keeps human-initiated dialogues from being silenced.

Worked example: a GraphQL-returned author `gemini-code-assist` → strip `[bot]` (no-op) → lowercase → matches `gemini-code-assist` ✅. A REST-returned author `gemini-code-assist[bot]` → strip `[bot]` → `gemini-code-assist` → lowercase → matches ✅.

Threads opened by any other login — including humans, unknown bots, and GitHub Actions user accounts — **must be left open**, even if the corresponding Phase 2 item was fixed.

### Per-thread gate

Resolve a thread only when **all** of the following hold:

1. The thread's root comment was authored by an allow-listed bot.
2. The Phase 2 status for the matching `ISS-NN` item is `✅ Fixed` (never `⚠️`, `❌`, `Already resolved`, or `Needs clarification`).
3. Phase 2 verification passed — tests, lint, build, and typecheck were all green for the batch that contained the fix.
4. The thread is not already resolved (`isResolved == false`).

Note: do **not** skip threads solely because they are `isOutdated`. Phase 4 runs **after** the fix commit is pushed, and a thread's commented line is frequently moved or replaced by that commit, which flips `isOutdated` to `true`. Condition 2 (Phase 2 marked the item `✅ Fixed`) is what guarantees the concern was actually addressed; `isOutdated` is just a side-effect of the fix and is not a blocker. `agent-auto-merge.yml` blocks on `isResolved == false` without considering `isOutdated`, so leaving outdated-but-fixed bot threads unresolved would defeat the entire purpose of Phase 4.

If any condition fails, skip the thread and record why in the Phase 4 log. Do not attempt to resolve threads you did not fix in this run.

### Resolve procedure

For each eligible thread:

1. **Fetch the thread node ID** via the GraphQL `pullRequest.reviewThreads` query. The REST review-comments endpoint does not return the node ID required by `resolveReviewThread`, so GraphQL is mandatory here. Example:

   ```graphql
   query($owner:String!, $repo:String!, $num:Int!) {
     repository(owner:$owner, name:$repo) {
       pullRequest(number:$num) {
         reviewThreads(first:100) {
           nodes {
             id
             isResolved
             isOutdated
             comments(first:1) {
               nodes { author { login } path line databaseId }
             }
           }
         }
       }
     }
   }
   ```

   Paginate if the PR has more than 100 threads.

2. **Post an audit-trail reply** on the thread before resolving, so the resolution is traceable without digging through workflow logs. Use `addPullRequestReviewThreadReply` (GraphQL) or the REST `POST /repos/{owner}/{repo}/pulls/{num}/comments/{comment_id}/replies` endpoint. Reply body format:

   ```text
   Resolved by <agent> in <SHORT_SHA> (ISS-NN).
   If this wasn't addressed correctly, re-open the thread.
   ```

   Substitute:
   - `<agent>` — the agent that ran this procedure. **Always backtick-wrap any literal `@`-handle** in the reply body (write `` `@copilot` ``, `` `@claude` ``, `` `@copilot follow ...` `` — not the raw `@copilot` / `@claude` strings). An un-escaped handle in a thread reply is parsed by GitHub as a real mention and re-triggers the bot (Copilot cloud agent on `@copilot`; `.github/workflows/claude.yml`'s `claude-mention` job on `@claude`), which then re-fixes everything you just fixed and posts duplicate Resolution Reports. The top-level trigger comment (`@copilot follow ...` / `@claude follow ...`) stays un-backticked — that's the intended dispatch; the audit reply must not re-dispatch. Use `claude (agent-fix-reviews)` when invoked by `.github/workflows/agent-fix-reviews.yml`, `copilot (via agent-relay-reviews)` when invoked by an `` `@copilot follow` `` comment from `.github/workflows/agent-relay-reviews.yml`, `` claude (`@claude` mention) `` / `` copilot (`@copilot` mention) `` when invoked by a direct human mention, or your own agent name if invoked by other tooling.
   - `<SHORT_SHA>` — the resolving commit SHA (first 7 chars).
   - `ISS-NN` — the ID from your Phase 1 index.

   If you know your fix-cycle number (e.g. the Claude path exposes cycle `N/3`), append `, cycle N/3` after the `ISS-NN` for additional traceability. Omit it if unknown.

3. **Fire the `resolveReviewThread` mutation** with the thread node ID:

   ```graphql
   mutation($id:ID!) {
     resolveReviewThread(input:{threadId:$id}) { thread { id isResolved } }
   }
   ```

   Confirm `isResolved: true` in the response. If the mutation fails, leave the thread open and log the error — do not retry silently.

### Phase 4 report

Because Phase 4 runs **before** Phase 3 posts the Resolution Report (see "How to run this prompt" at the top of this file), include the following section within the Phase 3 Resolution Report itself, listing every thread considered. Do not post Phase 4 as a separate comment. The `Thread ID` column is **required** — it is the GraphQL node ID (`PRRT_…`) that the relay-fallback job in `agent-relay-reviews.yml` parses to retry mutations on the Copilot path; omitting it breaks the fallback.

```markdown
### Phase 4 — Thread auto-resolution

| Thread | Thread ID | ISS | Author | Action | Notes |
|--------|-----------|-----|--------|--------|-------|
| [link](#) | PRRT_kwDOExampleA | ISS-01 | gemini-code-assist[bot] | ✅ Resolved | Fixed in abc1234 |
| [link](#) | PRRT_kwDOExampleB | ISS-02 | copilot-pull-request-reviewer[bot] | ⚠️ Errored | addPullRequestReviewThreadReply returned FORBIDDEN |
| [link](#) | PRRT_kwDOExampleC | ISS-03 | human-reviewer | ⏭️ Skipped | Human-authored — left open |
| [link](#) | PRRT_kwDOExampleD | ISS-04 | gemini-code-assist[bot] | ⏭️ Skipped | Phase 2 status was "Needs clarification" |
```

Use `⚠️ Errored` when the per-thread gate passed but the GraphQL mutation failed (e.g. `FORBIDDEN`). On the Copilot path, the relay-fallback job will pick up `⚠️ Errored` rows by Thread ID, post the audit reply under `CLAUDE_PAT`, and fire `resolveReviewThread`. Use `⏭️ Skipped` only when the per-thread gate failed (human author, status not `✅ Fixed`, etc.) — that signals the fallback to leave the thread alone.

### Safety rules

- **Never resolve a human-authored thread**, even if you fixed what they asked for. Humans expect to click Resolve themselves.
- **Never resolve a thread whose Phase 2 item is not `✅ Fixed`.** "Not reproducible" and "Out of scope" still warrant human acknowledgement.
- **Never resolve a thread without first posting the audit reply.** The reply is the paper trail; resolution without it leaves reviewers guessing.
- **Never include a live `@`-handle in the audit reply body.** Backtick-wrap every `@copilot` / `@claude` / `@copilot follow ...` / `@claude follow ...` reference in the reply so GitHub treats it as code, not a mention. An un-wrapped handle re-dispatches the bot (Copilot cloud agent + `.github/workflows/claude.yml`'s `claude-mention` job both listen for raw `@`-strings anywhere in a PR comment or review reply body) and produces duplicate fix runs. The **top-level trigger comment** that invoked `pr-resolve-all.md` in the first place stays un-backticked — that one is supposed to dispatch.
  - **Nested-backtick gotcha.** GitHub Flavored Markdown does **not** honor `\`` to escape a backtick inside a code span. Writing a single-backtick-wrapped span that contains `` `@copilot` `` does not produce one nested code span; the outer span closes at the first inner backtick and the trailing text falls back into plain text, which dispatches a real mention. To embed a literal backtick in a code span, wrap the outer span in double backticks: ``copilot (`@copilot` mention)``. When in doubt, don't nest — just write `@copilot` standalone in plain prose. (PR #216 hit this and spawned 4 spurious cloud-agent sessions.)
- **Do not resolve threads from a previous fix cycle.** Scope Phase 4 to items fixed in the current run only — the `ISS-NN` IDs from this run's Phase 1 index are your scope.

## Rules

- **Do not fabricate issues.** Only index things that are explicitly mentioned in the sources listed in Phase 1, or concrete problems you can verify in the code.
- **Do not make drive-by changes.** Fix only what's indexed. If you notice something else while working, note it at the bottom of the report under "Additional Observations" but do not fix it without asking.
- **Do not mark something fixed without verification.** Every `✅ Fixed` must have a passing test/lint/build result.
- **Preserve existing behavior.** Fixes should not change functionality beyond what's needed to resolve the indexed issue.
- **If you run out of context or token budget**: Post what you have so far with a clear "Batch 1 of N complete — proceeding with next batch" marker. Do not silently truncate.
- **If `AI_REPO_GUIDE.md` exists**, read it first for canonical test/lint/build commands and repo conventions.
