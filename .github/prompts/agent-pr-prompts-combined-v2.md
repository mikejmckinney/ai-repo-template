---
description: Bundled five-PR pack for context rules decomposition and advisory review workflow.
agent: agent
---

<!-- markdownlint-disable MD025 MD012 -->

# Combined agent prompt pack v2


---

# File: README.md

# Agent prompt pack: context rules + non-blocking review workflow

Use these prompts to implement the PR sequence:

1. `01-context-decomposition.md`
2. `01b-rules-consolidation-and-legacy-retirement.md`
3. `02-advisory-review-mode.md`
4. `03-final-feedback-consolidation.md`
5. `04-postmerge-retrospective.md`

`00-coordinator.md` is an optional meta-prompt for an agent that will create the PRs sequentially.

## Operating assumptions

- Each prompt is meant to be run in a fresh branch from the current default branch.
- Each prompt should produce exactly one PR-sized change.
- The agent must read the current repo instructions before editing. Do not rely on the content in these prompt files as a substitute for the repo's current `AGENTS.md` / rule files.
- Do not bundle later PR work into an earlier PR.
- Prefer small, reviewable changes over sweeping rewrites.
- Keep automation opt-in by label unless the prompt explicitly says otherwise.
- Do not claim a Cursor/Gemini GitHub Actions integration is wired unless the repo already has a working action/CLI path for it. If no such path exists, add a provider abstraction or TODO documentation and keep the workflow disabled/label-gated.
- Treat `01b-rules-consolidation-and-legacy-retirement.md` as optional only if PR 1 already performed the broader `.context/rules` consolidation and retired the legacy redirect surface.

## Pack implementation status (repo: `ai-repo-template`)

