# Autonomous Agent Pipeline — Operations Guide (v2)

## Overview

This pipeline automates the full development loop. Two per-PR opt-in
gates are the only manual steps: add the `auto-merge` label to enable
auto-merge, and add the `claude-fix` label to enable Claude-driven
review resolution. Everything else (implementation, draft→ready
transition, CI, bot reviews, queue management) runs without
intervention:

```text
backlog.yaml          Issue auto-created       Gated assignment        Copilot implements
(machine-readable) →  (copilot:ready label) →  (concurrent + daily →   and opens PR
                                                budget; queue if full)         │
                                                                               ▼
                              Issue closed ◀── Auto-merge ◀── CI green + reviews clear
                                                       ▲
                                                       │
                                       Claude fixes review comments ◀── Review bots fire
```

**Backlog → issue → assignment** (Step 0) and **Copilot → review → fix → merge** (Steps 1–5) are two halves of one loop:

**Copilot** handles implementation (included in your subscription).
**Claude** handles review resolution (small API cost — $1-3 per PR).
**GitHub Actions** handles auto-merge (free).

## How It Works

### Step 0: Backlog → issue (optional, automatic)

`.context/backlog.yaml` is the machine-readable task list. Each entry
will become one GitHub issue via `.github/workflows/backlog-to-issues.yml`,
which is planned to fire on push to `main` (when `backlog.yaml` changes)
or on manual `workflow_dispatch`. Entries support `depends_on:` (waits
until the dependency's issue is closed), `auto_assign: false` (creates
the issue but holds it for human review), and Claude-assisted expansion
of missing `body` / `acceptance_criteria` when `ANTHROPIC_API_KEY` is
present. Newly-created issues will be tagged `from-backlog` and (unless
`auto_assign: false`) `copilot:ready`.

After an issue carries the `copilot:ready` label —
whether it came from the backlog, a `workflow_dispatch`, or a human
applying the label in the web UI — `.github/workflows/agent-assign-copilot.yml`
will take over: it checks the concurrent budget (`MAX_COPILOT_CONCURRENT`,
default 3) and the rolling 24-hour daily cap (`MAX_COPILOT_DAILY`,
default 10), then either assigns Copilot via GraphQL, swaps the label
to `copilot:queued`, or hard-stops with `copilot:daily-cap-hit`. The
queue drains automatically when a Copilot PR merges or a slot is
released (see `agent-release-slot.yml`).

Schema: validate `backlog.yaml` locally with
`pip install check-jsonschema && check-jsonschema --schemafile .context/backlog.schema.json .context/backlog.yaml`.

### Step 1: You create an issue and assign to Copilot

Write an issue with the prompt instructions. Assign `@copilot` as the assignee.
Copilot reads `AGENTS.md`, your custom instructions, and the issue body, then
works autonomously in a GitHub Actions environment.

### Step 1.5: Implementation plan posted as issue comment (required)

Before writing any implementation code, the assigned agent posts an
Implementation Plan as a comment on the issue using
`.github/PLAN_TEMPLATE.md`. The plan captures the implementer's lens
(approach, files touched, verification, risks) — complementary to the
issue template, which captures the *what* and *why*. v1 has no
approval gate: the plan is reviewed at PR time, but writing it forces
implementation thinking before code (ADR-011).

ADR-026 extends the plan with a `plan_compliance` block. For non-exempt
work, include the parent startup evidence, applicable roles, process resources
that affected decisions, planned subagents, gate state, ADR/doc-sync state,
and planned verification. The block is review evidence first; it must not
claim that CI can prove a model runtime actually read or dispatched anything.

Exemptions: issues labeled `chore:no-plan`, automation-bot authors
(Renovate, Dependabot), and revert PRs of a prior PR. The companion
rule — every PR body must link the issue or a parent PR (`Closes #NN`,
`Refs #NN`, `Implements ADR-NNN`) — is enforced by Judge at diff-gate.
The PR body's `## Plan` section (populated at PR-open in Step 2) is the
reviewer-facing breadcrumb to the canonical plan comment — when the plan
is revised after the PR is open, refresh that section in the same push
as the divergent code and tick the matching box in `## Plan revision
sync`. Judge advises (REQUEST_CHANGES, not BLOCK) on missing or stale
entries in v1.

### Step 2: Copilot opens a PR (automatic)

Copilot creates a `copilot/issue-{number}` branch, implements the feature,
and opens a draft PR. After the Copilot run finishes, the
`agent-auto-ready.yml` workflow transitions the PR from draft to ready
for review automatically (Copilot itself leaves PRs as drafts).

For non-exempt PRs, fill the PR template's `parent_compliance` block before
requesting review. If role subagents were used, copy their parsed
`subagent_compliance` objects into `subagents_dispatched`; raw pasted YAML may
be retained for provenance but is not the canonical validator input.

### Step 3: Review bots fire (automatic)

With workflow approval disabled (see Setup below), these fire immediately on PR open / `ready_for_review`:

- **Gemini Code Assist** — posts review via `gemini-code-assist[bot]`
- **Claude auto-review** — posts review via your `claude.yml` workflow
- **Copilot code review** — posts review if configured as a required reviewer
- **CI checks** — your `ci-tests.yml` runs

