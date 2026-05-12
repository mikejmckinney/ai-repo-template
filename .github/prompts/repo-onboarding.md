---
description: Onboard an AI agent to a repo (template-clone or existing); produce repo brief.
agent: agent
---

# Repository Onboarding Prompt

You are a senior software engineer joining an existing codebase. Your job is to build an accurate mental model of this repo BEFORE making changes, then implement the requested work with minimal, well-tested diffs.

## Core Principles

- **Do NOT guess** APIs, file contents, or behavior. Verify everything in the repo.
- **Prefer small, reversible changes**. Keep style consistent with the repo.
- **Before editing**: Summarize understanding → propose a plan → identify files to touch.
- **After editing**: Provide rationale, the diff, and exact commands to test.

---

# Phase 0: Template Bootstrap (skip if not a fresh template clone)

> **Starting a new project from this template?** Read the
> [Template vs. Fork guidance](../../AI_REPO_GUIDE.md#template-vs-fork-choosing-how-to-start)
> **before** classifying below. TL;DR: "Use this template" (not Fork) is the
> default — a fork that keeps the name `ai-repo-template` will be classified as
> Mode A and skip bootstrap entirely, which is the wrong outcome for a new project.

This phase only applies when the repo was just cloned from
`mikejmckinney/ai-repo-template` (or its predecessor `dotfiles`) and has not
yet been customized for the actual project. If none of the detection signals
below fire, skip directly to Phase 1.

## Step 0.1: Classify the repo (Mode A / B / C)

Run these checks once and record the result. The mode determines whether
Phase 0 does any work and is reported at the start of Step 1.0:

- **Mode A — Template repo itself.** `git remote -v` (or the folder name)
  shows this repo *is* `ai-repo-template` (or legacy `dotfiles`). README,
  AI_REPO_GUIDE.md, and CLAUDE.md are the template's canonical docs and
  **must NOT be regenerated**. Skip directly to Phase 1.
- **Mode B — Derived repo, bootstrap not yet run.** Any of:
  - `README.md` or `AI_REPO_GUIDE.md` contains `TEMPLATE_PLACEHOLDER`.
  - `.github/ISSUE_TEMPLATE/config.yml` contains `PLEASE_UPDATE_THIS/URL`.
  - `./scripts/verify-env.sh` reports `PLACEHOLDER_COUNT > 0` (its output
    contains a "N files still contain TEMPLATE_PLACEHOLDER" line with N > 0).
    This catches partial-bootstrap states — e.g. `.context/**`, `docs/**`,
    `scripts/**`, or workflow files still carrying template stubs — even when
    the README/AI_REPO_GUIDE signals are already clear. (`verify-env.sh`
    excludes infrastructure files and the three bootstrap state files via
    `_PLACEHOLDER_LEGIT` and `_PLACEHOLDER_EXCLUDE`, so a fully-onboarded
    repo reaches PLACEHOLDER_COUNT=0 and does not re-trigger Mode B.)

  Do the work in Step 0.2, then continue to Phase 1.
- **Mode C — Derived repo, already customized.** No Mode B signals fire
  and the repo isn't `ai-repo-template`. Skip Phase 0 work; continue to
  Phase 1.

If signals are ambiguous (e.g. `ai-repo-template` *and* a stray
`TEMPLATE_PLACEHOLDER`), prefer Mode A — never regenerate the template's
own docs. Note the ambiguity in the Mode field of the Step 1.0 status line.

## Step 0.2: Apply template-bootstrap rules (Mode B only)

The canonical rules live in **`AGENTS.md`** (“Template detection
(important)” section) — read it first. The bullets below are a
non-canonical recap to anchor the work; if they ever drift from
AGENTS.md, AGENTS.md wins and this list should be re-synced in the
same PR:

1. **Replace `README.md`** with project-specific content (delete the template
   stub language; preserve repo-specific structure if any already exists).
2. **Regenerate `AI_REPO_GUIDE.md`** from the repo's real assets
   (`./.context/**`, `./docs/**`, source). This file is canonical for agents
   and must not retain template placeholder language.
3. **Replace placeholders** wherever they occur:
   - `TEMPLATE_PLACEHOLDER` markers → project-specific text or remove,
     **except** in `.context/state/_active.md`, `.context/sessions/latest_summary.md`,
     and `.context/state/coordination.md` — those files intentionally retain
     the marker post-onboarding per item 6 below (`verify-env.sh` excludes
     them via `_PLACEHOLDER_EXCLUDE` so they do not re-trigger Mode B).
   - `PLEASE_UPDATE_THIS/URL` in `.github/ISSUE_TEMPLATE/config.yml` →
     actual `owner/repo` from `git remote -v`.
4. **Extend `.context/rules/agent_ownership.md`** with rows for the project's
   real source paths (e.g. `src/frontend/**`, `src/backend/**`, `tests/**`).
   Do NOT remove the template-governance roles
   (Analyst / Architect / PM / QA / DevOps / Docs / Judge / Critic) —
   they remain load-bearing.
5. **Customize `docs/FAQ.md`** — strip entries prefixed with `Template:` and
   replace with project-specific Q&A.
6. **Clear template working state.** `.context/state/*.md` and
   `.context/sessions/*.md` ship populated with ai-repo-template's own
   task data. Reset them so re-read cadence (AGENTS.md →
   "Session-state cadence") doesn't ingest the template's stale state
   as if it were this project's reality:
   - `.context/state/_active.md` — clear the task details under the
     `# Active Task` header (resetting the fields to empty); keep the
     schema comment and `TEMPLATE_PLACEHOLDER` marker until the first
     real task lands.
   - `.context/sessions/latest_summary.md` — replace body with a single
     `No sessions yet` line; keep the `TEMPLATE_PLACEHOLDER` marker
     until the first close-out.
   - `.context/state/coordination.md` — clear all entries under
     `## Active Locks`, `## Recent History`, `## Blocked / Waiting`, and
     `## PM Notes`; keep the section headers, `## Lock Template`,
     and `TEMPLATE_PLACEHOLDER` marker.
   - Do NOT delete `*_template.md` or `README.md` in those directories
     — they are the schemas downstream agents copy from.

When Phase 0 work is complete, continue to Phase 1.

---

# Phase 1: Build Context (Repo Brief)

## Step 1.0: Quick context check (always run first)

Before the deep dive in Step 1.1, do a fast sanity pass so the rest of
Phase 1 has accurate state. Per ADR-025 (issue #298), live coordination
state lives in GitHub (issue body, PR body, latest `agent-state:v1`
comment, labels), not in repo-local `_active.md` / `task_*.md` files.
The order below reflects that:

1. **Read the assigned GitHub issue body** (and the linked PR body, if
   one exists). This is the durable feature/task contract used by
   Analyst / Judge / Critic gates — see
   [`.github/ISSUE_TEMPLATE/feature_request.md`](../ISSUE_TEMPLATE/feature_request.md).
2. **Read the latest `agent-state:v1` issue/PR comment**, if one exists.
   That's the live coordination baton — since-last-update, blockers,
   next 1–3 actions, handoff. Template:
   [`.context/state/agent_state_comment_template.md`](../../.context/state/agent_state_comment_template.md).
3. **Check GitHub labels** on the issue/PR for coarse workflow state
   (`agent:claimed`, `agent:blocked`, `agent:awaiting-review`).
4. Read `.context/00_INDEX.md` to locate relevant rules and constraints.
5. Skim `.context/sessions/latest_summary.md` for durable retrospective
   lessons from recent merged PRs (post-ADR-025: lessons land at PR
   merge / close-out, not as live working logs).
6. Run `git status` and `./scripts/verify-env.sh` to confirm the working
   tree and environment are stable.
7. (Legacy / transitional) If the issue/PR is from before ADR-025, you
   may also skim `.context/state/_active.md` and `.context/state/coordination.md`
   for in-flight work claimed under the pre-ADR-025 model. Treat anything
   you find there as legacy/advisory, not authoritative — the GitHub
   issue/PR is the source-of-truth.
8. Report a one-line status:
   `"Context reviewed. Onboarding Mode: <A|B|C>. Current task is <issue#/PR#/name>. Environment is <Stable|Unstable: <reason>>. Ready for instructions."`

**"Stable" means all of:**

- `git status` is clean, or only contains expected agent edits.
- `./scripts/verify-env.sh` exits 0 **and** reports no onboarding-blocking
  WARNs. In particular, treat any `TEMPLATE_PLACEHOLDER`-still-present
  WARN as **Unstable** when running in a derived (non-template) repo —
  it means stub docs haven't been replaced yet (Phase 0 is incomplete).
  (`verify-env.sh` emits a distinct WARN for the 3 bootstrap state files;
  that warn is **non-blocking** — expected during bootstrap, actionable once
  the first real task/session has landed and those markers should be cleared.)
- Steps 1–6 above completed without missing-file errors. (`bash test.sh`
  is the deeper structural check; run it later in Phase 1 if you want
  full coverage.)

Otherwise report **Unstable** and name the specific failure or blocking
WARN (e.g. `Unstable: verify-env.sh exited 1 — missing PYTHONPATH`, or
`Unstable: verify-env.sh warned TEMPLATE_PLACEHOLDER remains in 3 files`).

If any of these files are missing, note it explicitly — do not invent
content, and do not block on it. Continue with the rest of Phase 1.


## Step 1.1: Read Key Documentation

- [ ] `README.md`
- [ ] `CONTRIBUTING.md`
- [ ] `AI_REPO_GUIDE.md` (if exists — treat as canonical)
- [ ] `.github/copilot-instructions.md` (if exists)
- [ ] Any docs in `/docs`, `ARCHITECTURE.md`, `SECURITY.md`

## Step 1.2: Map the Codebase

Use search and file exploration (not linear reading) to identify:

### Directory Structure
```
Top-level directories and their purposes:
├── src/           # <purpose>
├── tests/         # <purpose>
├── docs/          # <purpose>
└── ...
```

### Entry Points
- **Web apps**: Main server file, routers, app bootstrap
- **CLI**: Bin directory, command registry
- **Libraries**: Public API surface, exports

### Test Infrastructure
- Test framework used
- Test file locations
- How to run tests

## Step 1.3: Identify Build Commands

Find and verify these commands from `package.json`, `Makefile`, `pyproject.toml`, etc.:

| Task | Command | Verified |
|------|---------|----------|
| Install dependencies | | [ ] |
| Build | | [ ] |
| Test | | [ ] |
| Lint | | [ ] |
| Type check | | [ ] |

## Step 1.4: Produce Repo Brief

Output a structured summary:

```markdown
## What This Repo Does
<1-3 sentences>

## Tech Stack
- Language: 
- Framework:
- Build tool:
- Test framework:

## Folder Map
- `/src` — 
- `/tests` — 
- `/docs` — 

## Key Entry Points
- Main: 
- CLI: 
- API: 

## Configuration Files
- Build config:
- Lint config:
- CI config:

## How to Run Locally
<commands>

## How to Test
<commands>

## Known Risks/Gotchas
- <item>
```

## Step 1.5: Create/Update AI_REPO_GUIDE.md

If `/AI_REPO_GUIDE.md` does NOT exist, create it with:
- Overview (what this is)
- Quickstart (run/test commands)
- Folder map + key entry points
- Conventions (lint/format, branching, commit style)
- Where to add things (routes, services, components)
- Troubleshooting / common gotchas

If it exists, verify accuracy and update if needed.

## Step 1.6: Confirm template placeholders are gone

Template-placeholder cleanup is handled in **Phase 0**. As a final
check, re-run the **Mode B detection signals** from Step 0.1 and
confirm none still fire. In a derived repo, all three should now be
clean:

```bash
# Signal 1 — README and AI_REPO_GUIDE no longer carry the template stub.
grep -El 'TEMPLATE_PLACEHOLDER' README.md AI_REPO_GUIDE.md 2>/dev/null \
  && echo "FAIL: stub README or AI_REPO_GUIDE still has TEMPLATE_PLACEHOLDER"

# Signal 2 — issue-template config points at the real repo.
grep -E 'PLEASE_UPDATE_THIS/URL' .github/ISSUE_TEMPLATE/config.yml 2>/dev/null \
  && echo "FAIL: ISSUE_TEMPLATE/config.yml still has PLEASE_UPDATE_THIS/URL"
```

If either signal fires, return to Phase 0 Step 0.2 and finish the
cleanup before continuing.

A broad `grep -RIl 'TEMPLATE_PLACEHOLDER|PLEASE_UPDATE_THIS' .` is
**not** a useful test — these markers are intentionally referenced in
many files as part of the template-detection logic itself
(`.github/copilot-instructions.md`, `.github/prompts/**`, `AGENTS.md`,
`.github/ISSUE_TEMPLATE/agent_init.md`, the agent role files, and the
`*.template` config samples). Trust the targeted checks above.

Use `grep -E` (extended regex) rather than `grep` with `\|` — the
basic-regex alternation is not portable across all `grep`
implementations.

---

# Phase 2: Clarify the Task

Ask at most **3 targeted questions** that unblock implementation.

If no questions are required, proceed to Phase 3.

Examples of good questions:
- "Should this change be backward compatible?"
- "Which test file should I add tests to?"
- "Is there an existing pattern for <X> I should follow?"

---

# Phase 3: Implement

## Step 3.1: Re-read AI_REPO_GUIDE.md

Cite which sections guide your approach.

## Step 3.2: Propose a Plan

Before making changes, provide:

```markdown
## Implementation Plan

### Changes
1. [ ] `path/to/file.ext` — <what changes>
2. [ ] `path/to/file.ext` — <what changes>

### Tests to Add/Update
- [ ] `test/path/file.test.ext` — <what to test>

### Risks
- <potential issues>

### Verification
- `<command>` — what it proves
```

## Step 3.3: Make the Changes

- Follow existing code style and patterns
- Add/update tests for behavioral changes
- Update docs if behavior changed

## Step 3.4: Update AI_REPO_GUIDE.md

If your changes affect:
- Commands
- File structure
- Conventions
- Entry points

Update `AI_REPO_GUIDE.md` to reflect this.

---

# Phase 4: Deliver

Provide:

````markdown
## Summary
<What changed and why>

## Files Changed
- `path/to/file.ext` — <description>

## Test Commands
```bash
<commands to verify changes work>
```

## Expected Outcome
<What should happen when tests pass>

## AI_REPO_GUIDE.md Status
- [ ] Up to date
- [ ] Updated (describe what changed)
- [ ] N/A (no structural changes)

## Follow-ups (optional)
- <Future improvements>
````

---

# Verification Checklist

Before considering the task complete:

- [ ] All tests pass
- [ ] Linting passes
- [ ] Build succeeds
- [ ] Changes are minimal (no unrelated modifications)
- [ ] Docs updated if behavior changed
- [ ] `AI_REPO_GUIDE.md` is accurate
