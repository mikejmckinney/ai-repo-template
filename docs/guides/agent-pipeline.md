# Autonomous Agent Pipeline — Operations Guide (v2)

## Overview

This pipeline automates the full development loop. Two per-PR opt-in
gates are the only manual steps: add the `auto-merge` label to enable
auto-merge, and add the `claude-fix` label to enable Claude-driven
review resolution. Everything else (implementation, draft→ready
transition, CI, bot reviews, queue management) runs without
intervention:

```
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
default 20), then either assigns Copilot via GraphQL, swaps the label
to `copilot:queued`, or hard-stops with `copilot:daily-cap-hit`. The
queue drains automatically when a Copilot PR merges or a slot is
released (see `agent-release-slot.yml`).

Schema: validate `backlog.yaml` locally with
`pip install check-jsonschema && check-jsonschema --schemafile .context/backlog.schema.json .context/backlog.yaml`.

### Step 1: You create an issue and assign to Copilot
Write an issue with the prompt instructions. Assign `@copilot` as the assignee.
Copilot reads `AGENTS.md`, your custom instructions, and the issue body, then
works autonomously in a GitHub Actions environment.

### Step 2: Copilot opens a PR (automatic)
Copilot creates a `copilot/issue-{number}` branch, implements the feature,
and opens a draft PR. After the Copilot run finishes, the
`agent-auto-ready.yml` workflow transitions the PR from draft to ready
for review automatically (Copilot itself leaves PRs as drafts).

### Step 3: Review bots fire (automatic)
With workflow approval disabled (see Setup below), these fire immediately:
- **Gemini Code Assist** — posts review via `gemini-code-assist[bot]`
- **Claude auto-review** — posts review via your `claude.yml` workflow
- **Copilot code review** — posts review if configured as a required reviewer
- **CI checks** — your `ci-tests.yml` runs

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

### Step 5: Auto-merge (opt-in via `auto-merge` label)
`agent-auto-merge.yml` triggers when checks complete, reviews change, or
labels change. It is **opt-in**: a PR only auto-merges when a maintainer
(or automation) applies the `auto-merge` label to it. The label applies
to PRs on **any** branch — the label itself is the allow-list, not the
branch name. Once labeled, and when CI is green, no outstanding change
requests remain, all review threads are resolved, the PR is not draft,
and there are no merge conflicts, the workflow squash-merges, deletes
the head branch, and closes the linked issue. Fork PRs are refused
regardless of the label (defense in depth).

## Invoking a prompt file manually

Both Claude and Copilot support a symmetric one-liner for running any prompt
under `.github/prompts/` against the current PR:

```
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
| `no-auto-ready` | `#BFDADC` (light blue) | Opt out of automatic ready-state handling |
| `claude-fix` | `#FBCA04` (amber) | Opt PR in to `agent-fix-reviews.yml` (Claude resolution) |
| `claude-review` | `#1D76DB` (blue) | Opt PR in to `claude.yml` auto-review (invokes judge subagent on open/reopen/ready_for_review) |
| `copilot-relay` | `#5319E7` (purple) | Opt PR in to `agent-relay-reviews.yml` (Copilot resolution; included in subscription) |
| `copilot:ready` | `#0E8A16` (green) | Assign Copilot when budget allows (applied to backlog issues unless `auto_assign: false`) |
| `copilot:in-progress` | `#1D76DB` (blue) | Assigned to Copilot; counts toward `MAX_COPILOT_CONCURRENT` |
| `copilot:queued` | `#FBCA04` (amber) | Waiting for an open Copilot slot (swapped in by `agent-assign-copilot.yml` when concurrent cap is hit) |
| `copilot:daily-cap-hit` | `#D93F0B` (red-orange) | Hit `MAX_COPILOT_DAILY`; requires manual re-queue |
| `from-backlog` | `#5319E7` (purple) | Issue auto-created from `.context/backlog.yaml` |
| `needs-human` | `#B60205` (red) | Requires human input (e.g., empty roadmap phase, CI failure, sparse entry that couldn't be expanded) |
| `coordination-sync` | `#BFDADC` (light blue) | Auto-filed by `agent-coordination-sync.yml` on the daily stale-lock tracking issue |
| `no-coordination-check` | `#EDEDED` (gray) | Opt PR out of `agent-coordination-sync.yml` suggestions |

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
  normalized allow-list (`gemini-code-assist`,
  `copilot-pull-request-reviewer`, `copilot`,
  `chatgpt-codex-connector`, `codex`, `claude`), once Phase 2 marks the
  matching `ISS-NN` item as `✅ Fixed` with passing verification.
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
| `.github/prompts/repo-onboarding.md` / `copilot-onboarding.md` (procedural) | ✅ Yes | — |
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
#155.

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
| Copilot's implementation is wrong | Comment on the PR with corrections, Copilot picks them up |
| Claude can't resolve a comment | Marked as "Needs clarification" in the resolution report — address manually |
| Merge conflict between parallel PRs | Merge one first, then comment on the other asking Copilot to rebase |
| Want to skip review resolution | Merge the PR manually — the fix workflow won't interfere |

## Cost Breakdown

| Component | Cost | Notes |
|-----------|------|-------|
| Copilot cloud agent (implementation) | Included in subscription | 1 premium request per session |
| Copilot code review | Included | 1 premium request per review |
| Claude auto-review (claude.yml) | $0.05–0.10 per PR | Uses ANTHROPIC_API_KEY |
| Claude review resolution | $1–3 per PR | The main API cost |
| Auto-merge workflow | Free | GitHub Actions minutes only |
| **Total per PR** | **~$1–3 API + subscription** | Scales linearly with PR count |

Compare to the all-Claude approach (Claude implements as well as resolves
reviews): roughly 4–6× the per-PR API cost.

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
| `.github/workflows/claude.yml` | Auto-review on PR open | Yes (ANTHROPIC_API_KEY) |
| `.github/workflows/ci-tests.yml` | CI checks | No |
| `.gemini/config.yaml` | Gemini review config | No (free GitHub App) |
| `.github/prompts/pr-resolve-all.md` | Review resolution procedure | Used by Claude |
| `.github/prompts/expand-backlog-entry.md` | Prompt for Claude to fill in sparse backlog entries | Used by Claude |
| `.github/prompts/00-PROJECT-BRIEF.md` *(author per project)* | Shared project context referenced by every stage prompt | Used by Copilot + Claude |
| `.github/prompts/NN-<stage>.md` *(author per project)* | One per implementation stage; each becomes one issue | Used by Copilot |