| PR | Branch | Status on `main` |
|---|---|---|
| 1 | `feature/context-rule-decomposition` | Merged (context decomposition) |
| 1B | `feature/rules-consolidation-legacy-retirement` | Merged (`864aac1`) |
| 2 | `feature/advisory-review-mode` | Merged (`72bd1d9`) — `agent-advisory-review.yml`, `scripts/workflows/advisory-review/` |
| 3 | `feature/final-feedback-consolidation` | Merged (#382 @ `e0d845e`) — `agent-review-finalize.yml`, `scripts/workflows/pr-feedback/`, `.context/rules/README.md` read-profile catalog |
| 4 | `feature/postmerge-retro-review` | Merged (#383 @ `7e0bf68`) — `agent-postmerge-retro.yml`, `scripts/workflows/postmerge-retro/`, label `retro-review` |
| 4v2 | `feature/postmerge-retro-daily-v2` | **In PR** — nightly 06:00 UTC, umbrella issue/day, draft fix PR; cron + dispatch only (#426) |

PR 3 reuses advisory-review LLM runners (`run-advisory-cursor.mjs`, `run-advisory-gemini.py`) and `upsert-pr-comment.sh` (AP8 shared sticky-comment helper).


---

# File: 00-coordinator.md

# Coordinator prompt: implement context/review PRs in sequence

You are implementing a multi-PR change series in `ai-repo-template`.

## Goal

Implement a cheaper, targeted-context, non-blocking review architecture:

1. Decompose `AGENTS.md` and make `.context/rules/README.md` the rule catalog.
2. Consolidate `.context/rules` and retire the temporary legacy AGENTS anchor redirect surface.
3. Add opt-in rolling advisory review for draft/WIP PRs.
4. Add final feedback consolidation for completed implementations.
5. Add post-merge retrospective review that creates follow-up issues, ADR suggestions, and context-pack improvement suggestions.

## Required behavior

Before doing repo work, read the current repo startup instructions from the repository itself. If the repo still uses the pre-decomposition `AGENTS.md`, follow that. If PR 1 has already landed and the repo now uses `.context/rules/process_session_start.md`, follow that instead.

Make separate branches and separate PRs:

| PR | Branch suggestion | Prompt |
|---|---|---|
| 1 | `feature/context-rule-decomposition` | `01-context-decomposition.md` |
| 1B | `feature/rules-consolidation-legacy-retirement` | `01b-rules-consolidation-and-legacy-retirement.md` |
| 2 | `feature/advisory-review-mode` | `02-advisory-review-mode.md` |
| 3 | `feature/final-feedback-consolidation` | `03-final-feedback-consolidation.md` |
| 4 | `feature/postmerge-retro-review` | `04-postmerge-retrospective.md` |

## Sequencing rules

- Do not start PR 1B until PR 1 is merged or rebased on top of PR 1.
- Do not start PR 2 until PR 1B is merged or explicitly deemed unnecessary because PR 1 already consolidated rules and retired legacy redirects.
- Do not start PR 3 until PR 2 is merged or rebased on top of PR 2.
- Do not start PR 4 until PR 3 is merged or rebased on top of PR 3.
- If you are asked to implement only one PR, implement only that PR.
- Stop after each PR is opened or after producing the ready-to-open branch, depending on the runtime’s capabilities.

## Common guardrails

- Do not rewrite unrelated workflows.
- Do not enable expensive agent runs globally.
- Do not make Judge/Critic/Analyst reviews blocking by default.
- Do not auto-apply `claude-fix`.
- Do not create or update ADRs automatically from post-merge review jobs; create follow-up issues instead.
- Do not invent a Cursor/Gemini Actions integration. Use the repo’s existing working automation path if needed, while keeping prompts/provider names model-neutral and configurable.
- Do not allow `.context/rules/legacy_agents_anchor_redirects.md` to become permanent compatibility debt. Delete it when no external references require it.

## Common verification

Run the repo’s normal checks, plus targeted greps relevant to each PR:

```bash
./test.sh
git status --short
```

If `./test.sh` is too slow or blocked by missing local dependencies, run the narrow checks that apply to changed scripts/workflows and document the limitation in the PR body.

## PR body requirements

Each PR body must include:

- Scope summary
- Files changed
- What is explicitly out of scope
- Verification commands and results
- Rollback plan
- Follow-up work, if any


---

# File: 01-context-decomposition.md

# PR 1 prompt: decompose `AGENTS.md` and create the rule catalog

## Objective

Shrink `AGENTS.md` into a thin startup kernel and move session-start mechanics into a focused rule file. Turn `.context/rules/README.md` into the rule catalog that tells agents which rules to load for each task type.

This PR should reduce always-loaded context and make rule loading explicit, targeted, and auditable.

## Read first

Read the current repository instructions from disk before editing. At minimum inspect:

```bash
sed -n '1,240p' AGENTS.md
sed -n '1,220p' .context/00_INDEX.md
find .context/rules -maxdepth 1 -type f -name '*.md' | sort
sed -n '1,220p' .context/rules/process_doc_maintenance.md 2>/dev/null || true
sed -n '1,220p' .context/rules/process_pr_completion.md 2>/dev/null || true
sed -n '1,220p' .context/rules/process_work_style.md 2>/dev/null || true
sed -n '1,220p' .context/rules/process_gates.md 2>/dev/null || true
sed -n '1,220p' .context/rules/process_model_tier.md 2>/dev/null || true
sed -n '1,220p' .context/rules/repo_orchestration_patterns.md 2>/dev/null || true
```

Also search current references:

```bash
git grep -n "AGENTS.md#" || true
git grep -n "AGENTS_MD_VERSION\|session handshake\|context receipt\|Read, Reviewed, or Skipped\|prompt-context read credit" || true
git grep -n "\.vscode/settings.json\|vscode.*settings" || true
```

## Scope

Implement exactly this PR-sized change:

1. Create `.context/rules/process_session_start.md`.
2. Turn `.context/rules/README.md` into the rule catalog.
3. Create `.context/rules/legacy_agents_anchor_redirects.md` if old `AGENTS.md#...` links still need compatibility.
4. Reduce `AGENTS.md` to a startup kernel.
5. Remove `.vscode/settings.json` only if search proves it is deprecated and unreferenced, or leave it and document why.
6. Update docs and checks that reference moved `AGENTS.md` sections.
7. Add lightweight validation so future changes do not re-grow `AGENTS.md` or break anchor redirects.

Do not implement advisory review workflows in this PR.

## Desired `AGENTS.md` shape

Keep `AGENTS.md` short. Use language close to this, but adapt to the repo’s exact conventions:

```markdown
# AGENTS.md

<!-- AGENTS_MD_VERSION: <next version> -->

Before substantive repo work, read:

1. `.context/rules/process_session_start.md`
2. `.context/rules/README.md`

A pointer or filename reference alone does not count as read credit. Full content already present verbatim in prompt context may count as Reviewed unless freshness, cadence, explicit dispatch, citations, or compliance evidence require reading from disk.

Truth hierarchy:

1. `./.context/**`
2. `./docs/**`
3. Codebase
```

Include only the minimum extra text required for existing tooling compatibility.

## `process_session_start.md` content requirements

Move or recreate the current canonical rules for:

- session handshake
- parent vs subagent handshake positioning
- session context receipt
- prompt-context read credit
- canary/version handling
- what counts as `Read`, `Reviewed`, or `Skipped`
- when full content already present in prompt context may count as Reviewed
- when disk reads are still required despite prompt-context content
- relationship between parent session and subagent dispatch packets
- how the agent reports loaded rule/context surfaces

Recommended outline:

```markdown
# Process: Session Start

## Purpose
## Load profile
## Required startup sequence
## Session handshake
## Parent vs subagent handshake positioning
## Session context receipt
## Prompt-context read credit
## Read / Reviewed / Skipped definitions
## Canary and version handling
## Evidence requirements
## Failure handling
```

Keep this file normative. Move verbose rationale/examples to `docs/` if they are long.

## Rule catalog requirements

`.context/rules/README.md` should become a compact catalog, not a long process guide.

Include a table with columns like:

```markdown
| Rule file | Applies when | Load profile | Trigger | Re-read cadence | Evidence expected |
|---|---|---|---|---|---|
```

Important distinction:

- “Applies when” means the rule is binding for that work.
- “Load profile” means when the agent must actually read the file.
- Avoid declaring too many files as “Always read.” The goal is targeted context loading.

Every `.context/rules/*.md` file should appear in the catalog unless intentionally excluded with a documented reason.

## Legacy anchor redirect requirements

If any docs still reference old `AGENTS.md#...` anchors, do one of:

1. update the references to the new rule/doc path; or
2. create `.context/rules/legacy_agents_anchor_redirects.md` with a table:

```markdown
| Old anchor | Now lives in | Notes |
|---|---|---|
| `AGENTS.md#session-handshake` | `.context/rules/process_session_start.md#session-handshake` | ADR/backlink compatibility |
```

Add a sunset note:

```markdown
This file exists only for ADR/backlink compatibility after AGENTS.md decomposition.
Do not add new anchors here.
Remove entries after references are updated.
```

## Validation to add or update

Add or update a check under `scripts/checks/` if the repo’s check architecture supports it.

The check should verify:

1. `AGENTS.md` contains the version canary and points to `process_session_start.md` and `.context/rules/README.md`.
2. `.context/rules/process_session_start.md` exists.
3. `.context/rules/README.md` exists and references every `.context/rules/*.md` file, except README itself and documented legacy/exception files.
4. No stale `AGENTS.md#...` references remain unless they appear in `legacy_agents_anchor_redirects.md`.
5. `AGENTS.md` stays below a reasonable line-count threshold, such as 80 lines, unless an ADR explicitly changes the threshold.

Do not make the check brittle around exact line numbers.

## `.vscode/settings.json`

Only remove `.vscode/settings.json` if this command shows no live dependency:

```bash
git grep -n "\.vscode/settings.json\|vscode.*settings" || true
```

If referenced, either update the reference or leave the file and note it in the PR body.

## Acceptance criteria

- `AGENTS.md` is a thin startup kernel.
- `.context/rules/process_session_start.md` contains the moved session-start contract.
- `.context/rules/README.md` is the rule catalog and routes agents to targeted rules.
- Old `AGENTS.md#...` references are updated or mapped through `legacy_agents_anchor_redirects.md`.
- Verbose rationale/examples are moved out of `.context/rules` only where safe and with references preserved.
- `.vscode/settings.json` is removed only if safe.
- Existing docs that describe startup behavior are updated.
- Checks pass.

## Verification commands

Run:

```bash
./test.sh
git grep -n "AGENTS.md#" || true
git grep -n "\.vscode/settings.json\|vscode.*settings" || true
find .context/rules -maxdepth 1 -type f -name '*.md' | sort
```

If `./test.sh` fails for a pre-existing or environment-specific reason, run the relevant `scripts/checks/*` files and document the limitation.

## PR body notes

Include:

- Old `AGENTS.md` sections moved and their new homes.
- Whether `.vscode/settings.json` was removed.
- Any references intentionally left through the legacy redirect file.
- Verification results.
- Explicit out-of-scope note: advisory review workflows come in the next PR.


---

# File: 01b-rules-consolidation-and-legacy-retirement.md

# PR 1B prompt: consolidate `.context/rules` and retire legacy AGENTS anchors

## Objective

After PR 1 decomposes `AGENTS.md` and creates the rule catalog, perform a dedicated consolidation pass over `.context/rules/` so rule files stay focused, normative, and cheap to load. Move verbose examples/rationale to `docs/`, update references, and retire `.context/rules/legacy_agents_anchor_redirects.md` as soon as it is no longer needed.

This PR exists to prevent the new rule catalog and legacy redirect file from becoming a permanent compatibility layer, “boat anchor,” or lava-code surface.

## Read first

Start from the current default branch after PR 1 has landed or from a branch rebased on PR 1.

Read the current startup instructions from disk, then inspect:

```bash
sed -n '1,160p' AGENTS.md
sed -n '1,260p' .context/rules/README.md
sed -n '1,260p' .context/rules/process_session_start.md
find .context/rules -maxdepth 1 -type f -name '*.md' | sort
find docs -maxdepth 3 -type f -name '*.md' | sort
```

Search references before editing:

```bash
git grep -n "AGENTS.md#" || true
git grep -n "legacy_agents_anchor_redirects" || true
git grep -n "\.context/rules/" || true
git grep -n "process_session_start\|process_critical_thinking\|process_work_style\|process_gates\|process_pr_completion" || true
```

## Scope

Implement exactly this PR-sized change:

1. Audit all `.context/rules/*.md` files after the PR 1 decomposition.
2. Keep `.context/rules/` files normative and focused: rules, triggers, required evidence, and block/advisory criteria.
3. Move long examples, rationale, historical background, and tutorials to `docs/` while preserving links from the rule files.
4. Merge or split rule files only when doing so improves load targeting and reduces overlap.
5. Update `.context/rules/README.md` so it remains the compact rule catalog and points to any moved explanatory docs.
6. Update every stale reference to pre-decomposition `AGENTS.md#...` anchors where practical.
7. Remove entries from `.context/rules/legacy_agents_anchor_redirects.md` after references are updated.
8. Delete `.context/rules/legacy_agents_anchor_redirects.md` entirely if it has no remaining live purpose.
9. Add or update checks so the legacy redirect file cannot silently become permanent lava code.

Do not implement advisory review workflows, feedback consolidation workflows, or post-merge retrospective workflows in this PR.

## Rule consolidation policy

For each `.context/rules/*.md` file, classify content into one of these buckets:

| Bucket | Keep in `.context/rules`? | Destination |
|---|---:|---|
| Mandatory process rule | Yes | Same rule file or more focused rule file |
| Trigger / load profile / re-read cadence | Yes | `.context/rules/README.md` and/or rule file |
| Evidence / compliance contract | Yes | Rule file, with schema/docs links if long |
| Blocking/advisory gate criteria | Yes | Rule file |
| Long examples | No, unless tiny | `docs/guides/` or role-specific docs |
| Historical rationale | No | ADR or `docs/` guide |
| Worked examples / tutorials | No | `docs/guides/` |
| Repeated content already covered elsewhere | No | Replace with link to canonical source |

Prefer moving verbose material to an existing guide when one exists. Create a new docs page only when there is no natural home.

## Consolidation guardrails

- Do not reduce clarity by merging unrelated rules into one large file.
- Do not delete a rule just because it is verbose; extract the verbose part and keep the normative contract.
- Do not create a new God Object under `.context/rules/README.md`.
- Keep `.context/rules/README.md` as a catalog/router, not a process guide.
- Keep each rule file focused on one primary reason to change.
- Preserve backward-compatible references during the PR, but prefer updating live references over adding redirect entries.
- Do not add new `AGENTS.md#...` references.

## Legacy redirect retirement requirements

If `.context/rules/legacy_agents_anchor_redirects.md` exists, treat it as temporary compatibility debt.

Required behavior:

1. Search for live references:

   ```bash
   git grep -n "AGENTS.md#" -- ':! .context/rules/legacy_agents_anchor_redirects.md' || true
   ```

2. For each live reference:
   - update it to the new rule/doc anchor when it is a current process reference;
   - preserve it only when changing historical ADR text would be misleading, and document why.

3. Remove redirect rows whose old anchor is no longer referenced anywhere outside the redirect file.

4. If no redirect rows remain, delete `.context/rules/legacy_agents_anchor_redirects.md`.

5. Add/update a check so the file is only allowed when it contains at least one redirect that corresponds to a live external reference.

Suggested check logic:

```bash
legacy=".context/rules/legacy_agents_anchor_redirects.md"
external_refs=$(git grep -n "AGENTS.md#" -- ':! .context/rules/legacy_agents_anchor_redirects.md' || true)

if [[ -f "$legacy" && -z "$external_refs" ]]; then
  fail "$legacy exists but no external AGENTS.md# references remain; delete it"
fi

if [[ -n "$external_refs" && ! -f "$legacy" ]]; then
  fail "external AGENTS.md# references remain but no legacy redirect file exists"
fi
```

Adapt to the repo's existing `scripts/checks/` style.

## Suggested implementation flow

1. Build a rule inventory:

   ```bash
   for f in .context/rules/*.md; do
     echo "--- $f"
     grep -E '^#|^## ' "$f" | sed -n '1,80p'
   done
   ```

2. Identify overlap and verbosity:

   ```bash
   wc -l .context/rules/*.md | sort -n
   git grep -n "For example\|Example:\|Rationale:\|Historically\|Background" .context/rules || true
   ```

3. Move long explanatory sections to docs and leave short links in the rule file.
4. Update `.context/rules/README.md` catalog rows.
5. Update references with `git grep`.
6. Retire redirect entries/file if possible.
7. Run tests and targeted greps.

## Acceptance criteria

- `.context/rules/` files are focused on normative process rules, triggers, evidence, and gates.
- Long examples/rationale moved to `docs/` where safe, with backlinks from the relevant rule files.
- `.context/rules/README.md` remains compact and references every active rule file.
- No new `AGENTS.md#...` references were introduced.
- Existing `AGENTS.md#...` references are updated where practical.
- `.context/rules/legacy_agents_anchor_redirects.md` is deleted if no longer needed.
- If the legacy redirect file remains, it has a clear sunset note and a check preventing stale/no-op entries.
- Checks pass.

## Verification commands

Run:

```bash
./test.sh
git grep -n "AGENTS.md#" || true
git grep -n "legacy_agents_anchor_redirects" || true
find .context/rules -maxdepth 1 -type f -name '*.md' | sort
wc -l AGENTS.md .context/rules/*.md | sort -n
```

If `./test.sh` fails for a pre-existing or environment-specific reason, run the relevant `scripts/checks/*` files and document the limitation in the PR body.

## PR body notes

Include:

- Rule files consolidated or slimmed.
- Content moved from `.context/rules` to `docs/`.
- References updated from old `AGENTS.md#...` anchors.
- Whether `legacy_agents_anchor_redirects.md` was deleted or why it still remains.
- The specific sunset/check behavior for the redirect file.
- Verification commands and results.
- Explicit out-of-scope note: review workflow changes come in later PRs.


---

# File: 02-advisory-review-mode.md

# PR 2 prompt: add opt-in rolling advisory review for draft/WIP PRs

## Objective

Add a low-cost, non-blocking, opt-in advisory review workflow that can run while implementation continues. It should combine Analyst, Judge, Critic, and code-review lenses into one advisory snapshot, posted as a single sticky PR comment.

This is not a blocking review gate and must not trigger automatic fix cycles.

## Read first

Read the current repo startup instructions and the workflow/review docs from disk. Inspect:

```bash
sed -n '1,220p' AGENTS.md
sed -n '1,220p' .context/rules/README.md 2>/dev/null || true
sed -n '1,220p' .context/rules/process_session_start.md 2>/dev/null || true
sed -n '1,260p' docs/guides/agent-pipeline.md
sed -n '1,260p' .github/workflows/agent-review-on-push.yml 2>/dev/null || true
sed -n '1,220p' .github/workflows/claude.yml 2>/dev/null || true
sed -n '1,180p' scripts/setup.sh 2>/dev/null || true
find scripts/setup -maxdepth 1 -type f -name '*.sh' -print | sort
```

Search labels and review workflows:

```bash
git grep -n "claude-review\|claude-fix\|copilot-relay\|REVIEW_ON_PUSH\|PR_RESOLVE_MAX_ROUNDS" || true
git grep -n "agent-review-on-push\|Gemini\|Copilot review\|pull_request.*synchronize" .github docs scripts || true
```

## Scope

Implement exactly this PR-sized change:

1. Add labels for advisory/final/retro review control.
2. Add `.github/prompts/pr-advisory-review.md`.
3. Add `.github/workflows/agent-advisory-review.yml`.
4. Add a helper script to upsert one sticky PR comment.
5. Update docs to describe the advisory review mode.
6. Add/adjust validation for the new workflow and scripts.

Do not implement final feedback consolidation in this PR.
Do not implement post-merge retrospectives in this PR.
Do not change existing `agent-fix-reviews.yml` behavior except for docs references if needed.

## Labels to add

Add labels through the repo’s existing setup/label creation mechanism:

| Label | Purpose |
|---|---|
| `ai-review:live` | Enable rolling advisory review on draft/WIP PRs. |
| `ai-review:full` | Request full review depth near finalization or on high-risk PRs. |
| `implementation-complete` | Later PR uses this to trigger final feedback consolidation. |
| `retro-review` | Later PR uses this for post-merge review. |
| `retro:adr` | Later PR may propose ADR follow-up issues. |
| `retro:context-pack` | Later PR may propose context-pack follow-up issues. |
| `review:blocking-ai` | Human escalation that an AI review finding should block until resolved. |

If the label setup is centralized, update only that source. Do not duplicate label definitions across many files unless the repo already requires that pattern.

## Workflow requirements

Create:

```text
.github/workflows/agent-advisory-review.yml
```

Required behavior:

- Trigger on `pull_request` events: `opened`, `reopened`, `synchronize`, `ready_for_review`, `labeled`.
- Must run on draft PRs when labeled `ai-review:live`.
- Must be opt-in by label.
- Must skip forks.
- Must skip closed PRs.
- Must use concurrency with `cancel-in-progress: true` per PR.
- Must post or update one sticky PR comment, not submit a formal PR review.
- Must be advisory only; it must not set review state, request changes, push commits, or apply `claude-fix`.
- Must not spam a new comment on every push.
- Must be cheap by default.

Suggested marker:

```markdown
<!-- ai-advisory-review:v1 -->
```

Suggested workflow shape:

```yaml
name: Agent — advisory review snapshot

on:
  pull_request:
    types: [opened, reopened, synchronize, ready_for_review, labeled]

permissions:
  contents: read
  pull-requests: read
  issues: write

concurrency:
  group: advisory-review-${{ github.event.pull_request.number }}
  cancel-in-progress: true

jobs:
  advisory-review:
    if: >-
      github.event.pull_request.state == 'open' &&
      github.event.pull_request.head.repo.full_name == github.repository &&
      contains(github.event.pull_request.labels.*.name, 'ai-review:live') &&
      !contains(github.event.pull_request.labels.*.name, 'smoke-test')
```

Use the repo’s existing working agent/action path if there is one. If the repo only has a working Claude Action path, use that for now while documenting that Cursor Composer 2.5 / Gemini Flash remain the benchmark-preferred future runtime. Do not claim Cursor/Gemini are wired unless they actually are.

## Advisory prompt requirements

Create:

```text
.github/prompts/pr-advisory-review.md
```

It must instruct a single reviewer to combine four lenses:

```markdown
## Analyst lens
- Is the PR still aligned to the issue outcome?
- Is there scope drift?

## Judge lens
- Are hard gates at risk?
- Are acceptance criteria and verification evidence likely sufficient?

## Critic lens
- Are there hidden assumptions, overengineering, unclear reasoning, or maintainability issues?

## Code review lens
- Are there concrete defects in the current diff?
```

Output structure is defined in `.github/prompts/pr-advisory-review.md` (canonical). Include snapshot header (with diff coverage), **session handshake** and **context receipt** sections that **pointer-link** to `.context/rules/process_session_start.md` — do not mirror the full handshake/receipt templates in the advisory prompt (avoids drift).

The prompt must say:

- Do not push commits.
- Do not submit a PR review.
- Do not apply labels.
- Do not resolve threads.
- Do not mark anything blocking unless a human later applies `review:blocking-ai`.
- Prefer concise, deduped findings.
- Avoid repeating findings already present in the existing advisory snapshot unless still present and material.

## Workflow scripts (AP8)

Place advisory workflow logic under **`scripts/workflows/advisory-review/`** (not `.github/scripts/`). Workflows should remain event wiring; extract dispatch, providers, and comment upsert into tested scripts per `repo_orchestration_patterns.md` **AP8**.

Minimum files:

```text
scripts/workflows/advisory-review/run-advisory-review.sh
scripts/workflows/advisory-review/upsert-pr-comment.sh
scripts/workflows/advisory-review/run-advisory-gemini.py
scripts/workflows/advisory-review/run-advisory-cursor.mjs
scripts/workflows/advisory-review/run-advisory-antigravity.py
```

Providers: `auto` (cursor → antigravity when `ADVISORY_ANTIGRAVITY_ENABLED=true` → gemini), `cursor`, `antigravity`, `gemini`. Future pack PRs (3–4) should use `scripts/workflows/<feature>/` the same way.

## Upsert helper

Add a helper script at:

```text
scripts/workflows/advisory-review/upsert-pr-comment.sh
```

Requirements:

```bash
upsert-pr-comment.sh <pr-number> <marker> <body-file>
```

Behavior:

1. Search PR issue comments for the marker.
2. If found, update the existing comment.
3. If not found, create a new comment.
4. Use `gh api` and `GH_TOKEN`.
5. Be shellcheck/syntax clean.

Do not rely on comments from review bodies; use issue comments for the sticky advisory snapshot.

## Documentation updates

Update `docs/guides/agent-pipeline.md` or the closest guide with:

- `ai-review:live` enables advisory snapshots.
- Advisory snapshots can run on draft PRs.
- Advisory snapshots are non-blocking.
- Final consolidation is a later workflow.
- `claude-fix` remains opt-in and is not automatically applied by advisory review.
- Existing Gemini/Copilot review-on-push behavior remains separate.

## Acceptance criteria

- New advisory workflow exists and is label-gated by `ai-review:live`.
- Draft PRs are allowed.
- Same-repo guard exists.
- Sticky comment marker exists.
- Helper script is idempotent.
- Advisory prompt combines Analyst/Judge/Critic/Code Review lenses into one job.
- No formal PR review is submitted by this workflow.
- No fix label is applied by this workflow.
- Labels are added to the setup path.
- Docs explain how to use the new workflow.
- Checks pass.

## Verification commands

Run:

```bash
./test.sh
bash -n scripts/workflows/advisory-review/upsert-pr-comment.sh 2>/dev/null || true
git grep -n "ai-review:live\|ai-advisory-review:v1\|pr-advisory-review" .
```

If actionlint is available:

```bash
actionlint .github/workflows/agent-advisory-review.yml
```

If shellcheck is available:

```bash
shellcheck scripts/workflows/advisory-review/*.sh
```

## PR body notes

Include:

- How to enable the workflow.
- Why it is non-blocking.
- What model/runtime is actually wired today.
- What remains out of scope: final consolidation and post-merge retrospectives.


---

# File: 03-final-feedback-consolidation.md

# PR 3 prompt: final feedback consolidation after implementation is complete

## Objective

Add an opt-in final feedback consolidation workflow that runs after implementation is finished. It should collect advisory snapshots and formal reviews, dedupe them, and post a single “Feedback Inbox” comment for the implementer or review-resolution workflow.

This PR should reduce review-loop thrash by batching feedback once near the end of implementation.

## Read first

Read the current repo startup instructions and the new advisory review implementation. Inspect:

```bash
sed -n '1,220p' AGENTS.md
sed -n '1,220p' .context/rules/README.md 2>/dev/null || true
sed -n '1,220p' .context/rules/process_session_start.md 2>/dev/null || true
sed -n '1,260p' docs/guides/agent-pipeline.md
sed -n '1,260p' .github/workflows/agent-advisory-review.yml 2>/dev/null || true
sed -n '1,260p' .github/prompts/pr-advisory-review.md 2>/dev/null || true
sed -n '1,260p' .github/workflows/agent-fix-reviews.yml 2>/dev/null || true
```

Search feedback/review mechanics:

```bash
git grep -n "ai-advisory-review:v1\|claude-fix\|implementation-complete\|review:blocking-ai\|resolve review" . || true
```

## Scope

Implement exactly this PR-sized change:

1. Add `.github/workflows/agent-review-finalize.yml`.
2. Add `.github/prompts/pr-final-feedback-consolidation.md`.
3. Add a deterministic feedback collection script.
4. Add or reuse a sticky-comment upsert helper.
5. Update docs for the final consolidation stage.
6. Add checks where appropriate.

Do not implement post-merge retrospective review in this PR.
Do not auto-apply `claude-fix` unless a human already applied it or the repo already has an explicit opt-in policy.

## Workflow requirements

Create:

```text
.github/workflows/agent-review-finalize.yml
```

Triggers:

```yaml
on:
  pull_request:
    types: [labeled, ready_for_review]
  workflow_dispatch:
    inputs:
      pr:
        description: "PR number"
        required: true
```

Required behavior:

- Runs when `implementation-complete` label is applied.
- May also be manually run for a PR number.
- Skips forks.
- Skips closed PRs.
- Uses concurrency per PR.
- Collects all relevant feedback into artifacts/files.
- Runs one consolidation pass.
- Posts or updates one sticky `Feedback Inbox` PR comment.
- Does not push commits.
- Does not resolve review threads.
- Does not submit a formal review.
- Does not apply `claude-fix`.

Suggested sticky marker:

```markdown
<!-- ai-feedback-inbox:v1 -->
```

## Feedback collector script

Create a script such as:

```text
scripts/workflows/pr-feedback/collect-pr-feedback.sh
```

Usage:

```bash
collect-pr-feedback.sh <pr-number> <out-dir>
```

It should collect:

- PR metadata
- changed files
- current head SHA
- issue comments
- formal PR reviews
- review comments / threads if accessible
- existing advisory snapshot comments
- labels

Suggested output:

```text
<out-dir>/pr.json
<out-dir>/comments.json
<out-dir>/reviews.json
<out-dir>/review-comments.json
<out-dir>/diff.patch
<out-dir>/advisory-comments.md
```

Use `gh api` / `gh pr view` and `GH_TOKEN`. Avoid requiring write permissions for collection.

## Consolidation prompt requirements

Create:

```text
.github/prompts/pr-final-feedback-consolidation.md
```

The prompt should instruct the agent to:

1. Read the collected files.
2. Identify current-head findings only.
3. Deduplicate repeated findings from advisory comments, Gemini, Copilot, Claude/Judge, and humans.
4. Classify findings as:
   - `must-fix`
   - `should-fix`
   - `follow-up`
   - `already-resolved`
   - `needs-human`
5. Produce a single Markdown comment body with the sticky marker.

Required output shape:

```markdown
<!-- ai-feedback-inbox:v1 -->

## Final Feedback Inbox

Head reviewed: `<sha>`
Mode: final consolidation, non-blocking unless a human applies `review:blocking-ai`

### Must fix before merge

| ID | Source(s) | File/area | Finding | Recommended action |
|---|---|---|---|---|

### Should fix when low-risk

| ID | Source(s) | File/area | Finding | Recommended action |
|---|---|---|---|---|

### Follow-up issue candidates

| ID | Source(s) | Area | Suggested issue |
|---|---|---|---|

### Already resolved / stale feedback

| Source | Why stale |
|---|---|
```

The prompt must not ask the agent to edit code.

## Integration with `agent-fix-reviews.yml`

Do not change `agent-fix-reviews.yml` to run automatically.

Document this behavior:

- `implementation-complete` creates a final feedback inbox.
- A human can then add `claude-fix` if they want automated remediation.
- If `claude-fix` is already present, the existing review-resolution workflow handles remediation according to its current rules.
- `review:blocking-ai` is a human escalation label, not an automatic output of the consolidation job.

## Docs updates

Update `docs/guides/agent-pipeline.md` or the closest guide:

```text
Implementer pushes until done
  ↓
apply `implementation-complete`
  ↓
final feedback consolidation posts Feedback Inbox
  ↓
human/agent resolves selected items
  ↓
normal deterministic merge gates
```

Clarify that this replaces repeated serial review/fix loops as the default happy path.

## Acceptance criteria

- Workflow exists and is label/manual triggered.
- `implementation-complete` label is documented and created by setup if label setup exists.
- Collector script is deterministic and syntax-clean.
- Consolidation prompt exists.
- Feedback Inbox sticky marker exists.
- Job does not push commits.
- Job does not apply `claude-fix`.
- Job does not submit a formal review.
- Docs explain how to use it.
- Checks pass.

## Verification commands

Run:

```bash
./test.sh
bash -n scripts/workflows/pr-feedback/collect-pr-feedback.sh 2>/dev/null || true
git grep -n "ai-feedback-inbox:v1\|implementation-complete\|pr-final-feedback-consolidation" .
```

If actionlint is available:

```bash
actionlint .github/workflows/agent-review-finalize.yml
```

If shellcheck is available:

```bash
shellcheck scripts/workflows/pr-feedback/collect-pr-feedback.sh
```

## PR body notes

Include:

- Trigger behavior.
- What gets collected.
- Why this is non-blocking.
- How it interacts with `claude-fix`.
- What remains out of scope: post-merge retrospective review.


---

# File: 04-postmerge-retrospective.md

# PR 4 prompt: post-merge retrospective review that creates follow-up issues

## Objective

Add an opt-in post-merge retrospective review workflow. After a PR merges, it should inspect the merged PR and create follow-up issues for evidence-backed problems, ADR update candidates, or context-pack improvements.

This workflow must not edit code, rewrite ADRs, or open PRs automatically. It creates follow-up issues only.

## Read first

Read current repo startup instructions and the review workflow docs. Inspect:

```bash
sed -n '1,220p' AGENTS.md
sed -n '1,220p' .context/rules/README.md 2>/dev/null || true
sed -n '1,220p' .context/rules/process_session_start.md 2>/dev/null || true
sed -n '1,300p' docs/guides/agent-pipeline.md
sed -n '1,220p' .github/workflows/agent-review-finalize.yml 2>/dev/null || true
sed -n '1,220p' .github/prompts/pr-final-feedback-consolidation.md 2>/dev/null || true
sed -n '1,220p' docs/decisions/adr-027-opportunity-feedback-channel.md 2>/dev/null || true
sed -n '1,220p' .context/rules/process_opportunity_feedback.md 2>/dev/null || true
```

Search retro/follow-up conventions:

```bash
git grep -n "agent-suggested\|retro-review\|retro:adr\|retro:context-pack\|opportunity" . || true
```

## Scope

Implement exactly this PR-sized change:

1. Add `.github/workflows/agent-postmerge-retro.yml`.
2. Add `.github/prompts/post-merge-retro.md`.
3. Add a deterministic evidence collector if not already reusable from PR 3.
4. Add `scripts/workflows/postmerge-retro/postmerge-retro-create-issues.sh`.
5. Add a JSON schema or lightweight validation for the retrospective output.
6. Update docs.
7. Add label setup entries if not already present.

Do not change merge behavior.
Do not make this run on every merged PR by default unless the repo owner explicitly asked for that in labels/config.

## Workflow requirements

Create:

```text
.github/workflows/agent-postmerge-retro.yml
```

Triggers:

```yaml
on:
  pull_request:
    types: [closed]
  workflow_dispatch:
    inputs:
      pr:
        description: "Merged PR number"
        required: true
      create_issues:
        description: "Create issues from retro output"
        required: true
        default: "true"
```

Job guard for automatic trigger:

```yaml
if: >-
  github.event.pull_request.merged == true &&
  github.event.pull_request.base.ref == 'main' &&
  (
    contains(github.event.pull_request.labels.*.name, 'retro-review') ||
    contains(github.event.pull_request.labels.*.name, 'retro:adr') ||
    contains(github.event.pull_request.labels.*.name, 'retro:context-pack') ||
    contains(github.event.pull_request.labels.*.name, 'ai-review:full')
  )
```

Required behavior:

- Runs only for merged PRs.
- Automatic mode is label-gated.
- Manual mode supports a PR number.
- Collects PR evidence.
- Produces a structured JSON result.
- Creates follow-up issues idempotently using dedupe markers.
- Does not commit, push, edit ADRs, or modify context files.
- Uses `agent-suggested` plus specific labels for created issues.

## Evidence collection

Collect into:

```text
.context/retrospectives/postmerge/pr-<number>/
```

Files:

```text
pr.json
diff.patch
issue-comments.json
reviews.json
review-comments.json
retro.json
```

These artifacts can stay ephemeral in Actions unless the repo already commits retrospectives. Prefer not committing generated retrospectives unless the repo has a clear convention for that.

## Retrospective prompt requirements

Create:

```text
.github/prompts/post-merge-retro.md
```

Prompt should instruct:

- Review the merged PR only.
- Prefer no issue over speculative issue.
- Do not suggest broad rewrites unless evidence shows recurring failure.
- Create actionable issue proposals only.
- Separate:
  - follow-up bug/process issues
  - ADR update candidates
  - context-pack improvement candidates
- Include evidence for every suggestion.
- Use stable dedupe keys.
- Output JSON only to `retro.json`.

Required JSON shape:

```json
{
  "pr": 123,
  "summary": "brief summary",
  "follow_up_issues": [
    {
      "title": "string",
      "labels": ["agent-suggested"],
      "severity": "low|medium|high",
      "body": "markdown body",
      "evidence": ["string"],
      "dedupe_key": "stable-short-key"
    }
  ],
  "adr_updates": [
    {
      "adr": "docs/decisions/adr-019-per-role-model-tiering.md",
      "title": "string",
      "body": "markdown body",
      "dedupe_key": "stable-short-key"
    }
  ],
  "context_pack_updates": [
    {
      "pack": "string",
      "reason": "string",
      "add": ["path"],
      "remove": ["path"],
      "evidence": ["string"],
      "dedupe_key": "stable-short-key"
    }
  ]
}
```

## Issue creation script

Create:

```text
scripts/workflows/postmerge-retro/postmerge-retro-create-issues.sh
```

Usage:

```bash
postmerge-retro-create-issues.sh <retro.json>
```

Required behavior:

1. Read `retro.json`.
2. For each suggested issue, construct a marker:
   ```markdown
   <!-- postmerge-retro:pr=<PR>:key=<dedupe_key> -->
   ```
3. Search all open and closed issues for that marker.
4. If found, skip.
5. If not found, create an issue.
6. Use labels from the JSON plus:
   - `agent-suggested`
   - `adr:update` for ADR updates
   - `context-pack` for context-pack updates
7. Include source PR number in the body.
8. Use `GH_TOKEN`.
9. Be shell syntax clean.

Do not create issues without a dedupe marker.

## Validation

Add a lightweight validation script or schema, for example:

```text
.github/schemas/postmerge-retro.schema.json
```

or a shell/JQ check that verifies:

- `pr` is a number.
- arrays exist.
- every item has `title` / `body` / `dedupe_key` as appropriate.
- no issue item has an empty dedupe key.

## Docs updates

Update the agent pipeline guide:

```text
Post-merge retrospective review

Merged PR with `retro-review`, `retro:adr`, `retro:context-pack`, or `ai-review:full`
  ↓
evidence collection
  ↓
retrospective analysis
  ↓
idempotent follow-up issue creation
```

Document:

- It is opt-in.
- It creates issues only.
- It does not edit ADRs or context packs directly.
- It is appropriate for process lessons, recurring review misses, ADR drift, and context-pack tuning.

## Acceptance criteria

- Post-merge retro workflow exists.
- Automatic trigger is label-gated.
- Manual dispatch exists.
- Prompt exists and outputs structured JSON.
- Issue creation script is idempotent.
- Created issues include dedupe markers.
- No code/ADR/context files are edited by the workflow.
- Docs explain usage.
- Labels are created if needed.
- Checks pass.

## Verification commands

Run:

```bash
./test.sh
bash -n scripts/workflows/postmerge-retro/postmerge-retro-create-issues.sh 2>/dev/null || true
git grep -n "postmerge-retro\|retro-review\|retro:adr\|retro:context-pack" .
```

If actionlint is available:

```bash
actionlint .github/workflows/agent-postmerge-retro.yml
```

If shellcheck is available:

```bash
shellcheck scripts/workflows/postmerge-retro/postmerge-retro-create-issues.sh
```

If a JSON schema is added and `check-jsonschema` is available:

```bash
check-jsonschema --schemafile .github/schemas/postmerge-retro.schema.json <sample-retro.json>
```

## PR body notes

Include:

- Trigger conditions.
- What evidence is collected.
- What issues are created.
- Dedupe strategy.
- Explicit statement that the workflow does not edit ADRs/context files directly.