**Re-review on push** — `agent-review-on-push.yml` nudges Gemini and Copilot to re-review after every push to an open non-draft PR. Enabled by default; set repo variable `REVIEW_ON_PUSH=false` to disable. See "Alternative: Copilot ruleset" below for a server-side option that did not work for this repo.

**Manual override** — anyone (agent or human) can comment `/gemini review` directly on a PR to force a fresh Gemini review. This is documented as a belt-and-suspenders escape hatch; the workflow is the primary mechanism.

**Alternative: Copilot ruleset** — GitHub offers a server-side ruleset (Settings → Rules → Rulesets → "Automatically request Copilot code review") that should re-request Copilot on every push. We tried it on this repo (April 2026) and it did **not** fire on push. Keeping it enabled is harmless (worst case, Copilot reviews twice if GitHub later fixes it). If the ruleset works for your fork, you can drop the Copilot half of `agent-review-on-push.yml`.

### Step 4: Resolve review comments (opt-in via `claude-fix` or `copilot-relay` label)

`agent-fix-reviews.yml` (Claude path) and `agent-relay-reviews.yml`
(Copilot path) are alternative review-resolution workflows. Pick one
per PR by adding the corresponding label — see
§"Resolution-path selection" under Setup for the tradeoff. The
Claude-path description below applies symmetrically to the Copilot path,
except that Copilot reads its own review comments and the Phase 4
thread-resolution mutations may need the `phase4-fallback` job (ADR-008).

`agent-fix-reviews.yml` triggers for same-repo PRs labeled `claude-fix`
when a reviewer submits a `commented` / `changes_requested` review, or
when the `claude-fix` label is added to a PR retroactively (useful if
you forgot to opt in at PR-open time). It waits 90 seconds for related
review activity to settle, then runs Claude Code Action (Sonnet) with
`pr-resolve-all.md`. Claude reads comments from **every** reviewer
(including Gemini — something Copilot can't do), fixes the issues,
runs verification, and pushes.

Between review-resolution rounds, `pr-resolve-all.md` now prefers the
repo-local helper `scripts/pr-resolve-all-poll.sh <PR_NUMBER>` over a
blind settle sleep. The helper is intentionally pre-#321: it reads the
canonical bot identities from `scripts/lib/bot-allowlist.txt`, polls
live GitHub PR state, emits a machine-readable `RESULT=...` line plus
`HEAD=...` when the current PR head is available, and still leaves a
documented time-based fallback in the prompt for sessions without
working `gh` / GraphQL access.

In this pre-#321 helper contract, `RESULT=CONVERGED` is intentionally
stricter than the quiet fallback: it requires an explicit current-head
review signal from each participating allow-listed bot with no unresolved
bot-rooted threads of its own. Comment-only bot activity can still move
forward via `RESULT=QUIET_ELAPSED`, but it does not prove current-head
convergence by itself.

Note: the workflow triggers only on `pull_request_review` (submitted),
not on `pull_request_review_comment`. A review with N inline comments
fires N comment events plus one review-submitted event; triggering on
both would cause Claude to run twice per review cycle.

The workflow is intentionally **not** triggered on `check_suite`
failures: a CI failure without a corresponding review comment is
better surfaced via Claude auto-review or Gemini, which then turns
into a normal review-resolution cycle. Triggering on `check_suite`
also creates a loop hazard since each fix-cycle push produces another
check suite.

When a review item requires editing a file under `.github/workflows/**`,
Claude can't push the change itself (the GitHub App token blocks workflow
edits). Instead it posts a single `@copilot` comment summarizing the
delegated items so Copilot's cloud agent can take care of them.

To enable Claude resolution on a particular PR, add the `claude-fix`
label directly to the PR — either at PR-open time or retroactively. To
use the Copilot-relay path instead (free with your Copilot subscription;
no Anthropic API cost), add `copilot-relay` directly to the PR (issue
labels are not automatically copied to Copilot's PR, and both labels
can also be applied retroactively on an existing PR). The two paths
are alternatives, not deprecations — `claude-fix` is faster and reads
all reviewers in one pass; `copilot-relay` avoids the Anthropic API
cost. See `agent-relay-reviews.yml`.

