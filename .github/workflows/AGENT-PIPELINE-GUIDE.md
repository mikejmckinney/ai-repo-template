# Autonomous Agent Pipeline — Operations Guide (v2)

## Overview

This pipeline automates the full development loop with **zero manual steps** after you create and assign an issue:

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

### Step 0: Backlog → issue (optional, automatic — backlog dispatch added in PR 3)

> **Status note (PR 2)**: `agent-assign-copilot.yml` and
> `agent-release-slot.yml` are now present in the repository.
> `.github/workflows/backlog-to-issues.yml` ships in PR 3 of the same
> series. Until that lands, `.context/backlog.yaml` exists as a planning
> artifact only; it is not auto-dispatched. You can still trigger the
> assign pipeline manually by applying the `copilot:ready` label to any
> issue.

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

### Step 4: Claude resolves ALL review comments (opt-in via `claude-fix` label)
`agent-fix-reviews.yml` triggers for `copilot/*` PRs labeled `claude-fix`
when a reviewer submits a `commented` / `changes_requested` review. It
waits 90 seconds for related review activity to settle, then runs Claude
Code Action (Sonnet) with `pr-resolve-all.md`. Claude reads comments
from **every** reviewer (including Gemini — something Copilot can't do),
fixes the issues, runs verification, and pushes.

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
label directly to the PR. To use the legacy Copilot-relay path instead,
add `copilot-relay` directly to the PR (issue labels are not
automatically copied to Copilot's PR). See `agent-relay-reviews.yml`.

### Step 5: Auto-merge (automatic)
`agent-auto-merge.yml` triggers when checks complete. If CI is green,
no outstanding change requests remain, and the PR isn't draft, it
squash-merges, deletes the branch, and closes the linked issue.

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
Expected cost: $1-3 per PR, or roughly $10-20 for the entire six-prompt POC build.

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
Create these in **Settings → Labels**:

| Label | Color | Purpose |
|-------|-------|---------|
| `agent-complete` | `#0E8A16` (green) | Merged and done |
| `no-auto-merge` | `#E4E669` (yellow) | Pause auto-merge for manual review |
| `no-auto-ready` | `#BFDADC` (light blue) | Opt out of automatic ready-state handling |
| `claude-fix` | `#FBCA04` (amber) | Opt PR in to `agent-fix-reviews.yml` (Claude resolution) |
| `copilot-relay` | `#5319E7` (purple) | Opt PR in to legacy `agent-relay-reviews.yml` (Copilot resolution) |

**Resolution-path selection:**
- Default: no automated resolution. Add a label to opt in.
- Add `claude-fix` to enable Claude (Sonnet) resolution of all bot/human
  review comments via `agent-fix-reviews.yml`. Workflow-file changes
  (`.github/workflows/**`) are auto-delegated to Copilot via an
  `@copilot` comment, because the Claude app token cannot push workflow
  edits.
- Add `copilot-relay` to enable the legacy relay path that forwards bot
  review comments to Copilot. Both labels can be combined when you want
  both paths running, though typically you'll pick one.

### 8. Install the workflow files
Copy to `.github/workflows/`:
- `agent-fix-reviews.yml` — Claude (Sonnet) resolves review comments (opt-in via `claude-fix`)
- `agent-relay-reviews.yml` — legacy Copilot relay (opt-in via `copilot-relay`)
- `agent-auto-ready.yml` — flips Copilot draft PRs to ready for review
- `agent-auto-merge.yml` — auto-merges when ready

Also add this repository secret in **Settings → Secrets and variables → Actions**:
- `CLAUDE_PAT` — fine-grained PAT required by `agent-fix-reviews.yml` so
  Claude can push review fixes when the trigger is a bot review. See the
  auth notes in `agent-fix-reviews.yml` for the exact token scope.

These work alongside your existing workflows:
- `claude.yml` — auto-review on PR open (already in your repo)
- `ci-tests.yml` — CI checks (already in your repo)

## Running a POC Build (example workflow)

> **Note**: The six issues below reference prompt files like
> `.github/prompts/01-init-project.md` and `.github/prompts/00-PROJECT-BRIEF.md`.
> Those files are **project-specific** and are **not included in this
> template** — they are example content from a Cloud Migration POC build
> that used this pipeline. To follow this pattern for your own project,
> author the prompt files first (one per implementation stage, plus a
> shared project brief) and then file issues that reference them.
>
> The only prompt file shipped with the template is
> `.github/prompts/pr-resolve-all.md`, which the review-resolution
> workflow uses internally.

### Create the six issues

Format each issue body with the prompt instructions and a reference to
the prompt file. Include `closes #N` so auto-merge closes the issue.

**Issue 1:**
```markdown
Title: Initialize project from ai-repo-template

Read and follow `.github/prompts/01-init-project.md`.
Also read `.github/prompts/00-PROJECT-BRIEF.md` for project context.

Initialize the Cloud Migration POC. Create directory structure, fill in
context files, set up CI pipeline. Run `./test.sh` to verify.
```

**Issue 2:**
```markdown
Title: Build Terraform infrastructure modules

Read and follow `.github/prompts/02-infrastructure-terraform.md`.
Also read `.github/prompts/00-PROJECT-BRIEF.md` for project context.

Create all Terraform modules for Snowflake and AWS. Verify with
`terraform fmt -check` and `terraform validate`.
```

**Issue 3:**
```markdown
Title: Build data pipeline (dbt + Airflow + sample data)

Read and follow `.github/prompts/03-data-pipeline.md`.
Also read `.github/prompts/00-PROJECT-BRIEF.md` for project context.

Create dbt project, Airflow DAGs, and sample data. Verify with
`dbt seed && dbt run && dbt test`.
```

**Issue 4:**
```markdown
Title: Build security and RBAC model

Read and follow `.github/prompts/04-security-rbac.md`.
Also read `.github/prompts/00-PROJECT-BRIEF.md` for project context.

Create RBAC documentation, SQL policy examples, and governance schema.
```

**Issue 5:**
```markdown
Title: Build interactive portfolio demo app

Read and follow `.github/prompts/05-portfolio-demo-app.md`.
Also read `.github/prompts/00-PROJECT-BRIEF.md` for project context.

Create the React demo application. Verify with `npm run build`.
```

**Issue 6:**
```markdown
Title: Documentation and portfolio polish

Read and follow `.github/prompts/06-documentation-polish.md`.
Also read `.github/prompts/00-PROJECT-BRIEF.md` for project context.

Create solution architecture doc, runbooks, and final README.
```

### Assign to Copilot

**Sequential (recommended for first run):**
1. Assign Issue 1 to `@copilot`
2. Watch the Agents panel on GitHub.com — you'll see Copilot working
3. Wait for it to merge (the full implement → review → fix → merge loop)
4. Assign Issue 2
5. Repeat

**Parallel (faster, possible conflicts):**
Issues 2, 3, and 4 touch different directories and can run simultaneously.
Assign all three to `@copilot` at once. Issues 5 and 6 should wait.

### Monitor progress
- **Agents panel**: github.com → your repo → Copilot tab shows active sessions
- **Actions tab**: shows workflow runs for fix-reviews and auto-merge
- **PR timeline**: shows cycle markers ("🔧 Claude fix cycle 1/3")
- **Issue timeline**: shows "✅ Done" when merged

## Manual Intervention Points

| Situation | What to do |
|-----------|-----------|
| Want to review before merge | Add `no-auto-merge` label to the PR |
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
| **Total for 6-prompt POC** | **~$10–20 API + subscription** | |

Compare to the all-Claude approach: $20–60 in API costs alone.

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
The workflow uses `workflow_run` (not `check_suite`) to detect CI
completion — GitHub suppresses `check_suite` events for Actions-based
workflows to prevent recursive loops. The `workflow_run` trigger
requires the workflow file to be on the default branch (`main`). If
you recently added the file, merge it to `main` first. Also check
branch protection: if reviews are required, bot reviews may not count.
Add `github-actions[bot]` to the bypass list.

**Gemini comments still not getting fixed:**
Verify that the `agent-fix-reviews.yml` workflow ran (Actions tab).
Claude should list all reviewers in its resolution report. If Gemini's
comments aren't in the index, check that the 90-second wait was enough
for Gemini to finish posting.

## File Reference

| File | Purpose | Needs API key? |
|------|---------|---------------|
| `.github/workflows/agent-assign-copilot.yml` | Gated Copilot assignment (concurrent + daily budget) | No (uses CLAUDE_PAT) |
| `.github/workflows/agent-release-slot.yml` | Releases slot on PR close/issue close, drains queue | No (uses CLAUDE_PAT) |
| `.github/workflows/agent-fix-reviews.yml` | Auto-trigger Claude (Sonnet) on reviews (opt-in via `claude-fix` label) | Yes (ANTHROPIC_API_KEY + CLAUDE_PAT) |
| `.github/workflows/agent-relay-reviews.yml` | Legacy Copilot relay (opt-in via `copilot-relay` label) | No (uses CLAUDE_PAT for posting) |
| `.github/workflows/agent-auto-merge.yml` | Auto-merge when ready; drains Copilot queue after merge | No (uses CLAUDE_PAT) |
| `.github/workflows/claude.yml` | Auto-review on PR open | Yes (ANTHROPIC_API_KEY) |
| `.github/workflows/ci-tests.yml` | CI checks | No |
| `.gemini/config.yaml` | Gemini review config | No (free GitHub App) |
| `.github/prompts/pr-resolve-all.md` | Review resolution procedure | Used by Claude |
| `.github/prompts/00-PROJECT-BRIEF.md` *(not in template)* | Project context | Used by Copilot + Claude |
| `.github/prompts/01–06-*.md` *(not in template)* | Per-stage implementation prompts | Used by Copilot |