**Bot-mention neutralization (relay path)**: when `agent-relay-reviews.yml` forwards review comment bodies in the relay comment, it wraps every `@`-mention except `@copilot` in backticks so forwarded text does not re-trigger other bots. The regex negative lookahead `(?!copilot(?:[^A-Za-z0-9_-]|$))` preserves the bare `@copilot` dispatch handle while wrapping all others (including `@copilot-swe-agent`). If a relayed review body re-triggers an unexpected bot, verify the neutralization step ran and check for an unguarded mention. See the `neutralize_mentions` / `def neutralize` jq function in the `build-relay-comment` step of `agent-relay-reviews.yml` for the canonical implementation. (Issue #225: a relayed Codex banner re-triggered Codex into a full session against the relay comment.)

### Step 5: Auto-merge (opt-in via `auto-merge` label)

`agent-auto-merge.yml` triggers when checks complete, reviews change, or
labels change. It is **opt-in**: a PR only auto-merges when a maintainer
(or automation) applies the `auto-merge` label to it. The label applies
to PRs on **any** branch — the label itself is the allow-list, not the
branch name. By default, auto-merge includes a bounded bot-review settle
window (up to ~4 minutes) so slower reviewers (for example Gemini Code
Assist and Copilot code review) can post before merge. For trivial /
low-risk changes, add `auto-merge-fast` to bypass that settle wait.

Once labeled, and when CI is green, no outstanding change requests
remain, all review threads are resolved, the PR is not draft, and there
are no merge conflicts, the workflow squash-merges, deletes the head
branch, and closes the linked issue. Fork PRs are refused regardless of
label (defense in depth).

## Workflow verifiability matrix

> **Why this matrix exists** (issue #227): GitHub Actions runs a
> workflow file from a specific git ref depending on its trigger. For
> some triggers, that ref is **always the default branch**, never the
> PR branch. A change to such a workflow on a PR branch is therefore
> structurally un-verifiable pre-merge — you can't observe the new
> behavior until after merge to `main`. PR #225 paid 11 rounds of bot
> review for one such change. The matrix below is the lookup that
> drives `scripts/verify-pr.sh` and the `Change class` field in
> `.github/PLAN_TEMPLATE.md`. ADR-016 captures the decision.

| Trigger event(s) in the workflow's `on:` block | Workflow file runs from | Verifiable on PR branch? | Plan-template `Change class` |
|---|---|---|---|
| `pull_request`, `workflow_dispatch` (only) | The PR branch (or the dispatched ref) | Yes | `pull_request-triggered workflow` |
| `pull_request_review`, `pull_request_review_comment` | Default branch | No | `default-branch-only workflow` |
| `pull_request_target` | Default (base) branch — GitHub loads the workflow from the PR's *base*, not the head, so PR-branch changes are unverifiable. This is also the trigger most commonly abused for write-permission escalation. | No | `default-branch-only workflow` |
| `issue_comment` | Default branch | No | `default-branch-only workflow` |
| `push`, `schedule` | Default branch | No | `default-branch-only workflow` |
| `workflow_run` (chained from another workflow), `repository_dispatch` | Default branch | No | `default-branch-only workflow` |
| Any combination of PR-triggered + default-branch-only triggers in the same file | The most-restrictive trigger wins | No | `default-branch-only workflow` |
| Diff that mixes a workflow file with non-workflow paths | n/a | Per-file basis | `mixed` (most-restrictive bucket sets the floor) |
| Diff that touches no `.github/workflows/*.yml` files | n/a | Yes | `code-or-docs` |

**How to apply the matrix**:

1. **At plan time** — Walk every changed path. Pick the most-restrictive class present and put it under the Verification section of your Implementation Plan comment as `Change class: <class>` and `Verification target: <PR branch | sandbox repo | both>`. The PLAN_TEMPLATE has the placeholder.
2. **Pre-push** — `bash scripts/verify-pr.sh --declared "<your declared class>"` (no args needed beyond `--declared`; it uses `git diff --name-only origin/main...HEAD`). Exit 0 means your declaration matches reality. Exit 1 prints the detected class and points you at the next step.
3. **In CI** — `verify-pr.sh` runs against the PR's changed-file list (sourced from the PR API into `PR_FILES`) and BLOCKs the merge if the declaration is too permissive for the diff. The Plan-comment authoring step is the gate; CI is the safety net.
4. **For default-branch-only / mixed PRs** — follow `docs/guides/sandbox-verification.md`. Push the same branch to the sandbox repo, merge it there, exercise the trigger event, and confirm green before merging here.

The classifier deliberately defaults to *more* restrictive when in doubt: a deleted workflow file (the body can't be inspected) is treated as `default-branch-only` so reviewers consciously confirm the removal is safe. False positives are easy to override (re-declare and proceed); false negatives are exactly the failure mode the gate exists to prevent.

## Invoking a prompt file manually

Both Claude and Copilot support a symmetric one-liner for running any prompt
under `.github/prompts/` against the current PR:

```text
@claude follow .github/prompts/pr-resolve-all.md
@copilot follow .github/prompts/pr-resolve-all.md
```

- `@claude follow <path>` is handled by `.github/workflows/claude.yml`'s
  `claude-mention` job — it triggers the Claude Code action on the comment,
  and Claude itself dereferences the path and reads the file.
- `@copilot follow <path>` is handled by a rule in
  `.github/copilot-instructions.md` ("Following referenced prompt files"),
  which Copilot's cloud agent loads on every run. No workflow or PAT is
  required; it's a pure prompt-file convention.

Both agents are instructed to execute every phase of the referenced prompt
in order and, when supported by the invocation path/tooling, should continue
in sequential `Part 1/N`, `Part 2/N` comments rather than truncating.

## Setup (One-Time)

### Required secrets

The agent workflows depend on two repository secrets. Every workflow that consumes them runs a `Verify required secrets` guard step that fails fast with an actionable message if a secret is missing (see issue #162). `scripts/setup.sh` reports presence after creating labels.

| Secret | Required by | Scopes / Source |
|--------|-------------|-----------------|
| `CLAUDE_PAT` | Agent workflows that call `gh` (assignment, auto-merge, auto-ready, fix-reviews, multi-dispatch, parallelism-report, relay-reviews, release-slot, auto-rebase-on-merge, backlog-to-issues, claude.yml) | Fine-grained PAT, this repo only: Contents R/W, Pull requests R/W, Issues R/W, Actions R, Variables R, Metadata R |
| `ANTHROPIC_API_KEY` | `agent-fix-reviews.yml`, `claude.yml`, optionally `backlog-to-issues.yml` (sparse-entry expansion) | API key from <https://console.anthropic.com> |
| `SANDBOX_BOOTSTRAP_TOKEN` | Sandbox verification steps (force-push sandbox `main`, push branch, `gh pr create/merge` on the sandbox repo). Used by agents running in workflows; maintainers running locally pass the same token as `BOOTSTRAP_GH_TOKEN` env var instead. | Classic PAT, `repo` + `workflow` scopes. Must be classic — fine-grained tokens cannot push `.github/workflows/` files without special account-level scope that typically isn't available until after the sandbox repo is created. See `docs/guides/sandbox-verification.md`. |

**Two ways to provide them**, in order of preference for users running multiple derived repos:

1. **Org-level (recommended for org users).** Org settings → Secrets and variables → Actions → New organization secret → grant access to the relevant repos. New repos in the org pick up the secrets automatically. The `Verify required secrets` guard treats org-granted secrets identically to per-repo ones.
2. **Per-repo.** Settings → Secrets and variables → Actions → New repository secret. Required for personal accounts and any repo not granted access to an org-level secret.

When a workflow fails with `Missing required secret: <NAME>`, the error annotation lists both remediation paths. `scripts/setup.sh` also prints a presence report at the end of its run.

### Repository variables

Set via **Settings → Secrets and variables → Actions → Variables tab**.

| Variable | Default | Description |
|----------|---------|-------------|
| `REVIEW_ON_PUSH` | on (unset = on) | When set to literal `false`, disables `agent-review-on-push.yml` nudges to Gemini + Copilot after each push to an open non-draft PR. Any other value (including unset) keeps it on. |
| `MAX_COPILOT_CONCURRENT` | `3` | Max concurrent Copilot sessions (open `copilot/` PRs + `copilot:in-progress` issues). |
| `MAX_COPILOT_DAILY` | `10` | Max Copilot assignments in a rolling 24-hour window. Spend thresholds: informational log at 50%, warning comment on issue at 75%, hard pause on new assignments at 90% (`copilot:budget-paused` label applied; bypassed by `cap-override` label on the issue — same label on a PR bypasses the round cap, see `PR_RESOLVE_MAX_ROUNDS` below), `copilot:daily-cap-hit` label at 100%. |
| `PR_RESOLVE_MAX_ROUNDS` | `3` | Max rounds `pr-resolve-all.md` runs per PR before escalating. **Also caps `agent-review-on-push.yml`** so Gemini/Copilot push-nudges stop firing after the same N rounds — without this, every fix-commit re-triggers stateless reviewers that re-flag already-deferred findings (PR #246 saw this across 13 rounds). Per-PR override: `cap-override` label on the PR (unbounded; bypasses both the agent-side cap and the push-nudge cap) or `@<agent> cap-override N` comment on the PR (N rounds). Manual `/gemini review` comments by humans are never gated. Only raise the default from 3 when a recurring class of PRs genuinely needs more rounds — raising it casually defeats the cost discipline the cap was designed to enforce. **Override justification (issue #229 Phase 4):** when override is in effect AND the round count is > 3, every Resolution Report from round 4 onward must include a literal `Override justification: <category>` line under `### Summary`. Categories: `sandbox-class`, `legitimate refactor`, `complex semantic dependency`, or `other: <≤80-char reason>`. Judge BLOCKs at diff-gate when the line is missing or its category text is malformed (`.github/agents/judge.agent.md` item 15). See `docs/guides/agent-pipeline.md` § "Manual Intervention Points" for the escape hatch. |

### 1. Copilot subscription

Any paid plan works: Pro ($10/mo), Pro+ ($39/mo), or Business ($21/seat/mo).
The cloud agent is included.

### 2. Anthropic API key

Get one from https://console.anthropic.com.
Add as repo secret: **Settings → Secrets and variables → Actions → `ANTHROPIC_API_KEY`**

This is ONLY used for review resolution (Step 4), not implementation.
Expected cost: $1-3 per PR.

### 3. Claude GitHub App

Install from https://github.com/apps/claude on your repo.

### 4. Gemini Code Assist (already installed)

Your `.gemini/config.yaml` and `.gemini/styleguide.md` configure its behavior.

### 5. Disable workflow approval for Copilot

**Settings → Copilot → Cloud agent → disable "Require approval for workflow runs"**

Without this, you'll have to manually click "Approve and run" every time
Copilot pushes — which defeats the purpose.

### 6. Branch protection (if enabled)

If `main` has branch protection requiring approvals:

- Add `github-actions[bot]` to the "Allow specified actors to bypass" list
- OR set required approvals to 0 (since bot reviews don't count as approvals)

### 7. Create labels

The labels in the table below are created automatically by `scripts/setup.sh`. Manual creation via **Settings → Labels** is only needed if you skipped that step or the setup.sh label-creation call failed (e.g., missing repo permissions).

| Label | Color | Purpose |
|-------|-------|---------|
| `agent-complete` | `#0E8A16` (green) | Merged and done |
| `auto-merge` | `#0E8A16` (green) | Opt PR in to `agent-auto-merge.yml` (applies to any branch) |
| `auto-merge-fast` | `#1D76DB` (blue) | Bypass auto-merge bot-review settle wait for this PR |
| `no-auto-ready` | `#BFDADC` (light blue) | Opt out of automatic ready-state handling |
| `claude-fix` | `#FBCA04` (amber) | Opt PR in to `agent-fix-reviews.yml` (Claude resolution) |
| `claude-review` | `#1D76DB` (blue) | Opt PR in to `claude.yml` auto-review (invokes judge subagent on open/reopen/ready_for_review) |
| `copilot-relay` | `#5319E7` (purple) | Opt PR in to `agent-relay-reviews.yml` (Copilot resolution; included in subscription) |
| `copilot:ready` | `#0E8A16` (green) | Assign Copilot when budget allows (applied to backlog issues unless `auto_assign: false`) |
| `copilot:in-progress` | `#1D76DB` (blue) | Assigned to Copilot; counts toward `MAX_COPILOT_CONCURRENT` |
| `copilot:queued` | `#FBCA04` (amber) | Waiting for an open Copilot slot (swapped in by `agent-assign-copilot.yml` when concurrent cap is hit) |
| `copilot:budget-paused` | `#E4E669` (yellow) | 90% daily spend threshold hit; **not** auto-drained by queue workers. Add `cap-override` + `copilot:ready` to resume manually |
| `copilot:daily-cap-hit` | `#D93F0B` (red-orange) | Hit `MAX_COPILOT_DAILY`; requires manual re-queue |
| `from-backlog` | `#5319E7` (purple) | Issue auto-created from `.context/backlog.yaml` |
| `needs-human` | `#B60205` (red) | Requires human input (e.g., empty roadmap phase, CI failure, sparse entry that couldn't be expanded) |
| `agent:claimed` | `#0969DA` (blue) | Agent has claimed the issue or PR; details live in the latest `agent-state:v1` comment |
| `agent:blocked` | `#D93F0B` (red-orange) | Agent work is blocked; details live in the latest `agent-state:v1` comment |
| `agent:awaiting-review` | `#F29513` (orange) | Agent work is awaiting review; details live in the latest `agent-state:v1` comment |
| `chore:no-plan` | `#EDEDED` (gray) | Exempt issue/PR from the plan-as-comment requirement (see ADR-011) |
| `outcome-validated` | `#0E8A16` (green) | Issue author has validated the user outcome inline; opts out of Analyst pre-flight gate (ADR-005, ADR-014) |
| `cap-override` | `#FBCA04` (amber) | Bypass max-round cap (`pr-resolve-all.md`) and 90% daily spend pause (`agent-assign-copilot.yml`) |
| `agent-suggested` | `#BFD4F2` (light blue) | Agent-surfaced opportunity; see process_opportunity_feedback rule. |

**Resolution-path selection:**

- Default: no automated resolution. Add a label to opt in.
- Add `claude-fix` to enable Claude (Sonnet) resolution of all bot/human
  review comments via `agent-fix-reviews.yml`. Workflow-file changes
  (`.github/workflows/**`) are auto-delegated to Copilot via an
  `@copilot` comment, because the Claude app token cannot push workflow
  edits.
- **Phase 4 (auto-resolve bot-authored threads) runs by default** on
  every invocation of `pr-resolve-all.md` — there is no opt-in label.
  Phase 4 matches reviewer identity by stripping any trailing `[bot]`
  from the login and comparing case-insensitively against the
  normalized allow-list below, once Phase 2 marks the matching `ISS-NN`
  item as `✅ Fixed` with passing verification. `scripts/lib/bot-allowlist.txt`
  is the canonical machine-readable source for this same normalized set.
  Keep the doc list and the prompt list in `.github/prompts/pr-resolve-all.md`
  in lockstep with that file:
  - `gemini-code-assist`
  - `copilot-pull-request-reviewer`
  - `copilot`
  - `chatgpt-codex-connector`
  - `codex`
  - `cursor`
  - `claude`
  Human-authored threads are never auto-resolved. Phase 4 is defined in
  `.github/prompts/pr-resolve-all.md`.
  > On the Copilot path (`copilot-relay` or `@copilot follow`), the
  > GraphQL mutations may return `FORBIDDEN` because the Copilot
  > cloud-agent token lacks `pull-requests:write`. The
  > `phase4-fallback` job in `agent-relay-reviews.yml` parses the
  > Phase 3 Resolution Report's `⚠️ Errored` rows by Thread ID and
  > retries the mutations under `CLAUDE_PAT`. See ADR-008.
- Add `copilot-relay` to enable the Copilot-relay path that forwards bot
  review comments to Copilot's cloud agent. Both labels can be combined
  when you want both paths running, though typically you'll pick one
  (Claude for speed and multi-reviewer coverage; Copilot to avoid the
  Anthropic API cost).

### 8. Install the workflow files

Copy to `.github/workflows/`:

- `agent-fix-reviews.yml` — Claude (Sonnet) resolves review comments (opt-in via `claude-fix`)
- `agent-relay-reviews.yml` — Copilot relay (opt-in via `copilot-relay`)
- `agent-auto-ready.yml` — flips Copilot draft PRs to ready for review
- `agent-auto-merge.yml` — auto-merges when ready
- `agent-review-on-push.yml` — nudges Gemini + Copilot to re-review after each push (opt-out via repo variable `REVIEW_ON_PUSH=false`)

Also add this repository secret in **Settings → Secrets and variables → Actions**:

- `CLAUDE_PAT` — fine-grained PAT required by `agent-fix-reviews.yml` so
  Claude can push review fixes when the trigger is a bot review. See the
  auth notes in `agent-fix-reviews.yml` for the exact token scope.

These work alongside your existing workflows:

- `claude.yml` — auto-review on PR open (already in your repo)
- `ci-tests.yml` — CI checks (already in your repo)

## Using this pipeline for your project

The end-to-end intent is **autonomous (or near-autonomous) project
build from a series of prompts**: a human (or upstream planning agent)
authors the per-stage prompt files, the backlog pipeline turns them
into issues, and the rest of this guide drives each issue to merge.
Manual issue filing is the fallback when you don't want the backlog
automation in the loop.

### Pipeline anatomy

The template ships the **infrastructure** (workflows, labels,
backlog schema, procedural prompts). Each derived project supplies its
own **content** (per-stage prompt files + backlog entries). The split:

| Layer | Ships with template? | Per-project content |
|-------|----------------------|---------------------|
| `agent-*.yml` workflows, labels, `setup.sh` | ✅ Yes | — |
| `.context/backlog.schema.json` + `backlog-to-issues.yml` + `agent-assign-copilot.yml` | ✅ Yes | — |
| `.github/prompts/pr-resolve-all.md` (review resolution) | ✅ Yes | — |
| `.github/prompts/expand-backlog-entry.md` (sparse-entry expansion) | ✅ Yes | — |
| `.github/prompts/repo-onboarding.md` (procedural) | ✅ Yes | — |
| `.context/backlog.yaml` | Stub with one example entry | Replace with your project's stage entries |
| `.github/prompts/00-PROJECT-BRIEF.md` (shared project context) | ❌ No | Author once per project |
| `.github/prompts/NN-<stage>.md` (one per implementation stage) | ❌ No | Author one per build stage; each becomes one issue |

### Worked example: cloud_migration_POC

A real downstream project built end-to-end with this pipeline lives at
[`mikejmckinney/cloud_migration_POC`](https://github.com/mikejmckinney/cloud_migration_POC).
It used **seven** stage prompts plus one project brief:

- [`.context/vision/00-PROJECT-BRIEF.md`](https://github.com/mikejmckinney/cloud_migration_POC/blob/main/.context/vision/00-PROJECT-BRIEF.md) — shared context referenced from every stage.
- [`.github/prompts/01-*.md` through `07-*.md`](https://github.com/mikejmckinney/cloud_migration_POC/tree/main/.github/prompts) — one stage per prompt (init, infrastructure, data pipeline, security/RBAC, demo app, documentation, polish).

The motivation for this template's backlog pipeline (`backlog.yaml` +
`backlog-to-issues.yml` + `agent-assign-copilot.yml`) and the
review-resolution path (`auto-merge`, `claude-fix`, `copilot-relay`
labels) came directly from operating that project: the backlog
automates the otherwise-manual step of filing one issue per prompt,
and the resolution labels automate the otherwise-manual step of
responding to review feedback. Lessons learned from running this and
future downstream projects are tracked under issue #150. A related
discovery — whether prompt files themselves should be the dispatch
source of truth (skipping `backlog.yaml`) — is tracked under issue
[#155](https://github.com/mikejmckinney/ai-repo-template/issues/155).

### Step-by-step

**1. Author the per-stage prompt files in your derived repo.**

Create `.github/prompts/00-PROJECT-BRIEF.md` (shared project context)
and one `.github/prompts/NN-<stage>.md` per implementation stage. Use
a two-digit numeric prefix (`01-`, `02-`, …) so the order is obvious
in directory listings and the Analyst pre-flight gate (defined in
`AGENTS.md` → "Analyst pre-flight gate") detects them by pattern. A
stage prompt should be self-contained: deliverables, constraints,
verification commands, and a reference back to `00-PROJECT-BRIEF.md`.
See the cloud_migration_POC prompts linked above for production-grade
examples.

Per ADR-014, the same Pre-Flight gate also fires on issues that
propose a novel user-facing deliverable without referencing an
`NN-*.md` prompt — ad-hoc feature issues using `feature_request.md`
with the `enhancement` label, ADRs proposing new agent surfaces, or
issue bodies pairing action verbs (build, implement, ship, create)
with user-facing nouns (UI, dashboard, page, service, pipeline,
dataset, demo, integration). Authors who have already validated the
outcome inline can opt out with the `outcome-validated` label plus an
inline outcome paragraph; see `AGENTS.md` → "Analyst pre-flight gate"
and `.agents/analyst.md` → "Pre-Flight Validation" for
the full trigger / exemption list.

**2. Mirror the prompts into `.context/backlog.yaml` (recommended primary path).**

For each stage prompt, add one entry to `.context/backlog.yaml` (the
machine-readable task list — schema in `.context/backlog.schema.json`).
On push to `main`, `backlog-to-issues.yml` files an issue per entry,
labels it `from-backlog` + `copilot:ready`, and lets
`agent-assign-copilot.yml` route it through the budget gates
(`MAX_COPILOT_CONCURRENT`, `MAX_COPILOT_DAILY`).

Use `depends_on:` to enforce build order between stages, and
`auto_assign: false` on any stage that should hold for human review
before Copilot picks it up. If `ANTHROPIC_API_KEY` is set, sparse
entries (missing `body` / `acceptance_criteria`) are auto-expanded
via `expand-backlog-entry.md`.

This is the intended primary path — it's what makes the pipeline
end-to-end automated. Skip to step 3 only if you want manual control
over issue filing for a specific project.

**3. (Fallback) File issues manually instead of via the backlog.**

If you don't want the backlog in the loop for a particular project,
file one issue per stage by hand. Each issue body needs three things:
a one-line title, a `Read and follow .github/prompts/<file>`
directive, and `closes #N` so auto-merge closes any linked tracking
issue.

```markdown
Title: <Stage name>

Read and follow `.github/prompts/NN-<stage>.md`.
Also read `.github/prompts/00-PROJECT-BRIEF.md` for project context.

<Any extra acceptance criteria specific to this issue.>
```

**4. Let the pipeline drive each issue to merge.**

Once issues exist (whether from the backlog dispatch or filed by
hand), Copilot is assigned automatically by `agent-assign-copilot.yml`
as slots open up. From there, Steps 1–5 above run unattended:
Copilot opens a draft PR → `agent-auto-ready.yml` flips it to ready
→ review bots fire → the chosen resolution path (`claude-fix` or
`copilot-relay`) addresses comments → `agent-auto-merge.yml`
squash-merges when CI is green.

For the first project on the pipeline, run **sequentially** (one
issue at a time) until you've verified the loop works end-to-end in
your repo. After that, run **in parallel** — assign multiple issues
at once. Stages whose ownership globs (per
`.context/rules/agent_ownership.md`) don't overlap are safe to run
concurrently. The Parallelism Report workflow (ADR-009) classifies
overlap per PR; auto-rebase-on-merge (ADR-010) handles soft overlaps
automatically post-merge.

**5. Monitor progress.**

- **Agents panel** — github.com → your repo → Copilot tab shows active
  Copilot sessions.
- **Actions tab** — workflow runs for backlog dispatch, fix-reviews,
  relay-reviews, and auto-merge.
- **PR timeline** — fix-cycle markers ("🔧 Claude fix cycle 1/3") and
  the Parallelism Report comment.
- **Issue timeline** — `agent-complete` label and "✅ Done" when merged.

## Manual Intervention Points

| Situation | What to do |
|-----------|-----------|
| Want the PR to auto-merge when ready | Add `auto-merge` label to the PR |
| Pause auto-merge on a labeled PR | Remove the `auto-merge` label |
| Enable Claude review resolution on this PR | Add `claude-fix` label |
| Use Copilot (not Claude) for review resolution | Add `copilot-relay` label |
| Fix cycle exhausted (3/3) | Review remaining comments yourself, merge manually |
| Fix cycle exhausted, want more rounds | Add `cap-override` label to the PR (unbounded) or comment `@<agent> cap-override N` (N rounds). See `PR_RESOLVE_MAX_ROUNDS` in Repository variables above. **From round 4 onward, every Resolution Report must include an `Override justification:` line** (issue #229 Phase 4); Judge BLOCKs at diff-gate without it. |
| Push-nudge cap hit (no Gemini/Copilot re-review on push) | Look for the `agent-review-on-push:cap-hit` marker comment on the PR. Same fix as above: `cap-override` label resumes automated nudges. To trigger a one-off re-review without removing the cap, post `/gemini review` as a regular comment yourself. |
| Copilot's implementation is wrong | Comment on the PR with corrections, Copilot picks them up |
| Claude can't resolve a comment | Marked as "Needs clarification" in the resolution report — address manually |
| Merge conflict between parallel PRs | Merge one first, then comment on the other asking Copilot to rebase |
| Want to skip review resolution | Merge the PR manually — the fix workflow won't interfere |

## Cost Breakdown

Two views: per-PR pipeline cost (workflow components below), and per-role dispatch cost (tier table below) introduced by [ADR-019](../decisions/adr-019-per-role-model-tiering.md).

### Per-PR pipeline cost

Reflects post-May-2026 model multipliers; figures are the working baseline against which Phase 1 / Phase 2 of [#220](https://github.com/mikejmckinney/ai-repo-template/issues/220) are measured.

| Component | Cost | Notes |
|-----------|------|-------|
| Copilot cloud agent (implementation) | Included in subscription | 1 premium request per session; multiplier varies by chat-default model |
| Copilot code review | Included | 1 premium request per review |
| Claude auto-review (claude.yml) | $0.05–0.10 per PR | Uses ANTHROPIC_API_KEY; defaults to Sonnet 4.6 post-Phase-1 |
| Claude review resolution | $1–3 per PR | The main API cost; per-round cost dominated by re-fetched context (Phase 1 loop discipline targets this) |
| Auto-merge workflow | Free | GitHub Actions minutes only |
| **Total per PR** | **~$1–3 API + subscription** | Scales linearly with PR count |

Compare to the all-Claude approach (Claude implements as well as resolves reviews): roughly 4–6× the per-PR API cost.

### Per-role dispatch tier (ADR-019)

Each role is pinned to a cost tier. The canonical table lives in [ADR-019 § Decision](../decisions/adr-019-per-role-model-tiering.md#decision); summary here for navigation:

| Role | Tier | Claude Code | Copilot |
|---|---|---|---|
| analyst, architect, judge | High | `claude-opus-4-7` | `'Claude Opus 4.7 (copilot)'` |
| critic, pm, backend, frontend, devops | Mid | `claude-sonnet-4-6` | `'Claude Sonnet 4.6 (copilot)'` |
| qa, docs | Low | `inherit` | *(omitted; inherits main session)* |

**Critic escalates to Judge (Opus) on `severity: high`** — role-to-role handoff, not in-place model upgrade.

**Copilot cost-ceiling caveat:** High-tier subagents on Copilot silently downgrade to the chat-default if the chat-default is below Opus. Set the picker to Opus before invoking analyst / architect / judge if you want them to actually receive Opus dispatch. See [ADR-019 Amendment #6](../decisions/adr-019-per-role-model-tiering.md#amendment-6--copilot-subagent-cost-tier-ceiling-limitation--workaround).

**Per-task upshift:** the [`Model tier:` field in `.github/PLAN_TEMPLATE.md`](../../.github/PLAN_TEMPLATE.md) lets a specific task override the role default upward (`top`) or downward (`cheap`); default is `mid`.

## Troubleshooting

**Copilot didn't pick up the issue:**
Ensure Copilot cloud agent is enabled (Settings → Copilot → Cloud agent).
The issue must be assigned to `@copilot`, not just mentioned.

**Workflow approval still required:**
Go to Settings → Copilot → Cloud agent → disable "Require approval for
workflow runs". This is per-repository.

**Claude doesn't run after reviews are posted:**
Check that `ANTHROPIC_API_KEY` is set in repo secrets. Check that the
PR branch starts with `copilot/` (the workflow filters on this).

**Auto-merge doesn't fire:**
First confirm the PR carries the `auto-merge` label — the workflow is
opt-in and does nothing without it. If the label is applied and the
workflow still doesn't act, the workflow uses `workflow_run` (not
`check_suite`) to detect CI completion — GitHub suppresses `check_suite`
events for Actions-based workflows to prevent recursive loops. The
`workflow_run` trigger requires the workflow file to be on the default
branch (`main`). If you recently added the file, merge it to `main`
first. Also check branch protection: if reviews are required, bot
reviews may not count. Add `github-actions[bot]` to the bypass list.

**Gemini comments still not getting fixed:**
Verify that the `agent-fix-reviews.yml` workflow ran (Actions tab).
Claude should list all reviewers in its resolution report. If Gemini's
comments aren't in the index, check that the 90-second wait was enough
for Gemini to finish posting.

## File Reference

| File | Purpose | Needs API key? |
|------|---------|---------------|
| `.context/backlog.yaml` | Machine-readable task list dispatched by backlog-to-issues.yml | No |
| `.context/backlog.schema.json` | JSON Schema for backlog.yaml; validated on every dispatch run | No |
| `.github/workflows/backlog-to-issues.yml` | Dispatches backlog entries into GitHub issues; Claude-expands sparse entries | Optional (ANTHROPIC_API_KEY for expansion) |
| `.github/workflows/agent-assign-copilot.yml` | Gated Copilot assignment (concurrent + daily budget) | No (uses CLAUDE_PAT) |
| `.github/workflows/agent-multi-dispatch.yml` | Manual fan-out: assigns a list of issues to Copilot in priority order, refuses conflicts (issue #114) | No (uses CLAUDE_PAT) |
| `.github/workflows/agent-release-slot.yml` | Releases slot on PR close/issue close, drains queue | No (uses CLAUDE_PAT) |
| `.github/workflows/agent-fix-reviews.yml` | Auto-trigger Claude (Sonnet) on reviews (opt-in via `claude-fix` label) | Yes (ANTHROPIC_API_KEY + CLAUDE_PAT) |
| `.github/workflows/agent-relay-reviews.yml` | Copilot relay (opt-in via `copilot-relay` label); also hosts the `phase4-fallback` job that retries Copilot's `⚠️ Errored` Phase 4 mutations under `CLAUDE_PAT` (see ADR-008) | No (uses CLAUDE_PAT for posting + fallback mutations) |
| `.github/workflows/agent-auto-merge.yml` | Auto-merge when ready; drains Copilot queue after merge | No (uses CLAUDE_PAT) |
| `.github/workflows/agent-review-on-push.yml` | Nudges Gemini (`/gemini review` comment under CLAUDE_PAT) + Copilot (GraphQL `requestReviewsByLogin` with `botLogins: ["copilot-pull-request-reviewer[bot]"]`) on each push to an open non-draft PR; opt-out via repo variable `REVIEW_ON_PUSH=false` | Yes (CLAUDE_PAT for Gemini comment author identity) |
| `.github/workflows/claude.yml` | Auto-review on PR open | Yes (ANTHROPIC_API_KEY) |
| `.github/workflows/ci-tests.yml` | CI checks | No |
| `.gemini/config.yaml` | Gemini review config | No (free GitHub App) |
| `.github/prompts/pr-resolve-all.md` | Review resolution procedure | Used by Claude |
| `.github/prompts/expand-backlog-entry.md` | Prompt for Claude to fill in sparse backlog entries | Used by Claude |
| `.github/prompts/00-PROJECT-BRIEF.md` *(author per project)* | Shared project context referenced by every stage prompt | Used by Copilot + Claude |
| `.github/prompts/NN-<stage>.md` *(author per project)* | One per implementation stage; each becomes one issue | Used by Copilot |
